---
name: VCR cassettes on E2E failure
description: When E2E tests fail, delete and re-record VCR cassettes before debugging further
type: feedback
---

When E2E or integration tests fail, flush VCR cassettes first and re-record them.

**Why:** Cassettes become stale when API params change (new fields, sort order, languages filter). Stale cassettes cause silent mismatches that are hard to debug.

**How to apply:** Before investigating E2E failures, run:
```bash
rm spec/fixtures/vcr_cassettes/mangadex/*.yml
bundle exec rspec spec/adapters/mangadex_adapter_integration_spec.rb
```
Then re-run the failing spec. If it still fails, the issue is in the code, not the cassette.
