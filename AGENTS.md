# Agents

## Project overview

Rank King is a webapp for ranking items along multiple axes through pairwise comparisons, powered by OpenSkill (Plackett-Luce). Users create lists of items, define axes to rank along, then do head-to-head matchups. Ratings are derived from results.

## Tech stack

- Ruby 4, Roda (routing), Sequel (ORM), SQLite
- Phlex for views (pure Ruby HTML)
- Puma web server, Rack
- Minitest for tests

## Repository layout

```
config.ru          — Rack entrypoint
Gemfile            — dependencies
Rakefile           — rake tasks (test, dev)
db/migrate/        — Sequel migrations
lib/rank_king/     — app code
  config.rb        — Config data class, reads from ENV
  db.rb            — Sequel connection + migration runner
  models.rb        — Sequel models (List, Item, Source, Axis, Result)
  sources.rb       — hardcoded registry of source kinds (Sources::ALL)
  sources/         — one class per source kind
  sync.rb          — reconciles a source's items with a fresh snapshot
  web.rb           — Roda routes
  views/           — Phlex view components
lib/open_skill/    — OpenSkill rating library (pure Ruby)
test/              — Minitest tests
public/            — static assets
.github/workflows/ — CI (GitHub Actions)
```

## Domain model

- **User** has many Lists; identified by login (see `AUTH`)
- **List** belongs to a User and has many Items, Sources, and Axes
- **Source** belongs to a List and produces its Items; `kind` picks a class from `Sources::ALL`
- **Item** belongs to a List and a Source; items missing from the latest sync are archived (`archived_at`) and hidden everywhere
- **Axis** belongs to a List, has many Results
- **Result** belongs to an Axis, a winner (Item), and a loser (Item)

## Commands

| Task | Command |
|------|---------|
| Run tests | `bundle exec rake test` |
| Run dev server | `bundle exec rake dev` (uses `fd \| entr -r rackup`) |
| Start server | `bundle exec rackup` |

## Environment variables

- `DATABASE_URL` — SQLite path (default: `:memory:`)
- `SESSION_SECRET` — session signing key (auto-generated if unset)
- `AUTH` — `local` (default: everyone is `LOCAL_USER`) or `tailscale` (user from the `Tailscale-User-Login` header; only safe behind `tailscale serve`)
- `LOCAL_USER` — login of the single user in `local` auth (default: `local`)

Tests set `DATABASE_URL=:memory:` in `test/test_helper.rb`.

## Conventions

- `$LOAD_PATH` is set to `lib/` in both `config.ru` and `Rakefile`
- Sequel migrations live in `db/migrate/` with numeric prefixes
- Models use `Sequel::Model` with `timestamps` plugin
- Views are Phlex components under `lib/rank_king/views/`
- CSRF protection is on for all POST routes
- Config is a frozen `Data.define` value object
