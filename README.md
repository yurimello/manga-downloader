# Manga Downloader

A Rails application for downloading manga from various sources, packing chapters into CBZ volumes.

## Features

### Search
- Search manga by title with debounced input (300ms)
- Dropdown with cover thumbnails and alternative English titles
- Paginated by 5, infinite scroll loads next page on scroll
- Sort by: relevance (default), rating, popularity, title, newest, recently updated
- Results filtered by configured languages
- Source selector in collapsible Advanced panel (MangaDex by default)
- Click result to fill title and URL inputs

### Download
- Download manga by pasting a MangaDex URL or selecting from search
- Volume selection — download specific volumes (e.g., "1, 2, 3") or all
- Volume tracking — skips already-downloaded volumes on reprocess
- Parallel CDN image downloads (4 concurrent threads)
- CBZ volume packing with sequential page numbering
- Reprocess completed/failed downloads (skips what's already done)
- Cancel active downloads
- Destination validation — blocks download if path not configured or not writable

### Real-time Updates
- Progress bar updates per-image via ActionCable (no DB writes)
- Status transitions shown live: queued → downloading → packing → completed
- Log panel with color-coded entries (info/warn/error) appended in real time
- Page auto-reloads when download completes or fails
- Settings validation errors broadcast in real time

### Configuration
- Max concurrent downloads (1-10)
- Destination root directory (validated as writable)
- Language priorities (`config/languages.yml`)
- Manga sources (`config/sources.yml`)

### Multi-language
- Chapter selection by language priority: pt-br > es-la > es > en > fr > it
- Best available language per chapter number
- Search results filtered to configured languages

### Infrastructure
- Background job processing with Sidekiq + Redis
- Queue throttling — re-enqueues when at max capacity
- Docker support: development (live reload) and production (multi-stage build)
- Dark theme UI with Tailwind CSS
- Form submit debouncer prevents duplicate clicks

## Architecture

- **Adapter Pattern** — Source adapters (`app/adapters/`) for different manga sites
- **Interactor Pattern** — Commands (`app/commands/`) and orchestrator steps use the `interactor` gem
- **Observer Pattern** — `Observable` module on models, observers handle ActionCable broadcasting
- **Service Objects** — Business logic in `app/services/`
- **Sidekiq + Redis** — Background job processing
- **ActionCable** — Real-time progress, status, log, and validation error updates
- **Stimulus** — Frontend interactivity (search dropdown, progress bars, form debouncing)

See [docs/](docs/) for detailed documentation:
- [Architecture](docs/architecture.md) — code structure, models, request flow, patterns
- [Services](docs/services.md) — service layer design and dependencies
- [Code Policies](docs/code-policies.md) — conventions, style, and contribution guidelines
- [Testing](docs/testing.md) — test suite structure and patterns

## Setup

### Docker — Development (recommended)

```bash
docker compose -f docker-compose.dev.yml up --build -d
docker compose -f docker-compose.dev.yml exec web bin/rails db:setup
```

Source code is mounted as a volume — Ruby and JS changes reflect immediately on browser refresh (no rebuild). Only rebuild when Gemfile changes.

Open http://localhost:3333

**Note:** If JS changes don't reflect, hard refresh with `Cmd+Shift+R` (Mac) or `Ctrl+Shift+R`.

### Docker — Production

1. Create a `.env` file:

```bash
SECRET_KEY_BASE=$(ruby -rsecurerandom -e "puts SecureRandom.hex(64)")
echo "SECRET_KEY_BASE=$SECRET_KEY_BASE" > .env
```

2. Start the application:

```bash
docker compose up --build -d
docker compose exec web bin/rails db:migrate
docker compose exec web bin/rails db:seed
```

3. Open http://localhost:3333

### Local Development

```bash
bundle install
redis-server          # in another terminal
bin/rails db:setup
bin/dev               # starts Rails + Sidekiq
```

## Configuration

### Settings (UI)

Visit `/settings` in the browser to configure:

| Setting | Default | Description |
|---------|---------|-------------|
| Max concurrent processes | 1 | Number of simultaneous downloads |
| Destination root | /downloads | Output directory inside container (maps to host) |

**Destination root** must be a writable directory. In Docker, `/downloads` maps to `~/Comics/Manga` on the host.

### Config Files

| File | Purpose |
|------|---------|
| `config/languages.yml` | Language priority order for chapter selection and search filtering |
| `config/sources.yml` | Manga source adapters and their API settings |
| `config/cable.yml` | ActionCable (WebSocket) adapter config |
| `config/sidekiq.yml` | Sidekiq concurrency and queue settings |

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SECRET_KEY_BASE` | (required for production) | Rails secret key |
| `REDIS_URL` | `redis://localhost:6379/0` | Redis connection URL |
| `RAILS_ENV` | `development` | Rails environment |
| `DOWNLOAD_DIR` | `~/Comics/Manga` | Host path for downloaded files |

### Docker Volumes

| Container Path | Host Path | Purpose |
|---------------|-----------|---------|
| `/rails/storage` | Docker volume `storage_data` | SQLite databases |
| `/downloads` | `$DOWNLOAD_DIR` (`~/Comics/Manga`) | CBZ output files |
| `.` (dev only) | `/rails` | Source code (live reload) |
| `bundle_cache` (dev only) | `/usr/local/bundle` | Gems persist across restarts |

### Adding a New Language

Edit `config/languages.yml`:

```yaml
- code: de
  priority: 7
```

### Adding a New Manga Source

1. Create `app/adapters/new_source_adapter.rb` extending `BaseAdapter`
2. Implement all abstract methods (`url_pattern`, `search_manga`, `extract_manga_id`, `fetch_manga_title`, `fetch_chapters`, `fetch_chapter_images`, `image_url`)
3. Add config to `config/sources.yml`:

```yaml
shared:
  sources:
    new_source:
      adapter_class: NewSourceAdapter
      base_url: https://api.newsource.com
```

The new source will automatically appear in the search "Advanced" panel source selector.

## Tests

```bash
# Full suite
bundle exec rspec

# By category
bundle exec rspec spec/commands/
bundle exec rspec spec/services/
bundle exec rspec spec/system/
bundle exec rspec spec/e2e/

# With verbose output
bundle exec rspec --format documentation
```

See [docs/testing.md](docs/testing.md) for test structure, patterns, and factories.

## Tech Stack

- Ruby on Rails 8.1
- SQLite3
- Sidekiq + Redis
- Tailwind CSS
- Hotwire (Turbo + Stimulus)
- ActionCable (WebSockets)
- Interactor gem
- RSpec + VCR + Capybara + Selenium
