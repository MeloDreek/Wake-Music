import AppGroupKit

extension DownloadViewController {
    @objc func startDownloadClick() {
        guard requireRemoteConnectionAccess() else { return }
        DownloadManager.shared.resumeDownloads()
        refreshDataAction()
    }
}

extension DownloadViewController: MusicTableViewCellDelegate {
    func musicTableCell(cell: MusicTableViewCell, model: MusicItemModel, action: MusicActionType) {
        guard action == .download, requireRemoteConnectionAccess() else { return }
        DownloadManager.shared.prioritizeDownload(model)
    }
}
