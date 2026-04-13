# Services Architecture

Services encapsulate business logic and are orchestrated by the `DownloadOrchestratorService`.

## Service Dependency Graph

```
DownloadOrchestratorService
  ├── AdapterRegistry        → resolves adapter for URL
  ├── ChapterSelectorService → filters chapters by language/volume
  ├── ImageDownloaderService → downloads images from CDN
  │     └── Faraday (CDN)    → parallel HTTP downloads (no rate limiting)
  ├── CbzPackerService       → packs images into CBZ archives
  └── ActionCable            → broadcasts progress/status/logs
```

## DownloadOrchestratorService

The main workflow coordinator. Runs inside a Sidekiq job.

**Steps:**
1. Extract manga ID from URL via adapter
2. Fetch manga title from API
3. Fetch all chapters with language filtering
4. Select chapters via `ChapterSelectorService`
5. Skip already-downloaded volumes (via `DownloadVolume` records)
6. Count total images for progress calculation
7. Download images chapter by chapter (parallel within each chapter)
8. Pack into CBZ files per volume
9. Record downloaded volumes in database
10. Update status to completed

**Broadcasts at each step**: status changes, per-image progress, log entries.

**Error handling**: catches all exceptions, sets status to `failed`, logs the error and backtrace.

**Cancellation**: checks `download.cancelled?` between chapters.

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
