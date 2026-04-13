# Test Suite

## Running Tests

```bash
# Full suite
bundle exec rspec

# Specific directory
bundle exec rspec spec/commands/
bundle exec rspec spec/services/
bundle exec rspec spec/system/

# Single file
bundle exec rspec spec/commands/command_chain_spec.rb

# With documentation format
bundle exec rspec --format documentation
```

## Test Structure

```
spec/
├── adapters/
│   ├── adapter_registry_spec.rb           # Registration, URL matching
│   ├── mangadex_adapter_spec.rb           # Unit tests with mocked HTTP
│   └── mangadex_adapter_integration_spec.rb # VCR integration tests
├── commands/
│   ├── command_chain_spec.rb              # Chain execution, context passing, error handling
│   └── download_manga_command_spec.rb     # Validation, download creation, job enqueue
├── features/
│   ├── download_flow_spec.rb             # Form submission, active/completed display
│   └── settings_flow_spec.rb            # Settings form persistence
├── jobs/
│   └── download_manga_job_spec.rb        # Job execution, cancellation, throttling
├── models/
│   ├── download_spec.rb                  # Enums, scopes, log broadcasting
│   └── setting_spec.rb                   # Fetch/store behavior
├── requests/
│   ├── downloads_spec.rb                 # HTTP endpoints
│   └── settings_spec.rb                  # HTTP endpoints
├── services/
│   ├── chapter_selector_service_spec.rb  # Language selection, volume filtering
│   ├── download_orchestrator_service_spec.rb # Full workflow, broadcasts
│   └── http_client_service_spec.rb       # Retries, rate limiting, downloads
├── system/
│   └── download_realtime_spec.rb         # WebSocket updates with Selenium
├── factories/
│   ├── downloads.rb                      # Traits: :downloading, :completed, :failed
│   └── download_logs.rb
└── support/
    ├── capybara.rb                       # Selenium headless Chrome config
    ├── factory_bot.rb                    # FactoryBot DSL inclusion
    └── vcr.rb                            # VCR + WebMock config
```

## Test Types

### Unit Tests (models, commands, services, adapters)
Fast, isolated tests. External HTTP is mocked with WebMock. ActionCable broadcasts are stubbed.

### Request Tests
HTTP integration tests hitting controller actions through the full Rails stack.

### Feature Tests
User flow tests using Capybara with the default Rack::Test driver (no JS).

### System Tests
Browser-based tests using Capybara + Selenium + headless Chrome. Required for testing ActionCable WebSocket behavior and Stimulus controllers.

## Key Testing Patterns

### Mocking Adapters
```ruby
let(:adapter) { instance_double(MangadexAdapter) }
before { allow(AdapterRegistry).to receive(:for_url).and_return(adapter) }
```

### Stubbing ActionCable
```ruby
before { allow(ActionCable.server).to receive(:broadcast) }

expect(ActionCable.server).to have_received(:broadcast).with(
  "download_#{download.id}",
  hash_including(type: "status_changed", status: "completed")
)
```

### Stubbing External HTTP (CDN)
```ruby
stub_request(:get, "https://cdn.example.com/data/abc/page1.jpg")
  .to_return(status: 200, body: "fake_image_data")
```

### VCR for Integration Tests
```ruby
it "fetches chapters", vcr: { cassette_name: "mangadex/chapters" } do
  # Real HTTP recorded on first run, replayed on subsequent runs
end
```

### System Tests with ActionCable
System tests run inline Sidekiq jobs so that ActionCable broadcasts happen inside the Puma server process (same process as the browser connection):

```ruby
allow(DownloadMangaJob).to receive(:perform_async) do |download_id|
  DownloadMangaJob.new.perform(download_id)
end
```

## Factories

### Download
```ruby
create(:download)                # queued, with MangaDex URL
create(:download, :downloading)  # status: downloading, with title and manga_id
create(:download, :completed)    # status: completed, progress: 100
create(:download, :failed)       # status: failed, with error_message
create(:download, :with_volumes) # volumes: "1, 2, 3"
```
