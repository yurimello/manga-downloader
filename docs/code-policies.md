# Code Policies

## Architecture Principles

### Command Pattern
All user-facing actions go through commands (`app/commands/`). Controllers should be thin — they call commands and handle redirects.

Commands receive a **context hash** and return `self` with `success?`, `errors`, and `result`.

### Command Composition
When an action requires multiple steps, use `Interactor::Organizer` to compose commands. Don't nest command calls inside other commands.

```ruby
# Good — organizer composes commands
class ReprocessDownloadCommand
  include Interactor::Organizer
  organize ResolveDownloadCommand, DownloadMangaCommand
end

# Bad — command calling another command
class ReprocessCommand < BaseCommand
  def call
    DownloadMangaCommand.call(context)
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
# Good — small focused steps composed via Interactor::Organizer
class DownloadOrchestratorService
  include Interactor::Organizer

  organize FetchMangaInfoStep,
           SelectChaptersStep,
           DownloadImagesStep
end

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

### Observer Pattern
Steps and commands must never call ActionCable directly. Use observers passed via `context.observers` to decouple broadcasting from business logic.

Steps that change download status declare an `after` hook to notify observers. Steps use `notify_observers` for explicit notifications like progress updates. Errors are caught in the orchestrator's `around` hook.

```ruby
class MyStep < BaseStep
  after { notify_observers(:on_status_changed) }

  def call
    download.update!(status: :downloading)
  end
end
```

Observers extend `ContextObserver` and implement:
- `on_status_changed(context)` — called automatically after each step via `after` hook
- `on_progress_updated(context)` — called explicitly for per-image progress
- `on_error(context, error)` — called from orchestrator's `around` hook on failure

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
