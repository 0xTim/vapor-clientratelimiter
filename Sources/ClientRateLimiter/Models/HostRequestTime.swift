import Fluent

final class HostRequestTime: Model {
    static let schema = "host_request_time"
    
    @ID
    var id: UUID?
    
    @Field(key: "host")
    var host: String
    
    @Field(key: "lastRequestedAt")
    var lastRequestedAt: Date
    
    init() {}
    
    init(id: UUID? = nil, host: String, lastRequestedAt: Date) {
        self.id = id
        self.host = host
        self.lastRequestedAt = lastRequestedAt
    }
}
