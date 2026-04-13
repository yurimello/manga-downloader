# Code Architecture

## Overview

The application follows a layered architecture with clear separation of concerns:

```
Request → Controller → Command → Job → Orchestrator (Interactor::Organizer)
                                                      ↓
                                            Step → Step → Step
                                            (shared Interactor::Context)
```

## Directory Structure

```
app/
├── adapters/          # Source-specific manga fetchers (adapter pattern)
├── channels/          # ActionCable WebSocket channels (DownloadChannel, SettingsChannel)
├── commands/          # User action handlers (interactor pattern)
├── controllers/       # HTTP request handlers
├── javascript/
│   ├── channels/      # ActionCable JS subscriptions
│   └── controllers/   # Stimulus controllers
├── jobs/              # Sidekiq background jobs
├── models/            # ActiveRecord models (include Observable)
├── observers/         # Observer implementations (ActionCable broadcasting)
├── services/          # Business logic
│   ├── download_orchestrator_steps/  # Pipeline steps for download orchestration
│   └── service_utils/                # Utility services (infrastructure, not domain)
└── views/             # ERB templates

lib/
├── interactor_step_definitions.rb   # DSL for declaring per-step dependencies
├── language_config.rb               # Language codes and priorities from config
├── observable.rb                    # Observer pattern (add_observer, notify)
└── system_utils.rb                  # Filesystem abstraction (module methods)
```

## Models

### Download
Main entity tracking a manga download request. Includes `Observable`.

- **Statuses**: `queued` → `downloading` → `packing` → `completed` / `failed` / `cancelled`
- **Relationships**: `has_many :download_volumes`, `has_many :download_logs`
- **Key fields**: `url`, `title`, `manga_id`, `volumes`, `status`
- **Observable events**: `on_status_changed` (after_update), `on_log_added` (via `log!`), `on_progress_updated` (via `notify`)

### DownloadVolume
Tracks which volumes have been downloaded for a given manga. Used to skip already-downloaded volumes on reprocess.

- **Relationships**: `belongs_to :download`
- **Uniqueness**: `[manga_id, volume]` — one record per volume per manga globally

### DownloadLog
Timestamped event log for each download. Levels: `info`, `warn`, `error`.

### Setting
Key-value store for persistent configuration. Includes `Observable`.

- Used for `max_concurrent_processes` and `destination_root`
- Validates `destination_root` is a writable directory
- **Observable events**: `on_error` (after_validation, when errors present)

## Search Flow

1. User types in the search input — Stimulus `manga_search_controller` debounces (300ms)
2. JS fetches `GET /search?q=query&offset=0&source=mangadex`
3. `SearchController` calls `adapter.search_manga(query)` via `AdapterRegistry.for_source`
4. Results rendered in dropdown with thumbnails — max 5 visible, infinite scroll loads next 5
5. User clicks a result — title fills search input, URL fills URL input
6. Advanced panel allows selecting a different source adapter

## Request Flow

1. User submits a URL via the form
2. `DownloadsController#create` calls `ProcessDownloadCommand` (validates destination, then creates download)
3. Command creates a `Download` record, enqueues `DownloadMangaJob`
4. Sidekiq picks up the job, calls `DownloadOrchestratorService`
5. Orchestrator registers observers on the download, runs steps
6. Steps update the download model — `Observable` fires observer notifications automatically
7. Observers broadcast via ActionCable — Stimulus controllers update the UI in real time

## Adapter Pattern

Adapters abstract manga sources behind a common interface:

```
BaseAdapter (abstract)
  ├── search_manga         # Search by title (paginated)
  ├── url_pattern          # Regex to match supported URLs
  ├── extract_manga_id     # Parse ID from URL
  ├── fetch_manga_title    # Get title from API
  ├── fetch_chapters       # List chapters with language codes
  ├── fetch_chapter_images # Get image URLs for a chapter
  └── image_url            # Construct CDN image URL

AdapterRegistry (singleton)
  ├── register(name, adapter)
  ├── for_url(url)         # Find adapter matching a URL
  └── for_source(name)     # Look up by registered name
```

New sources are added by:
1. Creating a new adapter class extending `BaseAdapter`
2. Adding config to `config/sources.yml`

The registry auto-loads adapters on Rails boot via `config/initializers/source_adapters.rb`.

## Observer Pattern (Real-time Updates)

Models include `Observable` (from `lib/observable.rb`) which provides `add_observer`, `observers`, and `notify`. Each model defines its own ActiveRecord callbacks that call `notify`.

No step, service, or command touches ActionCable directly.

```
Model state change                     Observer                        Client (JS)
──────────────────                     ────────                        ────────────
download.update!(status:) ──────→  after_update → on_status_changed → handleStatus()
download.update!(progress:) ────→  notify(:on_progress_updated)     → updateProgress()
download.log!() ────────────────→  notify(:on_log_added)            → appendLog()
setting validation fails ───────→  after_validation → on_error      → showErrors()
```

**Observers:**
- `DownloadBroadcastObserver` — broadcasts to `"download_#{id}"` channel
- `SettingsObserver` — broadcasts to `"settings"` channel

**Channels:**
- `DownloadChannel` — streams per-download updates
- `SettingsChannel` — streams settings validation errors

Cable config: Redis in development/production, async in test.
