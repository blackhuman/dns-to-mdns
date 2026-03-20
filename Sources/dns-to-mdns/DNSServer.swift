import Foundation
import Network
import DNSKit
import os

/// DNS Server - Listens for DNS queries on UDP and responds using mDNS resolution
actor DNSServer {
    private var listener: NWListener?
    private let resolver: DNSResolverAdapter
    private let port: UInt16
    private let queue = DispatchQueue(label: "dns-server", qos: .userInitiated)
    
    private let logger = Logger(subsystem: "com.dns-to-mdns", category: "DNSServer")
    
    enum Error: Swift.Error {
        case failedToCreateListener
        case failedToStart
    }
    
    /// Initialize the DNS server
    /// - Parameters:
    ///   - port: UDP port to listen on
    ///   - excludedCIDRRanges: Array of CIDR strings for IP ranges to exclude from responses
    init(port: UInt16 = 8053, excludedCIDRRanges: [String] = []) throws {
        self.port = port
        self.resolver = try DNSResolverAdapter(excludedCIDRRanges: excludedCIDRRanges)
    }
    
    /// Start the DNS server
    func start() async throws {
        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true
        
        guard let listener = try? NWListener(
            using: .udp,
            on: NWEndpoint.Port(integerLiteral: self.port)
        ) else {
            logger.error("Failed to create listener on port \(self.port)")
            throw Error.failedToCreateListener
        }
        
        self.listener = listener
        
        listener.stateUpdateHandler = { [weak self] state in
            Task { await self?.handleStateChange(state) }
        }
        
        listener.newConnectionHandler = { [weak self] connection in
            Task { await self?.setupConnection(connection) }
        }
        
        listener.start(queue: .global())
        logger.info("DNS server starting on port \(self.port)")
    }
    
    func stop() {
        listener?.cancel()
        listener = nil
        logger.info("DNS server stopped")
    }
    
    private func handleStateChange(_ state: NWListener.State) {
        switch state {
        case .ready:
            logger.info("DNS server ready on port \(self.port)")
        case .failed(let error):
            logger.error("DNS server failed: \(error.localizedDescription)")
        case .cancelled:
            logger.info("DNS server cancelled")
        default:
            break
        }
    }
    
    private func setupConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { state in
            Task {
                if case .ready = state {
                    // await self?.receiveRequest(on: connection)
                } else if case .failed = state {
                    connection.cancel()
                }
            }
        }
        connection.start(queue: queue)
        self.receiveRequest(on: connection)
    }
    
    private func receiveRequest(on connection: NWConnection) {
        connection.receiveMessage { [weak self] content, _, isComplete, error in
            Task {
                if let error = error {
                    await self?.logError("Receive error: \(error.localizedDescription)")
                    connection.cancel()
                    return
                }
                
                guard let data = content, !data.isEmpty else {
                    print("New message error.")
                    return
                }
                
                if let message = String(data: data, encoding: .utf8) {
                    print("New message: \(message)")
                }
                
                await self?.processDNSRequest(data: data, connection: connection)
            }
        }
    }
    
    private func processDNSRequest(data: Data, connection: NWConnection) async {
        logger.info("Received DNS query: \(data.hexEncodedString())")
        
        // Parse incoming DNS message using DNSKit
        guard let query = try? Message(messageData: data) else {
            logger.error("Invalid DNS packet")
            return
        }
        
        guard let question = query.questions.first else {
            logger.warning("No questions in DNS query")
            return
        }
        
        logger.info("Query: \(question.name) type=\(question.recordType.string())")
        
        // Only handle A record queries
        guard question.recordType == RecordType.A else {
            logger.debug("Unsupported query type")
            return
        }
        
        // Build response message
        var responseAnswers: [Answer] = []
        var responseCode = ResponseCode.NOERROR
        
        if let ipv4Data = await resolver.resolveIPv4(hostname: question.name) {
            if let answer = Answer.aRecord(name: question.name, ipv4Address: ipv4Data, ttl: 300) {
                responseAnswers.append(answer)
                logger.info("Resolved \(question.name) to \(ipv4Data.map { String($0) }.joined(separator: "."))")
            }
        } else {
            logger.info("No address found for \(question.name)")
            responseCode = .NXDOMAIN
        }
        
        // Create response message
        let response = Message(
            idNumber: query.idNumber,
            recursionDesired: query.recursionDesired,
            truncated: false,
            authoritativeAnswer: true,
            operationCode: .Query,
            isResponse: true,
            responseCode: responseCode,
            questions: query.questions,
            answers: responseAnswers,
            authority: [],
            additional: [],
            dnssecOK: false
        )
        
        do {
            let responseData = try response.data()
            sendResponse(responseData, on: connection)
        } catch {
            logger.error("Failed to serialize response: \(error)")
        }
    }
    
    private func sendResponse(_ data: Data, on connection: NWConnection) {
        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            Task {
                if let error = error {
                    await self?.logError("Send error: \(error.localizedDescription)")
                } else {
                    await self?.logDebug("Sent response: \(data.count) bytes")
                }
                connection.cancel()
            }
        })
    }
    
    private func logError(_ message: String) {
        logger.error("\(message)")
    }
    
    private func logDebug(_ message: String) {
        logger.debug("\(message)")
    }
}

extension Data {
    func hexEncodedString() -> String {
        map { String(format: "%02hhx", $0) }.joined()
    }
}
