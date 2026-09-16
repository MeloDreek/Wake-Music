import Foundation
import Network

/// Browses only advertised SMB services; never scans IP ranges or connects with credentials.
/// All state and callbacks are confined to the main queue/run loop.
final class SMBDiscovery: NSObject, NetServiceDelegate {
    struct Device: Equatable {
        let id: String
        let name: String
        let host: String
        let port: Int
    }
    enum State { case searching, browsing, blocked, unavailable }

    private(set) var devices: [Device] = []
    private(set) var state: State = .searching
    var onChange: (() -> Void)?
    private var browser: NWBrowser?
    private var services: [String: NetService] = [:]
    private var resolved: [String: Device] = [:]
    private var searchDeadline: DispatchWorkItem?
    private var generation = UUID()

    func start() {
        stop()
        devices = []
        state = .searching
        onChange?()
        let current = generation
        let browser = NWBrowser(for: .bonjour(type: "_smb._tcp", domain: "local."), using: .tcp)
        self.browser = browser
        browser.stateUpdateHandler = { [weak self] status in
            guard let self, self.generation == current else { return }
            switch status {
            case .ready:
                self.state = .searching
                self.scheduleDeadline(generation: current)
            case .waiting(let error), .failed(let error):
                // kDNSServiceErr_PolicyDenied. A timeout or an empty result isn't a denial.
                self.state = error == .dns(-65570) ? .blocked : .unavailable
                self.searchDeadline?.cancel()
                self.clearServices()
            default: return
            }
            self.onChange?()
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self, self.generation == current else { return }
            var advertised: [String: (String, String, String)] = [:]
            for result in results {
                guard case .service(let name, let type, let domain, _) = result.endpoint else { continue }
                let id = [name, type, domain].joined(separator: "\0")
                advertised[id] = (name, type, domain)
            }
            // Limit outstanding resolutions on very large LANs. Results are deterministic.
            let ids = Set(advertised.keys.sorted().prefix(64))
            for id in Array(self.services.keys) where !ids.contains(id) {
                self.services.removeValue(forKey: id)?.stop()
                self.resolved.removeValue(forKey: id)
            }
            for id in ids where self.services[id] == nil {
                guard let (name, type, domain) = advertised[id] else { continue }
                let service = NetService(domain: domain, type: type, name: name)
                self.services[id] = service
                service.delegate = self
                service.resolve(withTimeout: 8)
            }
            self.publish()
        }
        browser.start(queue: .main)
    }

    func stop() {
        generation = UUID() // Ignore queued callbacks from a previous browse.
        searchDeadline?.cancel()
        searchDeadline = nil
        browser?.cancel()
        browser = nil
        clearServices()
    }

    private func clearServices() {
        for service in services.values {
            service.delegate = nil
            service.stop()
        }
        services.removeAll()
        resolved.removeAll()
        devices = []
    }

    private func scheduleDeadline(generation current: UUID) {
        searchDeadline?.cancel()
        let deadline = DispatchWorkItem { [weak self] in
            guard let self, self.generation == current else { return }
            self.state = .browsing
            self.onChange?()
        }
        searchDeadline = deadline
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: deadline)
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        guard let id = services.first(where: { $0.value === sender })?.key,
              let hostname = sender.hostName, !hostname.isEmpty,
              (1...65535).contains(sender.port) else { return }
        // Persist the DNS name, NOT one of its DHCP-assigned addresses.
        let host = hostname.hasSuffix(".") ? String(hostname.dropLast()) : hostname
        resolved[id] = Device(id: id, name: sender.name, host: host, port: sender.port)
        publish()
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        guard let id = services.first(where: { $0.value === sender })?.key else { return }
        resolved.removeValue(forKey: id)
        publish() // Retrying the search creates a fresh resolver.
    }

    private func publish() {
        devices = resolved.values.sorted {
            let comparison = $0.name.localizedStandardCompare($1.name)
            return comparison == .orderedSame ? $0.id < $1.id : comparison == .orderedAscending
        }
        if !devices.isEmpty { state = .browsing }
        onChange?()
    }

    deinit {
        searchDeadline?.cancel()
        browser?.cancel()
        services.values.forEach { $0.stop() }
    }
}
