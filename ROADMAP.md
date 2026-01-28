# 🗺️ DelamainNetworking Roadmap

Our vision for DelamainNetworking: a best-in-class Swift networking library that's simple to use, powerful when needed, and delightful to test.

---

## ✅ v1.0 — Foundation (Complete)

The core networking layer is production-ready.

- [x] Async/await request methods
- [x] Protocol-based `Endpoint` definition
- [x] `SimpleEndpoint` for quick one-off requests
- [x] Request interceptors (headers, auth, logging)
- [x] Response handlers
- [x] `NetworkError` with comprehensive error cases
- [x] `MockNetworkClient` for testing
- [x] `DomainMappable` protocol for DTO → domain mapping
- [x] Full Swift 6 / Sendable conformance
- [x] CI pipeline (lint + test)
- [x] SwiftLint integration

---

## 🚧 v1.1 — Resilience & Observability

Making network calls more robust and debuggable.

- [ ] **Retry interceptor** — Configurable retry with exponential backoff
- [ ] **Timeout configuration** — Per-request and client-level timeouts
- [ ] **Request/response logging** — Structured logging with redaction support
- [ ] **Metrics collection** — Request duration, success rate, bytes transferred
- [ ] **Network reachability** — Combine/async publisher for connectivity status

---

## 🔮 v1.2 — Advanced Features

Power features for complex apps.

- [ ] **Multipart form data** — File uploads with progress tracking
- [ ] **Download tasks** — Large file downloads with progress & resume
- [ ] **Upload tasks** — Background uploads
- [ ] **Request queuing** — Priority queues, concurrency limits
- [ ] **Caching layer** — Configurable HTTP cache with offline support
- [ ] **Certificate pinning** — SSL pinning for security-critical apps

---

## 🌟 v2.0 — Developer Experience

Taking DX to the next level.

- [ ] **Swift Macros** — Generate endpoint enums from OpenAPI specs
- [ ] **Result builders** — DSL for building complex requests
- [ ] **Xcode previews integration** — Better SwiftUI preview support
- [ ] **Network debugging CLI** — Inspect requests from terminal
- [ ] **Combine bridge** — Publishers for Combine users
- [ ] **Documentation** — Full DocC documentation site

---

## 💡 Ideas & Proposals

Things we're considering but haven't committed to:

- GraphQL support
- WebSocket client
- gRPC support
- Request mocking server (for UI tests)
- Charles/Proxyman integration helpers

---

## Contributing

Have an idea? Open an issue to discuss it before submitting a PR.

Priority is given to features that:
1. Solve real problems we've encountered in our apps
2. Maintain the library's simplicity and testability
3. Don't add unnecessary dependencies

---

## Version History

| Version | Status | Release Date |
|---------|--------|--------------|
| 1.0.0   | ✅ Released | 2026-01-28 |
| 1.1.0   | 🚧 In Progress | TBD |
| 1.2.0   | 📋 Planned | TBD |
| 2.0.0   | 🔮 Future | TBD |
