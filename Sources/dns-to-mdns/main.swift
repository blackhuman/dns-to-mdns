import ArgumentParser
import Foundation
import Network

struct DNSProxyCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dns-to-mdns",
        abstract: "DNS-to-mDNS Proxy - Resolves DNS queries via system mDNS/Bonjour",
        usage: """
            dns-to-mdns -p 8053 --exclude "198.18.0.0/16,10.0.0.0/8"
        """
    )
    
    @Option(
        name: .long,
        help: "Comma-separated list of CIDR ranges to exclude from DNS responses (default: 198.18.0.0/16)"
    )
    var exclude: String = "198.18.0.0/16"
    
    @Option(
        name: [.customShort("p"), .long],
        help: "UDP port to listen on"
    )
    var port: UInt16 = 8053
    
    func run() async throws {
        // Parse excluded CIDR ranges
        let cidrRanges = exclude.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        
        print("DNS-to-mDNS Proxy")
        print("=================")
        print("Listening on port \(port)")
        print("Resolving queries via mDNS/Bonjour")
        print("Excluded IP ranges: \(cidrRanges.joined(separator: ", "))")
        print("")
        print("Press Ctrl+C to stop")
        print("")
        
        do {
            let server = try DNSServer(port: port, excludedCIDRRanges: cidrRanges)
            try await server.start()
            
            print("✅ DNS server ready on port \(port)")
            print("")
            print("Test with: dig @127.0.0.1 -p \(port) <hostname>.local A")
            print("")
            
            // Keep running until terminated
            await waitForTermination()
            
        } catch {
            print("❌ Failed to start server: \(error)")
            fatalError("Server error: \(error)")
        }
    }
    
    private func waitForTermination() async {
        await withCheckedContinuation { continuation in
            let signalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: DispatchQueue(label: "signal-handler"))
            signalSource.setEventHandler {
                print("\n👋 Shutting down...")
                signalSource.cancel()
                continuation.resume()
            }
            signal(SIGINT, SIG_IGN)
            signalSource.resume()
        }
    }
}

// Entry point
Task {
    await DNSProxyCommand.main()
}

// Run the event loop
RunLoop.main.run()
