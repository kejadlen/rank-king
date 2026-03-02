# Rank King

A webapp for ranking items along multiple axes through pairwise comparisons, powered by [OpenSkill](https://openskill.me/en/stable/) (Plackett-Luce).

## Domain

- **List** — a collection of items to rank (e.g., "Favorite Foods")
- **Item** — a thing being ranked (e.g., "Pizza", "Sushi", "Tacos")
- **Axis** — a dimension to rank along (e.g., "Taste", "Value", "Convenience")
- **Matchup** — a head-to-head comparison of two items on an axis
- **Result** — the record of who won a matchup
- **Rating** — the OpenSkill score for an item on an axis, derived from results

A **List** has **Items** and **Axes**. A **Matchup** presents two **Items** on an **Axis**. A **Result** records the winner. **Ratings** are derived from **Results**.

## Features

- Create a list by entering items into a text area
- Define one or more axes to rank along
- Pick matchups manually, get random ones, or use suggested matchups (the pair that reduces overall variance the most)
- View ratings per axis

## Design decisions

- In-memory storage to start
- No auth to start

## Future

- Persistence
- Users and auth
- API
