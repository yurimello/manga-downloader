# Manga Downloader

A Rails application for downloading manga from various sources, packing chapters into CBZ volumes.

## Features

- Download manga from MangaDex (extensible adapter pattern for future sources)
- Multi-language support with priority: pt-br > es-la > es > en
- Volume selection (download specific volumes or all)
- Real-time progress via Action Cable (WebSocket)
- Background processing with Sidekiq + Redis
- CBZ volume packing
- Configurable concurrent downloads and destination directory

## Architecture

- **Adapter Pattern** - Source adapters (`app/adapters/`) for different manga sites
- **Command Pattern** - Download commands (`app/commands/`) for job orchestration
- **Service Objects** - Business logic in `app/services/`
- **Sidekiq + Redis** - Background job processing
- **Action Cable** - Real-time progress updates
- **Stimulus** - Frontend interactivity

## Setup

### Docker

```bash
docker compose up
```

App runs on **port 3333**.

### Local Development

```bash
bundle install
bin/rails db:setup
bin/dev
```

Requires Redis running locally.

## Configuration

- `config/languages.yml` - Language priorities
- `config/sources.yml` - Source adapters
- Settings page (`/settings`) - Max concurrent processes, destination root

## Tests

```bash
bundle exec rspec
```

## Tech Stack

- Ruby on Rails 8
- SQLite
- Sidekiq + Redis
- Tailwind CSS
- Hotwire (Turbo + Stimulus)
- RSpec + VCR + WebMock
