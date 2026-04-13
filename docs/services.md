# Services Architecture

Services encapsulate business logic and are orchestrated by the `DownloadOrchestratorService`.

## Service Pipeline

The download workflow uses a **pipeline pattern** — a sequence of small, focused steps executed in order. Each step receives a shared context hash and does one thing.

```
ServicePipeline
  ├── DownloadOrchestratorSteps::FetchMangaInfoStep   → extract ID, fetch title
  ├── DownloadOrchestratorSteps::SelectChaptersStep   → fetch chapters, filter by language/volume, skip downloaded
  ├── DownloadOrchestratorSteps::DownloadImagesStep   → count images, download with progress
  ├── DownloadOrchestratorSteps::PackVolumesStep      → pack CBZ archives
  └── DownloadOrchestratorSteps::RecordVolumesStep    → record volumes in DB, mark completed
```

### ServicePipeline

Base class using the `interactor` gem's `Interactor::Organizer`. Provides `steps` class method for declaring the step sequence. Each step includes `Interactor` via `BaseStep` and receives a shared `Interactor::Context`.

### DownloadOrchestratorService

Thin wrapper that defines the step order, builds the context, and handles failure. All dependencies are injected via constructor — the orchestrator never instantiates other services.

```ruby
DownloadOrchestratorService.new(
  download,
  adapter:    adapter,     # manga source adapter (e.g. MangadexAdapter)
  selector:   selector,    # ChapterSelectorService
  downloader: downloader,  # ImageDownloaderService
  packer:     packer       # CbzPackerService
)
```

The **job** (`DownloadMangaJob`) is the composition root that wires up all dependencies.

### Steps

Each step extends `BaseStep` (which includes `Interactor`) and accesses shared state via `context`. `BaseStep` provides `download`, `log!`, `notify_status_changed`, and `notify_progress_updated`.

| Step | Responsibility |
|------|---------------|
| `FetchMangaInfoStep` | Extract manga ID from URL, fetch title from API |
| `SelectChaptersStep` | Fetch chapters, filter by language/volume, skip already-downloaded volumes |
| `DownloadImagesStep` | Count images, download with parallel threads, track progress |
| `PackVolumesStep` | Pack images into CBZ archives per volume |
| `RecordVolumesStep` | Record downloaded volumes in DB, mark download as completed |

**Error handling**: The orchestrator's `around` block catches exceptions, notifies the observer (which sets status to `failed` and broadcasts), then calls `context.fail!`.

**Cancellation**: Individual steps check `cancelled?` within loops.

## HttpClientService

Handles API requests to manga sources (rate-limited).

- Retries up to 5 times on HTTP 429 or API error responses
- Configurable delay between retries (default 2 seconds)
- Methods: `get_json(url, params:)`, `download_file(url, dest_path)`
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

- Loads priorities from `config/languages.yml`
- For each chapter number, selects the highest-priority language available
- Optionally filters by volume list
- Returns `language_summary` for logging

## CbzPackerService

Creates CBZ (Comic Book ZIP) archives from downloaded images.

- `pack_volumes(tmpdir, dest, title, volumes)` — one CBZ per volume
- `pack_single_volume(tmpdir, dest, title)` — all chapters in one CBZ
- Pages are numbered sequentially across chapters within a volume
- Output: `Title - Vol. 01.cbz`, `Title - Vol. 02.cbz`, etc.
