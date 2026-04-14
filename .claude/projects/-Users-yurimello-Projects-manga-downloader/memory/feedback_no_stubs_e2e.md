---
name: No stubs in E2E tests
description: E2E tests must not stub anything — VCR handles all external API requests
type: feedback
---

E2E tests must not use `allow`, `instance_double`, `stub_request`, or any mocking. VCR handles all external HTTP. E2E tests should exercise the real code path end to end.

**Why:** Stubs create false positives — they bypass real code paths and return whatever you tell them to, hiding real bugs.

**How to apply:** In `spec/e2e/`, never use `allow(...).to receive(...)` or `stub_request`. Use VCR cassettes for external APIs. Use real adapter instances, real services, real models.
