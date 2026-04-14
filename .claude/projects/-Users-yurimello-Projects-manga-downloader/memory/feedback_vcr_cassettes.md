---
name: Always VCR, never WebMock for API stubs
description: Use VCR cassettes for all external API stubs. Flush cassettes before running E2E tests.
type: feedback
---

ALWAYS use VCR cassettes instead of WebMock for external API stubs. WebMock creates false positives — it returns data regardless of actual query params.

**Why:** WebMock stubs don't validate the request params match what the code actually sends. VCR records real API responses tied to exact request URLs.

**How to apply:**
1. Before running E2E tests, flush cassettes: `rm spec/fixtures/vcr_cassettes/mangadex/*.yml`
2. Re-record: `bundle exec rspec spec/adapters/mangadex_adapter_integration_spec.rb`
3. Then run E2E tests
4. For system tests where VCR cassettes don't span Puma threads, this is the one exception where WebMock is acceptable — but document why.
