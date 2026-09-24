import UIKit
import AppGroupKit
import KakaFoundation
import WaketagLibKit
import Alamofire
import Combine
import UserNotifications

/// App-side execution lives outside AppGroupKit: views only observe and control it.
extension DownloadManager {
    func activateDownloads() { DownloadExecution.shared.activate() }
    func resumeDownloads() { DownloadExecution.shared.resume() }
    func pauseDownloads() { DownloadExecution.shared.pause() }
    func prioritizeDownload(_ model: MusicItemModel) {
        var tasks = taskArray.filter { $0.preDownloadIdentity() != model.preDownloadIdentity() }
        tasks.insert(model, at: 0)
        taskArray = tasks
        resumeDownloads()
    }
    func preDownload(_ model: MusicItemModel) { DownloadExecution.shared.prepare(model) }
    func cancelPreDownload() { DownloadExecution.shared.cancelPreparation() }
    var downloadUpdates: PassthroughSubject<Void, Never> { DownloadExecution.shared.updates }
    var downloadsRunning: Bool { DownloadExecution.shared.manual != nil }
    func downloadProgress(for model: MusicItemModel) -> Double? {
        let job = DownloadExecution.shared.manual
        return job?.identity == model.preDownloadIdentity() ? job?.progress : nil
    }
    func downloadError(for model: MusicItemModel) -> String? {
        DownloadExecution.shared.errors[model.preDownloadIdentity()]
    }
}

// BEGIN DOWNLOAD COMMIT GATE
/// Cancellation and publishing a complete file are mutually exclusive.
final class DownloadCommitGate {
    private let lock = NSLock()
    private var cancelled = false
    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }
    func commit<T>(_ operation: () throws -> T) throws -> T {
        lock.lock()
        defer { lock.unlock() }
        guard !cancelled else { throw URLError(.cancelled) }
        return try operation()
    }
}
// END DOWNLOAD COMMIT GATE

private final class DownloadJob {
    let model: MusicItemModel
    let identity: String
    let automatic: Bool
    let stage: URL
    var request: DownloadRequest?
    var lyricsRequest: DataRequest?
    var progress: Double = 0
    var timeout: DispatchWorkItem?
    var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private let gate = DownloadCommitGate()

    init(_ model: MusicItemModel, automatic: Bool) {
        self.model = model
        identity = model.preDownloadIdentity()
        self.automatic = automatic
        stage = FileManager.default.temporaryDirectory.appendingPathComponent("wake-download-" + UUID().uuidString)
            .appendingPathExtension((model.downloadPathName() as NSString).pathExtension)
    }
    func cancel() {
        gate.cancel()
        timeout?.cancel()
        request?.cancel()
        lyricsRequest?.cancel()
    }
    func commit(_ operation: () throws -> URL) throws -> URL {
        try gate.commit(operation)
    }
}

private final class DownloadExecution: NSObject, UNUserNotificationCenterDelegate {
    static let shared = DownloadExecution()
    let updates = PassthroughSubject<Void, Never>()
    var manual: DownloadJob?
    var automatic: DownloadJob?
    var errors: [String: String] = [:]
    private var subscriptions = Set<AnyCancellable>()
    private let files = DispatchQueue(label: "com.wakemusic.download.files", qos: .utility)
    private var activated = false
    private var ready = false
    private var paused = false
    private var suspendedForBackground = false
    private var knownIDs = Set<String>()
    private var pendingPreparation: MusicItemModel?
    private var requestedNotifications = false
    private var notificationAuthorizationPending = false
    private var pendingNotifications: [URL] = []

