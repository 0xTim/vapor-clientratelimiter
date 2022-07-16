import Vapor
import Fluent
import FluentSQL

public struct ClientRateLimiter {
    let byteBufferAllocator: ByteBufferAllocator
    let logger: Logger
    let client: Client
    let db: Database
    let config: RateLimiterConfig
    
    public init(byteBufferAllocator: ByteBufferAllocator, logger: Logger, client: Client, db: Database, config: RateLimiterConfig) {
        self.byteBufferAllocator = byteBufferAllocator
        self.logger = logger
        self.client = client
        self.db = db
        self.config = config
    }
    
    func `for`(req: Request) -> ClientRateLimiter {
        return ClientRateLimiter(byteBufferAllocator: req.byteBufferAllocator, logger: req.logger, client: req.client, db: req.db, config: self.config)
    }
    
    func send(_ request: ClientRequest) async throws -> ClientResponse {
        
        guard let host = request.url.host else {
            throw Abort(.badRequest, reason: "No host supplied")
        }
        
        let responseStorage = ClientResponseStorage()
        
        try await db.transaction { transactionDB in
            guard let transaction = transactionDB as? SQLDatabase else {
                throw Abort(.internalServerError)
            }
            // Try and get a lock on the table
            try await transaction.raw("LOCK TABLE ONLY \"\(raw: RateLimitedRequest.schema)\" IN ACCESS EXCLUSIVE MODE;").run()
            
            // See if any requests queued
            let pendingRequestsCount = try await RateLimitedRequest.query(on: transactionDB).filter(\.$host == host).sort(\.$requestedAt).count()
            
            if pendingRequestsCount == 0 {
                try await waitForNextRequestInterval(host: host, transactionDB: transactionDB)
            } else {
                let requestTime = Date()
                let timeoutTime = requestTime.addingTimeInterval(config.timeout)
                let pendingRequest = RateLimitedRequest(id: UUID(), host: host, requestedAt: requestTime)
                try await pendingRequest.create(on: transactionDB)
                
                // Wait til our request reaches the top
                while try await RateLimitedRequest.query(on: transactionDB).filter(\.$host == host).sort(\.$requestedAt).first()?.id != pendingRequest.id {
                    if Date() > timeoutTime {
                        try await pendingRequest.delete(on: transactionDB)
                        throw RateLimiterError.timeout
                    }
                    try await Task.sleep(nanoseconds: UInt64(config.requestInterval * 1_000_000))
                }
                
#warning("Do we need to wait for host request time?")
                
            }
                
            // Ours is next to process
            let actualRequestTime = Date()
            let clientResponse = try await client.send(request)
            await responseStorage.updateResponse(clientResponse)
            
            try await transaction.raw("LOCK TABLE ONLY \"\(raw: HostRequestTime.schema)\" IN ACCESS EXCLUSIVE MODE;").run()
            if let existingHostRequestTime = try await HostRequestTime.query(on: transactionDB).filter(\.$host == host).first() {
                existingHostRequestTime.lastRequestedAt = actualRequestTime
                try await existingHostRequestTime.update(on: transactionDB)
            } else {
                let newTime = HostRequestTime(host: host, lastRequestedAt: actualRequestTime)
                try await newTime.create(on: transactionDB)
            }
        }
        
        guard let response = await responseStorage.clientResponse else {
            throw RateLimiterError.noResponse
        }
        return response
    }
    
    func waitForNextRequestInterval(host: String, transactionDB: Database) async throws {
        if let existingHostRequestTime = try await HostRequestTime.query(on: transactionDB).filter(\.$host == host).first() {
            let nextRequestTime = existingHostRequestTime.lastRequestedAt.addingTimeInterval(config.requestInterval)
            if Date() >= nextRequestTime {
                // We're past the time, return
                return
            } else {
                let timeUntilNextRequest = Date().distance(to: nextRequestTime)
                try await Task.sleep(nanoseconds: UInt64(timeUntilNextRequest * 1_000_000))
            }
        } else {
            // No requests yet to this host, return
        }
    }
}

enum RateLimiterError: Error {
    case timeout
    case noResponse
}

actor ClientResponseStorage {
    var clientResponse: ClientResponse? = nil
    
    func updateResponse(_ newResponse: ClientResponse) {
        self.clientResponse = newResponse
    }
}
