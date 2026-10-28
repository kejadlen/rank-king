# Agents

## Project overview

Rank King is a webapp for ranking items along multiple axes through pairwise comparisons, powered by OpenSkill (Plackett-Luce). Users create lists of items, define axes to rank along, then do head-to-head matchups. Ratings are derived from results.

## Tech stack

- Ruby 4, Roda (routing), Sequel (ORM), SQLite
- Phlex for views (pure Ruby HTML)
- Gloss (https://github.com/kejadlen/gloss) for the design system, vendored
- Puma web server, Rack
- Minitest for tests
- Steep for type checking, against inline RBS comments

## Repository layout

```
config.ru          — Rack entrypoint (expects the proxy's Remote-User header)
demo.ru            — config.ru plus StubLogin and sample lists, for dev and the Fly apps
Gemfile            — dependencies
Rakefile           — rake tasks (test, dev)
db/migrate/        — Sequel migrations
lib/rank_king/     — app code
  config.rb        — Config data class, reads from ENV
  db.rb            — Sequel connection + migration runner
  models.rb        — Sequel models (User, GoogleAccount, List, Item, Axis, Result)
  google.rb        — Google client: OAuth and the YouTube Data API
  sources.rb       — Sources.fetch: a list's source_kind names a class in Sources
  sources/         — one class per source kind
  sync.rb          — reconciles a list's items with a fresh snapshot from a fetching source
  proxy_auth.rb    — reads the login from Remote-User
  seed.rb          — sample lists for the stub login (demo.ru)
  stub_login.rb    — writes a fixed login where there is no proxy (demo.ru)
  web.rb           — Roda routes
  views/           — Phlex view components
lib/open_skill/    — OpenSkill rating library (pure Ruby)
test/              — Minitest tests
sig/               — RBS for what inline comments cannot express
Steepfile          — type checking config
public/            — static assets
  vendor/gloss/    — vendored Gloss CSS and JS (refresh with rake gloss:vendor)
  css/app.css      — Rank King's layout over Gloss
  js/app.js        — axis tags, confirmations, busy buttons, new-list source fields
.github/workflows/ — CI, PR previews, preview reaper (GitHub Actions)
Dockerfile         — production image
fly.toml           — Fly config for the main demo and PR previews
.ramekin/          — agent dev container
```

## Domain model

- **User** has many Lists; identified by the login on the `Remote-User` header. Their settings page (`/settings`) connects a Google account (**GoogleAccount**, which keeps only the refresh token)
- **List** belongs to a User and has many Items and Axes, and one source (`source_kind` names a class in `Sources`). Each source renders its own sync dialog on the list page and applies what it posts: `Text`'s edits items by id, and a kind that fetches calls `Sync.call`. A fetching kind keeps its config in its own table keyed by `list_id` and its per-item details in a table keyed by `item_id`
- Sources: `Text` (typed in, edited by id) and `YouTube` (follows one of the owner's playlists through their Google account; `youtube_sources` by `list_id`, `youtube_items` by `item_id`)
- **Item** belongs to a List; removed items, and items missing from the latest sync, are archived (`archived_at`) and hidden everywhere
- **Axis** belongs to a List, has many Results
- **Result** belongs to an Axis, a winner (Item), and a loser (Item)

## Commands

| Task | Command |
|------|---------|
| Type check and test | `bundle exec rake` |
| Run tests | `bundle exec rake test` |
| Type check | `bundle exec rake steep` |
| Run dev server | `bundle exec rake dev` (uses `fd \| entr -r rackup demo.ru`) |
| Refresh Gloss | `bundle exec rake gloss:vendor GLOSS=/path/to/gloss` |
| Start server | `bundle exec rackup` (behind the proxy) or `bundle exec rackup demo.ru` (stub login) |

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
- `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` (required) — a Google OAuth
  web client with the YouTube Data API enabled, for connecting Google.
  Its redirect URI is `<app URL>/settings/google/callback`. A consent
  screen left in Testing mode expires refresh tokens after 7 days. The
  Fly demos set placeholders in `fly.toml`, since anyone can open them.

Tests set `DATABASE_URL=:memory:` and a dummy Google client in
`test/test_helper.rb`. The app hands its `google` client to every
source; the YouTube tests subclass the app to return a `Google`
subclass whose `request` answers without the network.

## Conventions

- `$LOAD_PATH` is set to `lib/` in both `config.ru` and `Rakefile`
- Sequel migrations live in `db/migrate/` with numeric prefixes
- Models use `Sequel::Model` with `timestamps` plugin
- Views are Phlex components under `lib/rank_king/views/`
- CSRF protection is on for all POST routes
- Markup follows Gloss' contracts (`_components/<name>.md` in the Gloss
  repo): bare elements, ARIA roles, and `data-*` variants, with no class
  beyond Gloss' own. `app.css` reads only `--gl-*` tokens and lays
  components out rather than restyling them.
- Every screen opens with one header row (back, title, then the
  screen's own actions). List actions go in the list's ⋯ menu and list
  options in its settings form, so a new feature adds an entry there
  rather than a new button or screen.
- A list's source is fixed when it is made. `Sources::KINDS` lists the
  kinds the new-list form offers, and each kind's `title` names it there
  and in settings. Its sync dialog opens from the list's ⋯ menu. Each
  kind also renders its own fields on the new-list form (`fields`) and
  sets the new list up from them (`create`).
- Every request needs a `Remote-User` header or it gets a 401. That is safe only because a proxy (Tailscale identity) writes the header. `StubLogin` fills it in for `demo.ru` (dev server, Fly apps) and nowhere else: never in `config.ru`, and never in front of real data.
- Lists are private to their owner (404 for anyone else)
- Config is a frozen `Data.define` value object
- Paths are `Pathname`s, not strings built with `File`/`Dir`
  (`Pathname(__dir__).join(...)`, `#exist?`, `#read`). Convert with
  `to_s` only at a boundary that wants a String, such as `$LOAD_PATH`,
  `Rack::Builder.parse_file`, or `Sequel::Migrator.run`.
- Types are inline RBS comments (`#:` before a method, `# @rbs` for the
  rest), checked by `rake steep`. `sig/` holds only what that syntax
  cannot say, each file saying why: gems with no signatures (Sequel,
  Roda), Data classes, the models (no constant superclass), and the
  Phlex views, which the Steepfile ignores.
- `rake steep` needs a UTF-8 locale: under a C locale the em dashes in
  comments are invalid bytes and the check hangs.
