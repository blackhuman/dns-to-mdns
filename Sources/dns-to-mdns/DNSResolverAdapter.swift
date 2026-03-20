import Foundation
import Network
import AsyncDNSResolver

/// Adapter wrapper around AsyncDNSResolver for mDNS resolution
/// Provides a simplified API for resolving hostnames to IPv4 addresses with optional IP range filtering
class DNSResolverAdapter {
    private let resolver: AsyncDNSResolver
    private let fullResolver = DNSResolver()
    private let excludedCIDRRanges: [IPv4Network]
    
    /// Initialize the resolver adapter
    /// - Parameter excludedCIDRRanges: Array of CIDR strings to filter out (e.g., ["198.18.0.0/16"])
    init(excludedCIDRRanges: [String]) throws {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        let options = DNSSDDNSResolver.Options(flags: [.timeout, .forceMulticast])
        self.resolver = AsyncDNSResolver(options: options)
        #else
        self.resolver = try AsyncDNSResolver()
        #endif
        self.excludedCIDRRanges = try excludedCIDRRanges.map { try IPv4Network(cidr: $0) }
    }
    
    /// Resolve a hostname to an IPv4 address
    /// - Parameter hostname: The hostname to resolve (e.g., "mydevice.local")
    /// - Returns: IPv4 address as 4-byte Data, or nil if resolution fails or all results are filtered
    func resolveIPv4(hostname: String) async -> Data? {
        // Try full host resolve first using DNSServiceGetAddrInfo
        // do {
        //     print("Trying DNSServiceGetAddrInfo (mDNS) for \(hostname)...")
        //     let ipStrings = try await fullResolver.resolve(host: hostname)
        //     print("  Successfully resolved \(ipStrings.count) IP(s) via DNSServiceGetAddrInfo: \(ipStrings.joined(separator: ", "))")
            
        //     for ipString in ipStrings {
        //         if let ipv4Address = IPv4Address(ipString) {
        //             if isIPExcluded(ipv4Address) {
        //                 print("  ⚠️  Excluded: \(ipv4Address)")
        //             } else {
        //                 print("  ✅ Using (mDNS): \(ipv4Address)")
        //                 return ipv4Address.data
        //             }
        //         }
        //     }
        // } catch {
        //     print("  DNSServiceGetAddrInfo failed for \(hostname): \(error)")
        // }

        do {
            // fallback to Query for A records
            print("Falling back to AsyncDNSResolver for \(hostname)...")
            let records = try await resolver.queryA(name: hostname)
            
            print("Found \(records.count) A record(s) for \(hostname):")
            for record in records {
                print("  - \(record.address.address)")
            }
            
            // Filter out excluded IP ranges
            for record in records {
                guard let ipv4Address = IPv4Address(record.address.address) else {
                    continue
                }
                
                if isIPExcluded(ipv4Address) {
                    print("  ⚠️  Excluded: \(ipv4Address)")
                    continue
                }
                
                print("  ✅ Using: \(ipv4Address)")
                return ipv4Address.data
            }
            
            print("  No usable IP addresses found (all filtered or resolution failed)")
            return nil
            
        } catch {
            print("DNS resolution failed for \(hostname): \(error)")
            return nil
        }
    }
    
    /// Check if an IP address falls within any excluded range
    /// - Parameter ipv4Address: IPv4 address to check
    /// - Returns: true if the IP should be excluded
    private func isIPExcluded(_ ipv4Address: IPv4Address) -> Bool {
        for network in excludedCIDRRanges {
            if network.contains(ipv4Address) {
                return true
            }
        }
        return false
    }
}

/// Represents an IPv4 network in CIDR notation
private struct IPv4Network {
    let networkAddress: IPv4Address
    let prefixLength: UInt8
    
    /// Parse CIDR notation (e.g., "198.18.0.0/16")
    init(cidr: String) throws {
        let parts = cidr.split(separator: "/")
        guard parts.count == 2 else {
            throw NSError(domain: "Invalid CIDR", code: 1, userInfo: [NSLocalizedDescriptionKey: "Expected format: x.x.x.x/n"])
        }
        
        guard let networkAddr = IPv4Address(String(parts[0])) else {
            throw NSError(domain: "Invalid IP", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid IPv4 address"])
        }
        self.networkAddress = networkAddr
        
        guard let prefix = UInt8(parts[1]), prefix <= 32 else {
            throw NSError(domain: "Invalid prefix", code: 3, userInfo: [NSLocalizedDescriptionKey: "Prefix must be 0-32"])
        }
        self.prefixLength = prefix
    }
    
    /// Check if an IP address is within this network
    func contains(_ address: IPv4Address) -> Bool {
        guard let addressBytes = address.bytes, let networkBytes = networkAddress.bytes else {
            return false
        }
        
        let mask = prefixLength == 0 ? 0 : ~UInt32(0) << (32 - prefixLength)
        let addressRaw = UInt32(addressBytes.0) << 24 | UInt32(addressBytes.1) << 16 | 
                         UInt32(addressBytes.2) << 8 | UInt32(addressBytes.3)
        let networkRaw = UInt32(networkBytes.0) << 24 | UInt32(networkBytes.1) << 16 | 
                         UInt32(networkBytes.2) << 8 | UInt32(networkBytes.3)
        
        return (addressRaw & mask) == (networkRaw & mask)
    }
}

private extension IPv4Address {
    /// Get the four octets as a tuple, or nil if not a valid IPv4 address
    var bytes: (UInt8, UInt8, UInt8, UInt8)? {
        guard self.rawValue.count == 4 else { return nil }
        return (self.rawValue[0], self.rawValue[1], self.rawValue[2], self.rawValue[3])
    }
    
    /// Get IPv4 address as 4-byte Data in network byte order
    var data: Data {
        guard let bytes = self.bytes else { return Data() }
        return Data([bytes.0, bytes.1, bytes.2, bytes.3])
    }
}
