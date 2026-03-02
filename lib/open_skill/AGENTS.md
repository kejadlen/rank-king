# OpenSkill library

Ruby port of [openskill.js](https://github.com/philihp/openskill.js) — a Bayesian skill rating system using the Plackett-Luce model.

## Purpose

This is a standalone, pure-Ruby rating library with no external dependencies. It is used by the Rank King app but has no coupling to it.

## Files

| File | Role |
|------|------|
| `rating.rb` | `Rating` value object (`Data.define(:mu, :sigma)`) |
| `game.rb` | `Game` — structures placements, ties, and teams; `TeamRating` aggregation |
| `model.rb` | `Model` — top-level API: `rating`, `rate(game)`, `ordinal(rating)` |
| `plackett_luce.rb` | `PlackettLuce` — the rating update algorithm |
| `statistics.rb` | `Statistics` — normal distribution helpers (`phi_minor`, `phi_major`, `v`, `w`, `vt`, `wt`) |
| `util.rb` | `Util` — shared math helpers (`util_c`, `util_sum_q`, `util_a`, `gamma`, `score`, `ladder_pairs`) |

## Key concepts

- **mu** (μ) — estimated skill mean (default 25)
- **sigma** (σ) — uncertainty / standard deviation (default μ/z ≈ 8.333)
- **beta** (β) — performance variability per match (default σ/2)
- **ordinal** — display rating: `target + alpha * (mu - z * sigma)`
- **tau** (τ) — optional additive dynamics factor that inflates sigma before rating, keeping ratings pliable over time
- **limit_sigma** — when true with tau, caps sigma so ordinal never drops after a win

## Usage

```ruby
model = OpenSkill::Model.new
a = model.rating  # Rating(mu: 25, sigma: 8.333...)
b = model.rating

# a beats b
new_a, new_b = model.rate(OpenSkill::Game.new([[a]], [[b]]))

# Ties: second and third place tied
model.rate(OpenSkill::Game.new([[first]], [[tied_a], [tied_b]], [[last]]))

# Teams
model.rate(OpenSkill::Game.new([[p1, p2]], [[p3, p4]]))

model.ordinal(new_a.first)  # => scalar rating for display
```

## Tests

Tests live at `test/test_open_skill.rb` (project root). They are ported from the upstream JS test suite and verify statistical helpers, model defaults, ordinal calculation, and Plackett-Luce rating updates including ties, teams, tau, and series.

Run with: `bundle exec rake test`

## Conventions

- Value objects use `Data.define` (frozen, immutable)
- No mutation — `rate` returns new Rating arrays
- Floating-point assertions use `assert_in_delta` with tolerances matching the JS reference implementation's precision
