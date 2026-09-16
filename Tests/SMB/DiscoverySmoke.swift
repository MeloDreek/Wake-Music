import Foundation

/// Optional real-LAN smoke test, separate from the deterministic transport regressions.
/// Compile with the production SMBDiscovery.swift and pass your own server's hostname.
@main
enum DiscoverySmoke {
    static func main() {
        guard CommandLine.arguments.count == 2 else {
            print("Usage: smb-discovery-smoke <your-server.local>")
            exit(2)
        }
        let expected = CommandLine.arguments[1]
        let discovery = SMBDiscovery()
        var phase = 0
        var finished = false
        discovery.onChange = {
            guard discovery.devices.contains(where: { $0.host == expected && $0.port == 445 }) else { return }
            precondition(Set(discovery.devices.map(\.id)).count == discovery.devices.count, "duplicate service")
            // Schedule outside the callback, as start itself publishes an initial state.
            DispatchQueue.main.async {
                guard !finished else { return }
                discovery.stop()
                precondition(discovery.devices.isEmpty, "stop clears discoveries")
                if phase == 0 {
                    phase = 1
                    discovery.start()
                } else {
                    finished = true
                    print("SMB discovery smoke passed: hostname, port, deduplication, stop/restart")
                    exit(0)
                }
            }
        }
        discovery.start()
        DispatchQueue.main.asyncAfter(deadline: .now() + 25) {
            discovery.stop()
            print("Expected SMB server was not discovered; check LAN access and Bonjour advertising.")
            exit(1)
        }
        RunLoop.main.run()
    }
}
