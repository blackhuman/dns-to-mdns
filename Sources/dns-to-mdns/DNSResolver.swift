import Foundation
import dnssd
import Network

/// Wrapper for DNSServiceGetAddrInfo from the dnssd framework
@available(*, deprecated, message: "Use DNSResolverAdapter for mDNS lookups so CLI test mode and server mode share the same resolution path.")
actor DNSResolver {
    
    private final class ResolveContext: @unchecked Sendable {
        private let lock = NSLock()
        private var addresses: [String] = []
        private var continuation: CheckedContinuation<[String], Error>?
        private var finished = false
        private var _serviceRef: DNSServiceRef?
        
        init(continuation: CheckedContinuation<[String], Error>) {
            self.continuation = continuation
        }
        
        var isFinished: Bool {
            lock.lock()
            defer { lock.unlock() }
            return finished
        }
        
        var serviceRef: DNSServiceRef? {
            get {
                lock.lock()
                defer { lock.unlock() }
                return _serviceRef
            }
            set {
                lock.lock()
                _serviceRef = newValue
                lock.unlock()
            }
        }
        
        func addAddress(_ address: String) {
            lock.lock()
            defer { lock.unlock() }
            
            if !addresses.contains(address) {
                addresses.append(address)
            }
        }
        
        func finish(with error: Error? = nil) {
            let continuationToResume: CheckedContinuation<[String], Error>?
            let addressesToReturn: [String]
            let serviceRefToDeallocate: DNSServiceRef?
            
            lock.lock()
            if finished {
                lock.unlock()
                return
            }
            
            finished = true
            continuationToResume = continuation
            continuation = nil
            addressesToReturn = addresses
            serviceRefToDeallocate = _serviceRef
            _serviceRef = nil
            lock.unlock()
            
            if let serviceRefToDeallocate {
                DNSServiceRefDeallocate(serviceRefToDeallocate)
            }
            
            if let error {
                continuationToResume?.resume(throwing: error)
            } else {
                continuationToResume?.resume(returning: addressesToReturn)
            }
        }
    }
    
    /// Resolve a hostname to a list of IP address strings
    /// - Parameter host: The hostname to resolve (e.g., "mydevice.local")
    /// - Returns: List of IPv4 address strings
    func resolve(host: String) async throws -> [String] {
        return try await withCheckedThrowingContinuation { continuation in
            let context = ResolveContext(continuation: continuation)
            
            // Callback function (C convention)
            let callback: DNSServiceGetAddrInfoReply = { (sdRef, flags, interfaceIndex, errorCode, hostname, address, ttl, contextPtr) in
                guard let contextPtr = contextPtr else { return }
                
                // Get the context object (without taking ownership yet)
                let context = Unmanaged<ResolveContext>.fromOpaque(contextPtr).takeUnretainedValue()
                
                if errorCode != kDNSServiceErr_NoError {
                    context.finish(with: NSError(domain: "DNSServiceError", code: Int(errorCode)))
                    // Error occurred, we stop
                    _ = Unmanaged<ResolveContext>.fromOpaque(contextPtr).takeRetainedValue()
                    return
                }
                
                if let address = address {
                    // Parse sockaddr structure to get IP string
                    var ipAddress = [Int8](repeating: 0, count: Int(INET6_ADDRSTRLEN))
                    let family = Int32(address.pointee.sa_family)
                    
                    if family == AF_INET {
                        let sin = address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                        var addr = sin.sin_addr
                        inet_ntop(AF_INET, &addr, &ipAddress, socklen_t(INET_ADDRSTRLEN))
                        let ipString = ipAddress.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
                        context.addAddress(ipString)
                    }
                }
                
                // Check if there are more results coming
                let moreComing = (flags & UInt32(kDNSServiceFlagsMoreComing)) != 0
                
                if !moreComing {
                    // No more results for now, resolve the continuation
                    context.finish()
                    
                    // Release the context reference
                    _ = Unmanaged<ResolveContext>.fromOpaque(contextPtr).takeRetainedValue()
                }
            }
            
            // Wrap context into opaque pointer
            let contextPtr = Unmanaged.passRetained(context).toOpaque()
            var sdRef: DNSServiceRef?
            
            // Flags: kDNSServiceFlagsForceMulticast forces mDNS query
            let flags: DNSServiceFlags = UInt32(kDNSServiceFlagsForceMulticast)
            
            let err = DNSServiceGetAddrInfo(&sdRef,
                                            flags,
                                            0, // InterfaceIndex
                                            DNSServiceProtocol(kDNSServiceProtocol_IPv4),
                                            host,
                                            callback,
                                            contextPtr)
            
            if err != kDNSServiceErr_NoError {
                _ = Unmanaged<ResolveContext>.fromOpaque(contextPtr).takeRetainedValue()
                continuation.resume(throwing: NSError(domain: "DNSServiceError", code: Int(err)))
                return
            }
            
            context.serviceRef = sdRef
            
            // Process results
            DispatchQueue.global().async {
                while !context.isFinished {
                    if let ref = context.serviceRef {
                        let processErr = DNSServiceProcessResult(ref)
                        if processErr != kDNSServiceErr_NoError {
                            context.finish(with: NSError(domain: "DNSServiceError", code: Int(processErr)))
                            break
                        }
                    } else {
                        break
                    }
                }
            }
        }
    }
}
