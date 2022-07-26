# Vapor Client Rate Limiter

Library for throttling requests to third party APIs to ensure you don't exceed a rate limit. Designed to be used when your application scales across multiple instances. Requires Postgres as it uses database locks to queue requests across instances.

## Usage

Setup in **configure.swift**

```swift
let clientRateLimiterConfig = RateLimiterConfig(maxRequestsPerSecond: 5, timeout: 60)
app.clientRateLimiters.use {
    ClientRateLimiter(byteBufferAllocator: $0.allocator, logger: $0.logger, client: $0.client, db: $0.db, config: clientRateLimiterConfig)
}
```

Add the migrations for storing the data:

```swift
app.migrations.add(CreateHostRequestTime())
app.migrations.add(CreateRateLimitedRequest())
```

You can configure the maximum number of requests per second to send and a timeout for requests if you're under heavy load. Then, route requests through the `clientRateLimiter`: 

```swift
let response = try await req.clientRateLimiter.get("https://www.google.com")
```


### Custom Rate Limits Per Site

There is initial support for allowing different sites to have differnt rate limits. You can configure this when setting up the config like so:

```swift
let clientRateLimiterConfig = RateLimiterConfig(defaultMaxRequestsPerSecond: 5, timeout: 60, siteSpecificRPS: [
    "api.google.com": 100,
    "api.mysite.com": 10
])

```
