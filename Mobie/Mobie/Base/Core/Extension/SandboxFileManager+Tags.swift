import AppGroupKit
import WaketagLibKit

// Tag editing belongs to the app, where the remote Swift package is linked.
// AppGroupKit's file and cache utilities remain independent of TagLib.
extension SandboxFileManager {
    public func updateTitleTag(oldModel: MusicItemModel, newTitle: String) -> Bool {
        // Artwork keys are independent of editable tags; no file rename needed.
        TaglibMetadataParser.setTitle(newTitle, toFileURL: oldModel.mediaPlayURL)
    }

    public func updateArtistTag(oldModel: MusicItemModel, newArtist: String) -> Bool {
        TaglibMetadataParser.setArtist(newArtist, toFileURL: oldModel.mediaPlayURL)
    }
}
