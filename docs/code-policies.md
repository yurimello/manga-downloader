# Code Policies

## Architecture Principles

### Command Pattern
All user-facing actions go through commands (`app/commands/`). Controllers should be thin — they call commands and handle redirects.

Commands use the `interactor` gem. They receive context via `Interactor::Context` and fail with `context.fail!(message: "...")`.

### Command Composition
When an action requires multiple steps, use `Interactor::Organizer` to compose commands. Don't nest command calls inside other commands.

```ruby
# Good — organizer composes commands
class ReprocessDownloadCommand
  include Interactor::Organizer
  organize ResolveDownloadCommand, ValidateDestinationCommand, DownloadMangaCommand
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
- No business service should know about or instantiate another business service. Dependencies are declared via the `step` DSL with lazy defaults.
- Utility services (`app/services/service_utils/`) can be instantiated directly — they are infrastructure, not domain logic. Namespaced under `ServiceUtils::`.
- The orchestrator's `initialize` resolves orchestrator-level dependencies (`dependency`), and `call` resolves per-step dependencies (`step ... dependencies:`) — both skip keys already present in context.
- Callers can override any dependency: `DownloadOrchestratorService.call(download: d, packer: CustomPacker.new)`
- Services should not query models they don't own. Use model class methods or scopes instead.

**Lib classes** (`lib/`) provide shared utilities:
- `SystemUtils` — filesystem abstraction, called as module methods (`SystemUtils.join`, `SystemUtils.mkdir_p`, etc.)
- `LanguageConfig` — language codes/priorities from YAML config
- `InteractorStepDefinitions` — DSL module for declaring step dependencies
- `Observable` — observer pattern module (add_observer, notify), included by models

```ruby
# Good — defaults declared per step, caller overrides what it needs
DownloadOrchestratorService.call(download: download)
DownloadOrchestratorService.call(download: download, packer: CustomPacker.new)

# Bad — service instantiates its own dependencies inline
class OrchestratorService
  def call
    downloader = ImageDownloaderService.new(adapter: @adapter)  # violation
  end
end
```

### Interactor Pipeline
When a workflow has multiple sequential responsibilities, split it into steps using `Interactor::Organizer`. Each step inherits `BaseStep`, receives shared `Interactor::Context`, and does one thing.

```ruby
# Good — steps with declarative dependencies via InteractorStepDefinitions DSL
class DownloadOrchestratorService
  include Interactor::Organizer
  extend InteractorStepDefinitions

  step FetchMangaInfoStep,
       dependencies: { adapter: -> (ctx) { AdapterRegistry.for_url(ctx[:download].url) } }

  step SelectChaptersStep,
       dependencies: { selector: -> { ChapterSelectorService.new } }

  dependency observers: -> { [DownloadBroadcastObserver.new] }
end

# Bad — one service doing everything
class BigService
  def call
    fetch_info
    select_chapters
    download_images
  end
end
```

### Adapter Pattern
Source-specific logic (fetching manga from MangaDex, etc.) lives in adapters (`app/adapters/`). All adapters implement the same interface defined in `BaseAdapter`. New sources are added via config, not code changes to existing files.

### Observer Pattern
Models include `Observable` from `lib/observable.rb`. State changes trigger observer notifications automatically via ActiveRecord callbacks. No step, service, or command touches ActionCable directly.

- Models define their own callbacks (e.g., `after_update :notify_status_changed`)
- Models call `notify(:event, *args)` which triggers all registered observers
- Observers extend `ContextObserver` and implement event methods
- Progress uses `notify` without DB writes — only broadcasts via observer

```ruby
# Model defines when to notify
class Download < ApplicationRecord
  include Observable
  after_update :notify_status_changed, if: -> { saved_change_to_attribute?("status") }
end

# Observer handles broadcasting
class DownloadBroadcastObserver < ContextObserver
  def on_status_changed(download)
    ActionCable.server.broadcast(...)
  end
end
```

Observers extend `ContextObserver` and implement:
- `on_status_changed(download)` — download status changed (automatic via after_update)
- `on_progress_updated(download, progress)` — per-image progress (explicit notify, no DB write)
- `on_log_added(download, message, level)` — log entry created (via `log!`)
- `on_error(source, error)` — failure or validation error

### Shared Behavior Scope Rules
- **All steps** use it → put in `BaseStep`
- **Some steps** use it → extract to a module in `app/services/concerns/`
- **One step** uses it → private method in that step

## Code Style

### Controllers
- Thin controllers — delegate to commands
- Return redirects with flash messages
- No business logic

### Models
- Validations, associations, scopes, and simple instance methods only
- Include `Observable` for real-time notifications
- No direct ActionCable calls — use `notify` which triggers observers
- Services can update models they own (e.g., steps update the download they orchestrate)
- Services must not update models they don't own (e.g., a download step must not update a `User`)

### Services
- One public method per service (usually `#call` or a descriptive name)
- Use `SystemUtils` module methods for filesystem operations — no direct `File`/`Dir`/`FileUtils`
- Progress is transient — notify via Observable, don't persist to DB

### JavaScript
- Stimulus controllers for all interactive behavior
- ActionCable subscriptions managed through channel JS modules
- Importmap module names (not relative paths) for imports

## Testing

### Test Organization
- `spec/models/` — model validations, scopes, Observable behavior
- `spec/commands/` — command execution, validation, context passing
- `spec/services/` — service logic with mocked dependencies
- `spec/adapters/` — adapter unit tests and integration tests (VCR)
- `spec/jobs/` — job execution and edge cases
- `spec/requests/` — HTTP endpoint integration
- `spec/features/` — user flow tests (Rack::Test)
- `spec/system/` — browser tests with Selenium (ActionCable, progress bar, JS behavior)
- `spec/e2e/` — end-to-end tests (full download lifecycle, CBZ verification, settings validation)

### Test Policies
- **VCR cassettes** for real API interactions (adapter integration tests, search E2E)
- **WebMock stubs** for fake URLs (CDN), controlled failures (retries), and inline image data
- System and E2E specs use headless Chrome via Selenium with inline Sidekiq
- E2E search test uses real adapter + VCR (instance_double stubs don't work across Puma threads)
- VCR allows localhost connections (`ignore_localhost = true`) for browser tests
- All specs that create downloads set `destination_root` to `Dir.mktmpdir` — never write to real folders

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
