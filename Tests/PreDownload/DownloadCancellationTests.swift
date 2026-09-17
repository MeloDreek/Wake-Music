import Foundation

@main struct DownloadCancellationTests {
    static func main() throws {
        let gate = DownloadCommitGate()
        var published = false
        gate.cancel()
        do {
            try gate.commit { published = true }
            fatalError("Cancelled tasks must not publish")
        } catch {
            precondition((error as? URLError)?.code == .cancelled)
            precondition(!published)
        }
        // A file already committed before cancellation stays complete.
        let completed = DownloadCommitGate()
        let value = try completed.commit { "complete" }
        completed.cancel()
        precondition(value == "complete")
        let failed = DownloadCommitGate()
        do {
            try failed.commit { throw CocoaError(.fileWriteOutOfSpace) }
        } catch {}
        // The lock is released on both thrown errors and cancellation.
        failed.cancel()
        do {
            _ = try failed.commit { 1 }
            fatalError("Cancelled failed task must stay cancelled")
        } catch {}
        let racing = DownloadCommitGate()
        let entered = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        let cancellationReturned = DispatchSemaphore(value: 0)
        let committed = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            _ = try? racing.commit {
                entered.signal()
                _ = release.wait(timeout: .now() + 2)
                return "published"
            }
            committed.signal()
        }
        precondition(entered.wait(timeout: .now() + 2) == .success)
        DispatchQueue.global().async {
            racing.cancel()
            cancellationReturned.signal()
        }
        precondition(cancellationReturned.wait(timeout: .now() + 0.05) == .timedOut)
        release.signal()
        precondition(committed.wait(timeout: .now() + 2) == .success)
        precondition(cancellationReturned.wait(timeout: .now() + 2) == .success)
        do {
            _ = try racing.commit { "late publish" }
            fatalError("No late commits after racing cancellation")
        } catch {}
        print("Download commit/cancellation checks passed (including concurrent cancellation)")
    }
}
