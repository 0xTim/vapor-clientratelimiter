import Vapor
import Fluent
import FluentSQL

public struct ClientRateLimiter {
    let byteBufferAllocator: ByteBufferAllocator
    let logger: Logger
    let client: Client
    let db: Database
    let config: RateLimiterConfig
    let dateFormatter = DateFormatter()
    
    public init(byteBufferAllocator: ByteBufferAllocator, logger: Logger, client: Client, db: Database, config: RateLimiterConfig) {
        self.byteBufferAllocator = byteBufferAllocator
        self.logger = logger
        self.client = client
        self.db = db
        self.config = config
        dateFormatter.dateFormat = "y-MM-dd H:mm:ss.SSSS"
    }
    
    func `for`(req: Request) -> ClientRateLimiter {
        return ClientRateLimiter(byteBufferAllocator: req.byteBufferAllocator, logger: req.logger, client: req.client, db: req.db, config: self.config)
    }
    
    func send(_ request: ClientRequest) async throws -> ClientResponse {
        
        guard let host = request.url.host else {
            throw Abort(.badRequest, reason: "No host supplied")
        }
        
        let requestTime = Date()
        let timeoutTime = requestTime.addingTimeInterval(config.timeout)
        
        let responseStorage = ClientResponseStorage()
        var requestSuccessfullySent = false
        
        while !requestSuccessfullySent {
            if Date() > timeoutTime {
                throw RateLimiterError.timeout
            }
            do {
                try await createTransactionAndWaitForRequestSending(request: request, responseStorage: responseStorage, requestTime: requestTime, timeoutTime: timeoutTime, host: host)
                
                // If we hit this point then we should now have a response
                requestSuccessfullySent = true
            } catch {
                // Caught an error because we're exhausted on connections/transactions. Wait for next interval and try agin
                let requestInterval = config.requestInterval(for: host)
                try await Task.sleep(nanoseconds: UInt64(requestInterval * 1_000_000))
            }
        }
        
        guard let response = await responseStorage.clientResponse else {
            throw RateLimiterError.noResponse
        }
        return response
    }
    
    func createTransactionAndWaitForRequestSending(request: ClientRequest, responseStorage: ClientResponseStorage, requestTime: Date, timeoutTime: Date, host: String) async throws {
        try await db.transaction { transactionDB in
            guard let transaction = transactionDB as? SQLDatabase else {
                throw Abort(.internalServerError)
            }
            
            // Wait until we get a lock on the table
            var gotTableLock = false
            
            let requestInterval = config.requestInterval(for: host)
            
            while !gotTableLock {
                if Date() > timeoutTime {
                    throw RateLimiterError.timeout
                }
                
                do {
                    try await transaction.raw("LOCK TABLE ONLY \"\(raw: RateLimitedRequest.schema)\" IN ACCESS EXCLUSIVE MODE;").run()
                    
                    // If we reach this point, we got the lock
                    gotTableLock = true
                } catch {
                    // Failed to get locks, sleep until next round
                    try await Task.sleep(nanoseconds: UInt64(requestInterval * 1_000_000))
                }
            }
            
            // Get other table lock - since we have the above lock, that's the entry point so we should be able to request this safely
            try await transaction.raw("LOCK TABLE ONLY \"\(raw: HostRequestTime.schema)\" IN ACCESS EXCLUSIVE MODE;").run()
            
            // See if any requests queued
            let pendingRequestsCount = try await RateLimitedRequest.query(on: transactionDB).filter(\.$host == host).sort(\.$requestedAt).count()
            
            if pendingRequestsCount == 0 {
                try await waitForNextRequestInterval(host: host, transactionDB: transactionDB)
            } else {
                let pendingRequest = RateLimitedRequest(id: UUID(), host: host, requestedAt: requestTime)
                try await pendingRequest.create(on: transactionDB)
                
                // Wait til our request reaches the top
                while try await RateLimitedRequest.query(on: transactionDB).filter(\.$host == host).sort(\.$requestedAt).first()?.id != pendingRequest.id {
                    if Date() > timeoutTime {
                        try await pendingRequest.delete(on: transactionDB)
                        throw RateLimiterError.timeout
                    }
                    try await Task.sleep(nanoseconds: UInt64(requestInterval * 1_000_000))
                }
                try await waitForNextRequestInterval(host: host, transactionDB: transactionDB)
            }
            
            // Ours is next to process
            let actualRequestTime = Date()
            self.logger.debug("Sending request to API at \(dateFormatter.string(from: actualRequestTime))")
            let clientResponse = try await client.send(request)
            await responseStorage.updateResponse(clientResponse)
            
            if let existingHostRequestTime = try await HostRequestTime.query(on: transactionDB).filter(\.$host == host).first() {
                existingHostRequestTime.lastRequestedAt = actualRequestTime
                try await existingHostRequestTime.update(on: transactionDB)
            } else {
                let newTime = HostRequestTime(host: host, lastRequestedAt: actualRequestTime)
                try await newTime.create(on: transactionDB)
            }
        }
    }
    
    func waitForNextRequestInterval(host: String, transactionDB: Database) async throws {
        if let existingHostRequestTime = try await HostRequestTime.query(on: transactionDB).filter(\.$host == host).first() {
            let requestInterval = config.requestInterval(for: host)
            let nextRequestTime = existingHostRequestTime.lastRequestedAt.addingTimeInterval(requestInterval)
            while Date() < nextRequestTime {
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
