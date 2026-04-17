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

    @Option(
        name: .long,
        help: "Resolve a single hostname through the internal mDNS client and exit"
    )
    var test: String?
    
    func run() async throws {
        // Parse excluded CIDR ranges
        let cidrRanges = exclude.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }

        if let testHost = test?.trimmingCharacters(in: .whitespacesAndNewlines), !testHost.isEmpty {
            try await runTest(for: testHost)
            return
        }
        
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

    private func runTest(for host: String) async throws {
        let cidrRanges = exclude.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        let resolver = try DNSResolverAdapter(excludedCIDRRanges: cidrRanges)

        print("DNS-to-mDNS Test")
        print("================")
        print("Resolving \(host) via internal mDNS client")
        print("Excluded IP ranges: \(cidrRanges.joined(separator: ", "))")
        print("")

        if let ipv4Data = await resolver.resolveIPv4(hostname: host) {
            let address = ipv4Data.map { String($0) }.joined(separator: ".")
            print("A record for \(host):")
            print("  \(address)")
        } else {
            print("No usable A record found for \(host)")
            throw ExitCode.failure
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

Task {
    await DNSProxyCommand.main()
    exit(EXIT_SUCCESS)
}

dispatchMain()