    func activate() {
        guard Thread.isMainThread else { DispatchQueue.main.async { self.activate() }; return }
        guard !activated else { return }
        activated = true
        // Do not mark migration finished globally: failed moves remain for next launch.
        let old = SandboxFileManager.shared.preDownloadURL()
        let root = SandboxFileManager.shared.basePublicFileURL()
        // Include the canonical directory used by older OS/path APIs.
        let cacheRoot = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        var legacyFolders = [old, cacheRoot.appendingPathComponent(SandboxType_PreDownload)]
#if targetEnvironment(macCatalyst)
        legacyFolders.append(cacheRoot.appendingPathComponent(Bundle.main.bundleIdentifier ?? "Wakemusic")
            .appendingPathComponent(SandboxType_PreDownload))
#endif
        let migrationFolders = Array(Set(legacyFolders.map { $0.standardizedFileURL }))
        files.async {
            // These UUID staging files are never library files or resumable queue records.
            let temp = FileManager.default.temporaryDirectory
            let abandoned = (try? FileManager.default.contentsOfDirectory(at: temp,
                includingPropertiesForKeys: [.isRegularFileKey], options: .skipsHiddenFiles)) ?? []
            for file in abandoned where file.lastPathComponent.hasPrefix("wake-download-") || file.lastPathComponent.hasPrefix("predownload-") {
                if (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
                    try? FileManager.default.removeItem(at: file)
                }
            }
            var movedPaths: [String: URL] = [:]
            var result: [URL] = []
            for folder in migrationFolders {
                result += PreDownloadedAudioFile.migrateLegacyFiles(from: folder, to: root,
                    extensions: Set(AudioExtension.playableAudioSuffixs.map { $0.lowercased() })) { source, target in
                    movedPaths[source.standardizedFileURL.path] = target
                }
            }
            let migratedFiles = result
            let migrationPaths = movedPaths
            DispatchQueue.main.async {
                self.ready = true
                if !migratedFiles.isEmpty {
                    func relocated(_ model: MusicItemModel) -> MusicItemModel {
                        var updated = model
                        if let target = migrationPaths[model.mediaPlayURL.standardizedFileURL.path] {
                            updated.mediaPlayURL = target
                        }
                        return updated
                    }
                    AppLocalManager.shared.cachePathArray = AppLocalManager.shared.cachePathArray.map {
                        migrationPaths[URL(fileURLWithPath: $0).standardizedFileURL.path]?.path ?? $0
                    }
                    if let last = MusicConfigManager.shared.lastPlayModel {
                        MusicConfigManager.shared.lastPlayModel = relocated(last)
                    }
                    ConnectConfigManager.shared.lastPlaylist = ConnectConfigManager.shared.lastPlaylist.map(relocated)
                    let player = KakaMusicPlayer.shared
                    player.musicArray = player.musicArray.map(relocated)
                    player.tempMusicArray = player.tempMusicArray.map(relocated)
                    if let playing = player.playingMusic,
                       migrationPaths[playing.mediaPlayURL.standardizedFileURL.path] != nil {
                        player.playingMusic = relocated(playing)
                    }
                    SandboxFileManager.shared.addLocalMusicFiles(migratedFiles)
                    NotificationCenter.default.post(name: Notification.Name(kLocalMusicChangedKey), object: nil)
                }
                self.pump()
                if let pending = self.pendingPreparation { self.prepare(pending) }
            }
        }
        DownloadManager.shared.$taskArray.receive(on: DispatchQueue.main).sink { [weak self] tasks in
            guard let self else { return }
            let ids = Set(tasks.map { $0.preDownloadIdentity() })
            if !ids.subtracting(self.knownIDs).isEmpty { self.paused = false }
            self.knownIDs = ids
            self.errors = self.errors.filter { ids.contains($0.key) }
            if let job = self.manual, !ids.contains(job.identity) {
                self.manual = nil
                self.cancel(job)
            }
            if let job = self.automatic, ids.contains(job.identity) { self.cancelPreparation() }
            self.updates.send()
            self.pump()
        }.store(in: &subscriptions)
        MusicConfigManager.shared.$isPreDownload.receive(on: DispatchQueue.main).sink { [weak self] enabled in
            if !enabled { self?.cancelPreparation() }
        }.store(in: &subscriptions)
        UserInfoManager.shared.$payStatus.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.pump()
        }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: DownloadManager.didEnqueue)
            .receive(on: DispatchQueue.main).sink { [weak self] notification in
                guard let self else { return }
                for id in notification.object as? [String] ?? [] { self.errors.removeValue(forKey: id) }
                self.paused = false
                self.pump()
            }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main).sink { [weak self] _ in
                guard let self else { return }
                if self.suspendedForBackground {
                    self.suspendedForBackground = false
                    self.paused = false
                }
                self.pump()
            }.store(in: &subscriptions)
    }

    func resume() {
        activate()
        paused = false
        suspendedForBackground = false
        errors.removeAll()
        pump()
    }
    func pause() {
        paused = true
        suspendedForBackground = false
        if let job = manual { manual = nil; cancel(job) }
        updates.send()
    }
    func cancelPreparation() {
        guard Thread.isMainThread else { DispatchQueue.main.async { self.cancelPreparation() }; return }
        pendingPreparation = nil
        if let job = automatic { automatic = nil; cancel(job) }
    }
    private func cancel(_ job: DownloadJob) {
        job.cancel()
        endBackground(job)
        files.async { try? FileManager.default.removeItem(at: job.stage) }
    }
    private func current(_ job: DownloadJob) -> Bool {
        job.automatic ? automatic === job : manual === job
    }
    func prepare(_ model: MusicItemModel) {
        activate()
        guard MusicConfigManager.shared.isPreDownload, UserInfoManager.shared.isVIP(),
              !model.isLocalFile(), model.drive115Model?.isUnsupportedStreamingAudio != true else {
            cancelPreparation()
            return
        }
        if automatic?.identity == model.preDownloadIdentity() { return }
        cancelPreparation()
        guard ready else { pendingPreparation = model; return }
        guard !DownloadManager.shared.taskArray.contains(where: { $0.preDownloadIdentity() == model.preDownloadIdentity() }),
              SandboxFileManager.shared.getDownloadPlayURL(model) == nil else { return }
        let job = DownloadJob(model, automatic: true)
        automatic = job
        resolve(job)
    }
    private func pump() {
        guard ready, !paused, manual == nil, UserInfoManager.shared.isVIP() else { return }
        guard let model = DownloadManager.shared.taskArray.first(where: { errors[$0.preDownloadIdentity()] == nil }) else {
            updates.send()
            return
        }
        let job = DownloadJob(model, automatic: false)
        manual = job
        if automatic?.identity == job.identity { cancelPreparation() }
        requestNotificationPermission()
        updates.send()
        // Reuse completed automatic/manual downloads without downloading them twice.
        if let url = SandboxFileManager.shared.getDownloadPlayURL(model) {
            finish(job, result: .success(url))
        } else {
            resolve(job)
        }
    }

    private func resolve(_ job: DownloadJob) {
        job.backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "WakeDownload") { [weak self, weak job] in
            guard let self, let job, self.current(job) else { return }
            if job.automatic { self.cancelPreparation() } else {
                self.pause()
                self.suspendedForBackground = true
            }
        }
        let timeout = DispatchWorkItem { [weak self, weak job] in
            guard let self, let job, self.current(job) else { return }
            self.fail(job, URLError(.timedOut))
        }
        job.timeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 60, execute: timeout)
        let callback: (Result<URL, KakaError>) -> Void = { [weak self, weak job] result in
            DispatchQueue.main.async {
                guard let self, let job, self.current(job) else { return }
                switch result {
                case .success(let url): self.transfer(job, url: url)
                case .failure(let error): self.fail(job, error)
                }
            }
        }
        let model = job.model
        if let file = model.smbFile { SMBDriveService.shared.fileURL(file, completion: callback) }
        else if let file = model.ftpFile { FTPDriveService.shared.fileURL(file, completion: callback) }
        else if let file = model.megaFile {
            Task { @MainActor [weak self, weak job] in
                guard let self, let job, self.current(job) else { return }
                MEGADriveService.shared.fileURL(file, completion: callback)
            }
        }
        else if let file = model.pan123File { Pan123DriveService.shared.fileURL(file, completion: callback) }
        else if let file = model.guangyaFile { GuangyaDriveService.shared.fileURL(file, completion: callback) }
        else if let file = model.boxFile { BoxDriveService.shared.fileURL(file, completion: callback) }
        else if let file = model.pcloudFile { PCloudDriveService.shared.fileURL(file, completion: callback) }
        else if let file = model.yandexFile {
            YandexDriveService.shared.fileSource(file) { [weak self, weak job] result in
                DispatchQueue.main.async {
                    guard let self, let job, self.current(job) else { return }
                    switch result {
                    case .success(let source): self.transfer(job, url: source.url, additionalHeaders: source.headers)
                    case .failure(let error): self.fail(job, error)
                    }
                }
            }
        } else if let file = model.baiduFileModel {
            KakaMusicPlayer.shared.fetchBaiduDownloadURL(accessToken: file.baiduUser?.access_token ?? "", fileModel: file, completion: callback)
        } else if let file = model.aliFileModel {
            KakaMusicPlayer.shared.fetchAliyunDownloadURL(fileModel: file, completion: callback)
        } else if let file = model.drive115Model {
            KakaMusicPlayer.shared.fetch115DownloadPlayURL(file115: file, completion: callback)
        } else if let file = model.dropboxFile {
            KakaMusicPlayer.shared.fetchDropboxDownloadPlayURL(dropboxFile: file, completion: callback)
        } else { transfer(job, url: model.mediaPlayURL) }
    }

    private func transfer(_ job: DownloadJob, url: URL, additionalHeaders: [String: String] = [:]) {
        guard current(job) else { return }
        job.timeout?.cancel()
        if url.isFileURL {
            files.async {
                do {
                    try FileManager.default.copyItem(at: url, to: job.stage)
                    DispatchQueue.main.async { self.persist(job) }
                } catch { DispatchQueue.main.async { self.fail(job, error) } }
            }
            return
        }
        var headers = HTTPHeaders.default
        if let user = job.model.googleFile?.googleUser {
            headers.update(name: "Authorization", value: "Bearer " + (user.accessToken ?? ""))
        }
        additionalHeaders.forEach { headers.update(name: $0.key, value: $0.value) }
        let request = AF.download(url, headers: headers, to: { _, _ in (job.stage, [.createIntermediateDirectories]) })
        job.request = request
        request.redirect(using: Redirector(behavior: .modify { _, redirect, _ in
            guard let url = redirect.url else { return nil }
            if job.model.yandexFile != nil && !YandexDriveAPI.validDownloadURL(url) { return nil }
            if job.model.pan123File != nil && !Pan123DriveAPI.validDownloadURL(url) { return nil }
            if job.model.guangyaFile != nil && !GuangyaDriveAPI.validDownloadURL(url) { return nil }
            return redirect
        }))
        request.validate(statusCode: 200..<300).downloadProgress { [weak self, weak job] progress in
            guard let self, let job, self.current(job) else { return }
            job.progress = progress.fractionCompleted
            if !job.automatic { self.updates.send() }
        }.responseURL { [weak self, job] response in
            job.request = nil
            guard let self else { return }
            guard self.current(job) else {
                self.files.async { try? FileManager.default.removeItem(at: job.stage) }
                return
            }
            switch response.result {
            case .success:
                let type = response.response?.mimeType?.lowercased()
                if type == "text/html" || type == "application/json" {
                    self.fail(job, CocoaError(.fileReadCorruptFile))
                } else { self.fetchLyricsThenPersist(job) }
            case .failure(let error): self.fail(job, error)
            }
        }
    }

    private func fetchLyricsThenPersist(_ job: DownloadJob) {
        guard !job.automatic, job.model.webFileModel != nil,
              let url = job.model.lrcFileInSameFolderURL() else { persist(job); return }
        // Optional sidecar must never stall the queue or change a successful audio download to failure.
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let lyrics = AF.request(request).validate(statusCode: 200..<300)
        job.lyricsRequest = lyrics
        lyrics.responseData { [weak self, job] response in
            job.lyricsRequest = nil
            guard let self else { return }
            guard self.current(job) else { return }
            if case .success(let data) = response.result, data.count < 2_000_000,
               let text = String(data: data, encoding: .utf8), !text.isEmpty {
                self.files.async {
                    _ = TaglibMetadataParser.setLyris(text, toFileURL: job.stage)
                    DispatchQueue.main.async { self.persist(job) }
                }
            } else { self.persist(job) }
        }
    }

    private func persist(_ job: DownloadJob) {
        guard current(job) else { files.async { try? FileManager.default.removeItem(at: job.stage) }; return }
        var folder = SandboxFileManager.shared.basePublicFileURL()
        if !job.automatic, let name = job.model.downloadFolderName, !name.isEmpty {
            // Queue metadata must never escape the chosen music directory.
            let candidate = folder.appendingPathComponent(name).standardizedFileURL
            if candidate.path.hasPrefix(folder.standardizedFileURL.path + "/") { folder = candidate }
        }
        let target = folder
        files.async {
            let result: Result<URL, Error>
            do {
                let size = try job.stage.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size > 0 else { throw CocoaError(.fileReadCorruptFile) }
                let metadata = job.automatic ? TaglibMetadataParser.readMetadata(withFileURL: job.stage, read: .basic) : nil
                let url = try job.commit {
                    try PreDownloadedAudioFile.store(job.stage, in: target, title: metadata?.title,
                        artist: metadata?.artist, originalName: job.model.downloadPathName(), identity: job.identity)
                }
                result = .success(url)
            } catch { result = .failure(error) }
            try? FileManager.default.removeItem(at: job.stage)
            DispatchQueue.main.async { self.finish(job, result: result) }
        }
    }

    private func fail(_ job: DownloadJob, _ error: Error) {
        guard current(job) else { return }
        cancel(job)
        finish(job, result: .failure(error))
    }
    private func finish(_ job: DownloadJob, result: Result<URL, Error>) {
        endBackground(job)
        // A completed atomic move is kept even if the user switched tracks immediately afterwards.
        if case .success(let url) = result {
            SandboxFileManager.shared.addLocalMusicFiles([url])
            NotificationCenter.default.post(name: Notification.Name(kLocalMusicChangedKey), object: nil)
        }
        guard current(job) else { return }
        if job.automatic { automatic = nil } else { manual = nil }
        switch result {
        case .success(let url):
            if !job.automatic {
                _ = DownloadManager.shared.removeFromDownloads(job.model)
                notifyCompletion(url)
            }
        case .failure(let error):
            if !job.automatic { errors[job.identity] = error.localizedDescription }
        }
        updates.send()
        if !job.automatic { pump() }
    }
    private func endBackground(_ job: DownloadJob) {
        job.timeout?.cancel()
        if job.backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(job.backgroundTask)
            job.backgroundTask = .invalid
        }
    }
    private func requestNotificationPermission() {
        guard !requestedNotifications else { return }
        requestedNotifications = true
        notificationAuthorizationPending = true
        let center = UNUserNotificationCenter.current()
        if center.delegate == nil { center.delegate = self }
        center.requestAuthorization(options: [.alert, .sound]) { [weak self] _, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.notificationAuthorizationPending = false
                let pending = self.pendingNotifications
                self.pendingNotifications.removeAll()
                pending.forEach { self.notifyCompletion($0) }
            }
        }
    }
    private func notifyCompletion(_ url: URL) {
        if notificationAuthorizationPending {
            pendingNotifications.append(url)
            return
        }
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            let content = UNMutableNotificationContent()
            content.title = "Download.Completed".localStr()
            content.body = url.lastPathComponent
            content.sound = .default
            center.add(UNNotificationRequest(identifier: "download." + UUID().uuidString, content: content, trigger: nil))
        }
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler(notification.request.identifier.hasPrefix("download.") ? [.banner, .list, .sound] : [])
    }
}
