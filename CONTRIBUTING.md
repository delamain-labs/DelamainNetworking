# Contributing to DelamainNetworking

## Self-Review Process

Before requesting review on any PR, run through this checklist:

### 1. Automated Checks
- [ ] `swift build` — compiles without warnings
- [ ] `swift test` — all tests pass
- [ ] `swiftlint lint --strict` — no violations

### 2. Code Review (read your own diff)
- [ ] **Naming** — Are types, methods, and variables clearly named?
- [ ] **Documentation** — Are public APIs documented?
- [ ] **Edge cases** — Are error cases handled?
- [ ] **Test coverage** — Is new functionality tested?
- [ ] **Consistency** — Does it match existing patterns?

### 3. PR Hygiene
- [ ] Clear commit messages
- [ ] PR does one thing well

## Code Style

- Swift 6 strict concurrency
- SwiftLint enforced
- Protocol-first design
- Full test coverage for public APIs
