# Manga Downloader

A Rails application for downloading manga from various sources, packing chapters into CBZ volumes.

## Features

- Download manga from MangaDex (extensible adapter pattern for future sources)
- Multi-language support with priority: pt-br > es-la > es > en > fr > it
- Volume selection (download specific volumes or all)
- Volume tracking — skips already-downloaded volumes on reprocess
- Parallel CDN image downloads (4 concurrent threads)
- Real-time progress via ActionCable (WebSocket) — per-image tracking
- Background processing with Sidekiq + Redis
- CBZ volume packing
- Configurable concurrent downloads and destination directory
- Reprocess action for retrying downloads

## Architecture

- **Adapter Pattern** — Source adapters (`app/adapters/`) for different manga sites
- **Command Pattern** — User actions (`app/commands/`) with `CommandChain` for composing multi-step operations
- **Service Objects** — Business logic in `app/services/`
- **Sidekiq + Redis** — Background job processing
- **ActionCable** — Real-time progress, status, and log updates
- **Stimulus** — Frontend interactivity (progress bars, form debouncing)

See [docs/](docs/) for detailed documentation:
- [Architecture](docs/architecture.md) — code structure, models, request flow, patterns
- [Services](docs/services.md) — service layer design and dependencies
- [Code Policies](docs/code-policies.md) — conventions, style, and contribution guidelines
- [Testing](docs/testing.md) — test suite structure and patterns

## Setup

### Docker (recommended)

1. Create a `.env` file:

```bash
SECRET_KEY_BASE=$(ruby -rsecurerandom -e "puts SecureRandom.hex(64)")
echo "SECRET_KEY_BASE=$SECRET_KEY_BASE" > .env
```

2. Start the application:

```bash
docker compose up --build -d
```

3. Run database migrations:

```bash
docker compose exec web bin/rails db:migrate
docker compose exec web bin/rails db:seed
```

4. Open http://localhost:3333

Downloaded manga will be saved to `~/Comics/Manga` on your host by default.

### Local Development

1. Install dependencies:

```bash
bundle install
```

2. Start Redis:

```bash
redis-server
```

3. Setup the database:

```bash
bin/rails db:setup
```

4. Start the application:

```bash
bin/dev
```

This starts both the Rails server and Sidekiq worker.

## Configuration

### Settings (UI)

Visit `/settings` in the browser to configure:

| Setting | Default | Description |
|---------|---------|-------------|
| Max concurrent processes | 1 | Number of simultaneous downloads |
| Destination root | /downloads | Output directory inside container |

### Config Files

| File | Purpose |
|------|---------|
| `config/languages.yml` | Language priority order for chapter selection |
| `config/sources.yml` | Manga source adapters and their API settings |
| `config/cable.yml` | ActionCable (WebSocket) adapter config |
| `config/sidekiq.yml` | Sidekiq concurrency and queue settings |

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SECRET_KEY_BASE` | (required) | Rails secret key for production |
| `REDIS_URL` | `redis://localhost:6379/0` | Redis connection URL |
| `RAILS_ENV` | `development` | Rails environment |
| `DOWNLOAD_DIR` | `~/Comics/Manga` | Host path for downloaded files |
| `RAILS_MASTER_KEY` | (optional) | Rails credentials master key |

### Docker Volumes

| Container Path | Host Path | Purpose |
|---------------|-----------|---------|
| `/rails/storage` | Docker volume `storage_data` | SQLite databases |
| `/downloads` | `$DOWNLOAD_DIR` (~`/Comics/Manga`) | CBZ output files |

### Adding a New Language

Edit `config/languages.yml` and add a new entry with the next priority number:

```yaml
- code: de
  priority: 7
```

### Adding a New Manga Source

1. Create `app/adapters/new_source_adapter.rb` extending `BaseAdapter`
2. Implement all abstract methods (`url_pattern`, `extract_manga_id`, `fetch_manga_title`, `fetch_chapters`, `fetch_chapter_images`, `image_url`)
3. Add config to `config/sources.yml`:

```yaml
shared:
  sources:
    new_source:
      adapter_class: NewSourceAdapter
      base_url: https://api.newsource.com
```

## Tests

```bash
# Full suite
bundle exec rspec

# By category
bundle exec rspec spec/commands/
bundle exec rspec spec/services/
bundle exec rspec spec/system/

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
- RSpec + VCR + WebMock + Capybara + Selenium
