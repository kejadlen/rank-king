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
  models.rb        — Sequel models (List, Item, Axis, Result)
  web.rb           — Roda routes
  views/           — Phlex view components
lib/open_skill/    — OpenSkill rating library (pure Ruby)
test/              — Minitest tests
public/            — static assets
.github/workflows/ — CI, PR previews, preview reaper (GitHub Actions)
Dockerfile         — production image
fly.toml           — Fly config for the main demo and PR previews
.ramekin/          — agent dev container
```

## Domain model

- **List** has many Items and Axes
- **Item** belongs to a List
- **Axis** belongs to a List, has many Results
- **Result** belongs to an Axis, a winner (Item), and a loser (Item)

## Commands

| Task | Command |
|------|---------|
| Run tests | `bundle exec rake test` |
| Run dev server | `bundle exec rake dev` (uses `fd \| entr -r rackup`) |
| Start server | `bundle exec rackup` |

## CI and deployment

- `ci.yml` runs `rake` and audits workflows with zizmor on every push and PR.
  On main it then builds the image, pushes it to GHCR, cuts a GitHub release
  named after the image tag, and deploys that image to Fly (`rank-king`).
- `preview.yml` deploys each PR to its own Fly app and destroys it on close;
  `reap-previews.yml` cleans up any that were missed.
- Needs a `FLY_API_TOKEN` secret, available to the `demo`, `pr-*`, and
  `preview-reaper` environments.
- Workflow actions are pinned by commit with a tag comment naming that
  commit, never a branch. Renovate keeps them, gems, and the Docker base
  image current.

## Environment variables

- `DATABASE_URL` — SQLite path (default: `:memory:`)
- `SESSION_SECRET` — session signing key (auto-generated if unset)

Tests set `DATABASE_URL=:memory:` in `test/test_helper.rb`.

## Conventions

- `$LOAD_PATH` is set to `lib/` in both `config.ru` and `Rakefile`
- Sequel migrations live in `db/migrate/` with numeric prefixes
- Models use `Sequel::Model` with `timestamps` plugin
- Views are Phlex components under `lib/rank_king/views/`
- CSRF protection is on for all POST routes
- Config is a frozen `Data.define` value object
