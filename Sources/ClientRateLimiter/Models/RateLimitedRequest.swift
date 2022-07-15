import Fluent

final class RateLimitedRequest: Model {
    static let schema = "rate_limited_request"
    
    @ID
    var id: UUID?
    
    @Field(key: "host")
    var host: String
    
    @Field(key: "requestedAt")
    var requestedAt: Date
    
    @Field(key: "requestDetails")
    var requestDetails: String
    
    init() {}
    
    init(id: UUID? = nil, host: String, requestedAt: Date, requestDetails: String) {
        self.id = id
        self.host = host
        self.requestedAt = requestedAt
        self.requestDetails = requestDetails
    }
}
