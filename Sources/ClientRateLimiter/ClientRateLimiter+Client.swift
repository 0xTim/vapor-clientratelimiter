import Vapor

extension ClientRateLimiter {
    public func get(_ url: URI, headers: HTTPHeaders = [:], beforeSend: (inout ClientRequest) throws -> () = { _ in }) async throws -> ClientResponse {
        try await self.send(.GET, headers: headers, to: url, beforeSend: beforeSend)
    }

    public func post(_ url: URI, headers: HTTPHeaders = [:], beforeSend: (inout ClientRequest) throws -> () = { _ in }) async throws -> ClientResponse {
        try await self.send(.POST, headers: headers, to: url, beforeSend: beforeSend)
    }

    public func patch(_ url: URI, headers: HTTPHeaders = [:], beforeSend: (inout ClientRequest) throws -> () = { _ in }) async throws -> ClientResponse {
        try await self.send(.PATCH, headers: headers, to: url, beforeSend: beforeSend)
    }

    public func put(_ url: URI, headers: HTTPHeaders = [:], beforeSend: (inout ClientRequest) throws -> () = { _ in }) async throws -> ClientResponse {
        try await self.send(.PUT, headers: headers, to: url, beforeSend: beforeSend)
    }

    public func delete(_ url: URI, headers: HTTPHeaders = [:], beforeSend: (inout ClientRequest) throws -> () = { _ in }) async throws -> ClientResponse {
        try await self.send(.DELETE, headers: headers, to: url, beforeSend: beforeSend)
    }
    
    public func post<T>(_ url: URI, headers: HTTPHeaders = [:], content: T) async throws -> ClientResponse where T: Content {
        try await self.post(url, headers: headers, beforeSend: { try $0.content.encode(content) })
    }

    public func patch<T>(_ url: URI, headers: HTTPHeaders = [:], content: T) async throws -> ClientResponse where T: Content {
        try await self.patch(url, headers: headers, beforeSend: { try $0.content.encode(content) })
    }

    public func put<T>(_ url: URI, headers: HTTPHeaders = [:], content: T) async throws -> ClientResponse where T: Content {
        try await self.put(url, headers: headers, beforeSend: { try $0.content.encode(content) })
    }

    public func send(
        _ method: HTTPMethod,
        headers: HTTPHeaders = [:],
        to url: URI,
        beforeSend: (inout ClientRequest) throws -> () = { _ in }
    ) async throws -> ClientResponse {
        var request = ClientRequest(method: method, url: url, headers: headers, body: nil, byteBufferAllocator: self.byteBufferAllocator)
        try beforeSend(&request)
        return try await self.send(request)
    }
}
