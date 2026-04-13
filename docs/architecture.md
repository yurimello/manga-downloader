# Code Architecture

## Overview

The application follows a layered architecture with clear separation of concerns:

```
Request → Controller → Command → Job (composition root) → Orchestrator (Interactor::Organizer)
                                   ↓ injects                                    ↓
                            Adapter, Selector,                         Step → Step → Step
                            Downloader, Packer                         (shared Interactor::Context)
```

## Directory Structure

```
app/
├── adapters/          # Source-specific manga fetchers (adapter pattern)
├── channels/          # ActionCable WebSocket channels
├── commands/          # User action handlers (command pattern + chain)
├── observers/         # Observer pattern (ActionCable broadcasting)
├── controllers/       # HTTP request handlers
├── javascript/
│   ├── channels/      # ActionCable JS subscriptions
│   └── controllers/   # Stimulus controllers
├── jobs/              # Sidekiq background jobs (composition root)
├── models/            # ActiveRecord models
├── services/          # Business logic
│   ├── concerns/                     # Shared modules for services/steps
│   └── download_orchestrator_steps/  # Pipeline steps for download orchestration
└── views/             # ERB templates
```

## Models

### Download
Main entity tracking a manga download request.

- **Statuses**: `queued` → `downloading` → `packing` → `completed` / `failed` / `cancelled`
- **Relationships**: `has_many :download_volumes`, `has_many :download_logs`
- **Key fields**: `url`, `title`, `manga_id`, `volumes`, `progress`, `status`

### DownloadVolume
Tracks which volumes have been downloaded for a given manga. Used to skip already-downloaded volumes on reprocess.

- **Relationships**: `belongs_to :download`
- **Uniqueness**: `[manga_id, volume]` — one record per volume per manga globally

### DownloadLog
Timestamped event log for each download. Levels: `info`, `warn`, `error`.

### Setting
Key-value store for persistent configuration. Used for `max_concurrent_processes` and `destination_root`.

## Request Flow

1. User submits a URL via the form
2. `DownloadsController#create` calls `DownloadMangaCommand`
3. Command validates URL, creates a `Download` record, enqueues `DownloadMangaJob`
4. Sidekiq picks up the job and runs `DownloadOrchestratorService`
5. Orchestrator fetches chapters, downloads images, packs CBZ files
6. Progress is broadcast via ActionCable at each step
7. Stimulus controllers update the UI in real time

## Adapter Pattern

Adapters abstract manga sources behind a common interface:

```
BaseAdapter (abstract)
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

No step, service, or command touches ActionCable directly. Observers handle all broadcasting.

```
Orchestrator (after each step)          Observer                        Client (JS)
──────────────────────────────          ────────                        ────────────
on_status_changed  ──────────────→  DownloadBroadcastObserver  ──→  handleStatus()
on_log_added (via BaseStep#log!) ─→   .on_status_changed()         updateProgress()
on_progress_updated (in-loop) ────→   .on_progress_updated()       appendLog()
on_error (around hook) ──────────→    .on_log_added()
                                      .on_error()
```

**Where notifications happen:**
- `on_status_changed` — orchestrator's `call` method, after each step
- `on_log_added` — `BaseStep#log!`, on every log call
- `on_progress_updated` — `DownloadImagesStep`, per-image in download loop
- `on_error` — orchestrator's `around` hook, on failure

```
app/
├── observers/
│   ├── context_observer.rb              # Base class (interface)
│   └── download_broadcast_observer.rb   # ActionCable implementation
```

Cable config: Redis in development/production, async in test.
