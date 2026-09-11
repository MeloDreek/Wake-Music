import Foundation

@main
struct PCloudStatusRegression {
    static func main() throws {
        var checks = 0
        func check(_ condition: @autoclosure () -> Bool, _ name: String) {
            precondition(condition(), name)
            checks += 1
        }
        typealias State = PCloudFileListEmptyState
        check(State.empty(folderID: 0, query: "") == .appFolder, "Empty root explains app-folder access")
        check(State.empty(folderID: 123, query: "") == .folder, "Empty subfolder is not an access error")
        check(State.empty(folderID: UInt64.max, query: "") == .folder, "64-bit folder IDs remain valid")
        check(State.empty(folderID: 0, query: "missing") == .search, "Search takes priority over root guidance")
        check(State.empty(folderID: 123, query: "missing") == .search, "Search in a subfolder")
        check(State.search.action == .clearSearch, "Search action clears query instead of retrying API")
        check(State.appFolder.action == .refresh, "Root action refreshes")
        check(State.folder.action == .refresh, "Subfolder action refreshes")
        check(State.failure("Network error").action == .refresh, "Failure action retries")
        check(State.failure("Network error").message { _ in "wrong" } == "Network error", "Failure is preserved, not relocalized or replaced with onboarding")
        let root = State.appFolder.message { $0 }
        check(root.contains(State.appFolderPath), "English root includes literal folder path")
        check(!root.contains("%@"), "English root substitutes placeholder")
        check(State.folder.message { $0 } == State.folderMessage, "Subfolder message")
        check(State.search.message { $0 } == State.searchMessage, "Search message")

        let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
        let catalog = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let strings = catalog["strings"] as! [String: [String: Any]]
        let refresh = strings["Refresh"]!["localizations"] as! [String: Any]
        check(refresh.count == 41, "All 41 existing localization regions are present")
        for (index, key) in [State.appFolderMessage, State.folderMessage, State.searchMessage].enumerated() {
            let localizations = strings[key]?["localizations"] as! [String: Any]
            check(Set(localizations.keys) == Set(refresh.keys), "Message covers every app localization")
            for (language, entry) in localizations {
                let unit = (entry as! [String: Any])["stringUnit"] as! [String: String]
                let value = unit["value"]!
                check(unit["state"] == "translated" && !value.isEmpty, "Translation exists: \(language)")
                check(value.components(separatedBy: "%@").count - 1 == (index == 0 ? 1 : 0), "Placeholder count: \(language)")
                if index == 0 {
                    let message = State.appFolder.message { _ in value }
                    check(message.contains(State.appFolderPath) && !message.contains("%@"), "Localized path is unchanged: \(language)")
                }
            }
        }
        print("PASS: \(checks) pCloud empty-state and localization checks")
    }
}
