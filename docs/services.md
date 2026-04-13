# Services Architecture

Services encapsulate business logic and are orchestrated by the `DownloadOrchestratorService`.

## Interactor Pipeline

The download workflow uses `Interactor::Organizer` — a sequence of small, focused steps executed in order. Each step includes `Interactor` via `BaseStep` and shares state through `Interactor::Context`.

```
DownloadOrchestratorService (Interactor::Organizer)
  ├── FetchMangaInfoStep   → extract ID, fetch title
  ├── SelectChaptersStep   → fetch chapters, filter by language/volume, skip downloaded
  ├── DownloadImagesStep   → count images, download with progress
  ├── PackVolumesStep      → pack CBZ archives
  └── RecordVolumesStep    → record volumes in DB, mark completed
```

### DownloadOrchestratorService

Uses `Interactor::Organizer` with `InteractorStepDefinitions` DSL to declare steps and their dependencies. Each step declares its dependencies as lambdas — resolved lazily before the step runs. Dependencies can be overridden by the caller.

```ruby
# Minimal — all dependencies use defaults
DownloadOrchestratorService.call(download: download)

# Override specific dependencies
DownloadOrchestratorService.call(
  download: download,
  adapter: custom_adapter,
  language_config: CustomLanguageConfig,
  observers: [CustomObserver.new]
)
```

**Step DSL** (`InteractorStepDefinitions` from `lib/`):
- `step StepClass, dependencies: { key: -> { default } }` — per-step dependency with lazy default
- `dependency key: -> { default }` — orchestrator-level dependency (e.g., observers)

Error handling in `around` hook. Tmpdir cleanup via `TmpdirCleanupService`.

### Steps

Each step inherits from `BaseStep` (which includes `Interactor`) and accesses shared state via `context`.

**Scope rules for shared behavior:**
- **BaseStep** — methods used by all steps: `download`, `log!`
- **Modules** (`app/services/concerns/`) — methods used by some steps: `FileSystemAccess` (provides `fs`)
- **Private methods** — methods used by one step only: `cancelled?`, `notify_progress` in `DownloadImagesStep`

| Step | Responsibility |
|------|---------------|
| `FetchMangaInfoStep` | Extract manga ID from URL, fetch title from API |
| `SelectChaptersStep` | Fetch chapters, filter by language/volume, skip already-downloaded volumes |
| `DownloadImagesStep` | Count images, download with parallel threads, track progress |
| `PackVolumesStep` | Pack images into CBZ archives per volume |
| `RecordVolumesStep` | Record downloaded volumes in DB, mark download as completed |

**Error handling**: The orchestrator's `around` block catches exceptions, persists the failure to the DB, notifies the observer (which broadcasts), then calls `context.fail!`.

**Cancellation**: Individual steps check `cancelled?` within loops.

**Tmpdir cleanup**: `TmpdirCleanupService` runs in the `ensure` block — uses `SystemUtils` directly.

## Services vs Steps

Services (`app/services/*.rb`) are reusable utilities with no orchestration logic. Steps (`app/services/download_orchestrator_steps/`) are glue that manage status, logging, and context — they call services but add orchestration concerns.

| Service | Step | Relationship |
|---------|------|-------------|
| `ImageDownloaderService` | `DownloadImagesStep` | Step tracks progress, manages tmpdir, calls service |
| `CbzPackerService` | `PackVolumesStep` | Step resolves destination, sets status, calls service |
| `ChapterSelectorService` | `SelectChaptersStep` | Step filters downloaded volumes, calls service |

## HttpClientService

Handles API requests to manga sources (rate-limited).

- Retries up to 5 times on HTTP 429 or API error responses
- Configurable delay between retries (default 2 seconds)
- Methods: `get_json(url, params:)`
- Custom exceptions: `RateLimitError`, `ApiError`

**Important**: This service is only used for API calls. CDN image downloads use a separate Faraday connection in `ImageDownloaderService` with no rate limiting.

## ImageDownloaderService

Downloads chapter images from CDN with parallel threads.

- **Concurrency**: 4 threads (configurable)
- **Deduplication**: tracks downloaded URLs in a `Set` to skip duplicates across chapters
- **Progress callback**: accepts a block called after each successful download
- **Thread safety**: `Mutex` protects shared state (count, URL set)
- **Completion**: `threads.each(&:join)` blocks until all images finish

```ruby
downloader.download_chapter(chapter_id, dest_dir) do
  # called after each image downloads (thread-safe)
  update_progress
end
```

## ChapterSelectorService

Picks the best chapter for each chapter number based on language priority.

- Defaults to `LanguageConfig.priorities` (from `lib/language_config.rb`)
- For each chapter number, selects the highest-priority language available
- Optionally filters by volume list
- Returns `language_summary` for logging

## Utility Services (`service_utils/`)

Utility services are infrastructure helpers — they can be instantiated directly without dependency injection.

### ServiceUtils::TmpdirCleanup

Cleans up temporary directories after download orchestration.

- Uses `SystemUtils` module methods for filesystem operations
- Single `call(path)` method — removes directory if it exists

## CbzPackerService

Creates CBZ (Comic Book ZIP) archives from downloaded images.

- `pack_volumes(tmpdir, dest, title, volumes)` — one CBZ per volume
- `pack_single_volume(tmpdir, dest, title)` — all chapters in one CBZ
- Pages are numbered sequentially across chapters within a volume
- Output: `Title - Vol. 01.cbz`, `Title - Vol. 02.cbz`, etc.
