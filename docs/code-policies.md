# Code Policies

## Architecture Principles

### Command Pattern
All user-facing actions go through commands (`app/commands/`). Controllers should be thin — they call commands and handle redirects.

Commands receive a **context hash** and return `self` with `success?`, `errors`, and `result`.

### Command Chain
When an action requires multiple steps, use `CommandChain` instead of creating a wrapper command that calls other commands.

```ruby
# Good
CommandChain.new(
  [ResolveDownloadCommand, DownloadMangaCommand],
  download_id: params[:id]
).call

# Bad — don't nest commands inside commands
class ReprocessCommand < BaseCommand
  def call
    DownloadMangaCommand.new(@context).call
  end
end
```

### Service Objects
Business logic lives in services (`app/services/`), not in models or controllers. Services are plain Ruby classes initialized with dependencies and called with `#call` or specific methods.

**Dependency Inversion Principle (DIP):**
- No service should know about or instantiate another service. Dependencies are injected via constructor.
- The **job** is the composition root — it wires up the adapter, selector, downloader, and packer, then passes them to the orchestrator.
- Services should not query models they don't own. Use model class methods or scopes instead.

```ruby
# Good — dependencies injected
DownloadOrchestratorService.new(
  download,
  adapter: adapter,
  selector: ChapterSelectorService.new,
  downloader: ImageDownloaderService.new(adapter: adapter),
  packer: CbzPackerService.new
).call

# Bad — service instantiates its own dependencies
class OrchestratorService
  def call
    downloader = ImageDownloaderService.new(adapter: @adapter)  # violation
  end
end
```

### Service Pipeline
When a workflow has multiple sequential responsibilities, split it into steps and run them through `ServicePipeline`. Each step extends `BaseStep`, receives a shared context hash, and does one thing.

```ruby
# Good — small focused steps composed via pipeline
ServicePipeline.new([
  DownloadOrchestratorSteps::FetchMangaInfoStep,
  DownloadOrchestratorSteps::SelectChaptersStep,
  DownloadOrchestratorSteps::DownloadImagesStep
], context).call

# Bad — one service doing everything
class BigService
  def call
    fetch_info
    select_chapters
    download_images
    pack_volumes
    record_results
  end
end
```

### Adapter Pattern
Source-specific logic (fetching manga from MangaDex, etc.) lives in adapters (`app/adapters/`). All adapters implement the same interface defined in `BaseAdapter`. New sources are added via config, not code changes to existing files.

## Code Style

### Controllers
- Thin controllers — delegate to commands
- Return redirects with flash messages
- No business logic

### Models
- Validations, associations, scopes, and simple instance methods only
- No HTTP calls or external service interactions
- Broadcasting via `log!` method is acceptable since it's a model concern

### Services
- One public method per service (usually `#call` or a descriptive name)
- Injected dependencies via constructor
- No direct database writes to unrelated models

### JavaScript
- Stimulus controllers for all interactive behavior
- ActionCable subscriptions managed through `channels/download_channel.js`
- Importmap module names (not relative paths) for imports

## Testing

### Test Organization
- `spec/models/` — model validations, scopes, methods
- `spec/commands/` — command execution, validation, context passing
- `spec/services/` — service logic with mocked dependencies
- `spec/adapters/` — adapter unit tests and integration tests (VCR)
- `spec/jobs/` — job execution and edge cases
- `spec/requests/` — HTTP endpoint integration
- `spec/features/` — user flow tests (Rack::Test)
- `spec/system/` — browser tests with Selenium (ActionCable, JS behavior)

### Test Policies
- External HTTP calls are mocked with WebMock
- VCR cassettes for adapter integration tests
- `ActionCable.server.broadcast` is stubbed in service specs
- System specs use headless Chrome via Selenium
- VCR allows localhost connections (`ignore_localhost = true`) for system tests

## Configuration

### Adding a New Manga Source
1. Create `app/adapters/new_source_adapter.rb` extending `BaseAdapter`
2. Implement all abstract methods
3. Add entry to `config/sources.yml` under `shared.sources`

### Adding a New Language
Add an entry to `config/languages.yml` with the next priority number:
```yaml
- code: de
  priority: 7
```

### Environment Variables
- `SECRET_KEY_BASE` — required for production
- `REDIS_URL` — Redis connection (default: `redis://localhost:6379/0`)
- `RAILS_ENV` — environment (development/test/production)
- `DOWNLOAD_DIR` — host path for downloads volume (default: `~/Comics/Manga`)

## Docker

### Volume Mounts
- `storage_data:/rails/storage` — SQLite databases (persistent)
- `${DOWNLOAD_DIR}:/downloads` — CBZ output directory (maps to host)

### Adding Dependencies
If a new gem requires system packages, update the `apt-get install` line in the Dockerfile for both the base and build stages as needed.
