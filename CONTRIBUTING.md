# Contributing to DelamainNetworking

## Self-Review Process

Before requesting review on any PR, run through this checklist:

### 1. Automated Checks
- [ ] `swift build` — compiles without warnings
- [ ] `swift test` — all tests pass
- [ ] `swiftlint lint --strict` — no violations

### 2. Code Review (read your own diff)
- [ ] **Naming** — Are types, methods, and variables clearly named?
- [ ] **Documentation** — Are public APIs documented? Complex logic commented?
- [ ] **Edge cases** — Are error cases handled? Nil checks where needed?
- [ ] **Test coverage** — Is new functionality tested? Are edge cases covered?
- [ ] **Consistency** — Does it match existing patterns in the codebase?
- [ ] **No debug code** — No `print()`, hardcoded values, or TODOs left behind

### 3. PR Hygiene
- [ ] **Commit messages** — Clear, descriptive, imperative mood
- [ ] **PR description** — Explains what and why
- [ ] **Scope** — PR does one thing well (not kitchen sink)

### 4. Self-Review Comments
Actually review your own PR on GitHub:
1. Go through the diff file by file
2. Leave comments on anything questionable
3. Address your own comments before requesting review
4. Note any tradeoffs or decisions in PR description

## PR Template

```markdown
## Summary
[What does this PR do?]

## Changes
- [List key changes]

## Testing
- [How was this tested?]

## Self-Review
- [x] Ran through CONTRIBUTING.md checklist
- [x] Left and addressed self-review comments
```

## Code Style

- Swift 6 strict concurrency
- SwiftLint enforced
- Prefer composition over inheritance
- Protocol-first design
- Full test coverage for public APIs
