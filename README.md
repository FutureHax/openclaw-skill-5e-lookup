# 5e-lookup

OpenClaw skill for looking up D&D 5th Edition content via the [5etools](https://5e.r2plays.games) mirror.

## Features

- **Monsters** — Full stat blocks with artwork and 5etools links
- **Spells** — Complete spell details with casting info and class lists
- **Items** — Magic items and base equipment with rarity and attunement info
- **Conditions & Diseases** — Quick rules reference
- **Backgrounds** — Character background details
- **Adventures** — Browse, outline, read chapters, and search adventure text

## Usage

All lookups go through a single tool script:

```bash
bash tools/lookup.sh <command> [args...]
```

### Commands

| Command | Description |
|---|---|
| `monster <name> [source]` | Look up a monster by name |
| `monsters <source>` | List monsters from a source book |
| `spell <name> [source]` | Look up a spell by name |
| `spells <source>` | List spells from a source book |
| `item <name>` | Look up an item by name |
| `items [rarity]` | List items, optionally filtered by rarity |
| `condition <name>` | Look up a condition or disease |
| `conditions` | List all conditions and diseases |
| `background <name>` | Look up a background |
| `backgrounds` | List all backgrounds |
| `adventures` | List all adventure modules |
| `adventure-outline <id>` | Show table of contents for an adventure |
| `adventure-read <id> <section>` | Read a chapter/section from an adventure |
| `adventure-search <id> <keyword>` | Search adventure text for a keyword |
| `sources` | List common source abbreviations |

## Output

Returns structured JSON designed for Discord embed formatting, including:

- `title`, `url`, `description`, `fields`, `image`, `footer`, `color`

## Data Source

All data is fetched from the public 5etools mirror at `https://5e.r2plays.games/data/`. No API key required.

## Requirements

- `curl` — HTTP requests
- `jq` — JSON processing
- `sed` — Tag stripping
