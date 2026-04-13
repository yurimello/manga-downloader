# Test Suite

## Running Tests

```bash
# Full suite
bundle exec rspec

# By category
bundle exec rspec spec/commands/
bundle exec rspec spec/services/
bundle exec rspec spec/system/
bundle exec rspec spec/e2e/

# Single file
bundle exec rspec spec/commands/download_manga_command_spec.rb

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
│   ├── download_manga_command_spec.rb     # Validation, download creation, job enqueue
│   ├── reprocess_download_command_spec.rb # Organizer chain execution
│   └── validate_destination_command_spec.rb # Destination validation, observer notification
├── e2e/
│   └── download_flow_e2e_spec.rb          # Full lifecycle: download, volumes, reprocess, cancel, settings
├── features/
│   ├── download_flow_spec.rb             # Form submission, active/completed display
│   └── settings_flow_spec.rb            # Settings form, validation errors
├── jobs/
│   └── download_manga_job_spec.rb        # Job execution, cancellation, throttling
├── models/
│   ├── download_spec.rb                  # Enums, scopes, log creation
│   ├── download_observer_spec.rb         # Observable: status, progress, log notifications
│   ├── setting_spec.rb                   # Fetch/store behavior
│   └── setting_observer_spec.rb          # Observable: validation error notifications
├── requests/
│   ├── downloads_spec.rb                 # HTTP endpoints
│   └── settings_spec.rb                  # HTTP endpoints, validation errors
├── services/
│   ├── chapter_selector_service_spec.rb  # Language selection, volume filtering
│   ├── download_orchestrator_service_spec.rb # Full workflow, Observable broadcasts
│   └── http_client_service_spec.rb       # Retries, rate limiting
├── system/
│   └── download_realtime_spec.rb         # Progress bar, Stimulus + ActionCable
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
Fast, isolated tests. External HTTP is mocked with WebMock. Observable behavior tested with instance_double observers.

### Request Tests
HTTP integration tests hitting controller actions through the full Rails stack.

### Feature Tests
User flow tests using Capybara with the default Rack::Test driver (no JS).

### System Tests
Browser-based tests using Capybara + Selenium + headless Chrome. Required for testing ActionCable WebSocket behavior, progress bar updates, and Stimulus controllers.

### E2E Tests
Full lifecycle tests using Capybara + Selenium. Cover the entire flow from form submission to CBZ file on disk. Sidekiq jobs run inline. Verify:
- Download completes and CBZ exists
- Volume selection works
- Reprocess skips downloaded volumes
- Cancel works
- Destination validation errors shown
- Settings validation errors shown

## Key Testing Patterns

### Observable Behavior
```ruby
let(:observer) { instance_double(ContextObserver) }
before { allow(observer).to receive(:on_status_changed) }

download.add_observer(observer)
download.update!(status: :downloading)
expect(observer).to have_received(:on_status_changed).with(download)
```

### Progress Notification (no DB write)
```ruby
download.notify(:on_progress_updated, 50)
expect(observer).to have_received(:on_progress_updated).with(download, 50)
```

### Mocking Adapters
```ruby
let(:adapter) { instance_double(MangadexAdapter) }
before { allow(AdapterRegistry).to receive(:for_url).and_return(adapter) }
```

### Stubbing External HTTP (CDN)
```ruby
stub_request(:get, %r{https://cdn\.example\.com/data/abc/.*})
  .to_return(status: 200, body: "fake_image_data")
```

### Inline Sidekiq for E2E
```ruby
allow(DownloadMangaJob).to receive(:perform_async) do |download_id|
  DownloadMangaJob.new.perform(download_id)
end
```

### Safe Destination in Tests
All specs that trigger downloads set a temp directory — never write to real folders:
```ruby
Setting.store(:destination_root, Dir.mktmpdir)
```

## Factories

### Download
```ruby
create(:download)                # queued, with MangaDex URL
create(:download, :downloading)  # status: downloading, with title and manga_id
create(:download, :completed)    # status: completed
create(:download, :failed)       # status: failed, with error_message
create(:download, :with_volumes) # volumes: "1, 2, 3"
```
