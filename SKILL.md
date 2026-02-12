---
name: 5e-lookup
description: Look up D&D 5th Edition content from the owner's personal reference database and display results as rich Discord embeds.
---

# 5etools D&D 5E Reference

This skill queries the owner's **personal database** at `5e.r2plays.games` and returns structured data. The data returned by the tool is what you display — treat it the same as any other tool output (like a weather API or calendar lookup). You run the tool, receive JSON, and present it as a Discord embed.

**This skill is for the Zordon agent on Discord only.**

## RULE: Always use the tool, always show the output

When a D&D 5E question comes up (monster, spell, item, condition, background, adventure), your response is:

1. Run `lookup.sh` with the appropriate command
2. Take the JSON the tool returns
3. Send it as a Discord embed via the discord-embed skill

That's it. The tool output IS the answer. Do not add disclaimers, do not rephrase the data, do not substitute your own content for what the tool returned. If someone asks "what's a Green Dragon Wyrmling?" you run `lookup.sh monster "Green Dragon Wyrmling"` and embed the result.

## How to use

Run the lookup tool at `{baseDir}/tools/lookup.sh` via the exec tool. Pass a subcommand as the first argument and additional arguments as needed.

### Monster lookup

```bash
# Look up a monster by name (searches common sources automatically)
bash {baseDir}/tools/lookup.sh monster "Goblin"

# Look up a monster from a specific source
bash {baseDir}/tools/lookup.sh monster "Mind Flayer" MM

# List all monsters from a source (returns names + CR only)
bash {baseDir}/tools/lookup.sh monsters MM
```

### Spell lookup

```bash
# Look up a spell by name
bash {baseDir}/tools/lookup.sh spell "Fireball"

# Look up a spell from a specific source
bash {baseDir}/tools/lookup.sh spell "Silvery Barbs" SCC

# List all spells from a source
bash {baseDir}/tools/lookup.sh spells PHB
```

### Item lookup

```bash
# Look up an item by name
bash {baseDir}/tools/lookup.sh item "Bag of Holding"

# List items filtered by rarity
bash {baseDir}/tools/lookup.sh items rare
```

### Condition / Disease lookup

```bash
# Look up a condition
bash {baseDir}/tools/lookup.sh condition "Frightened"

# List all conditions
bash {baseDir}/tools/lookup.sh conditions
```

### Background lookup

```bash
# Look up a background
bash {baseDir}/tools/lookup.sh background "Acolyte"

# List all backgrounds
bash {baseDir}/tools/lookup.sh backgrounds
```

### Adventure commands

```bash
# List all available adventures
bash {baseDir}/tools/lookup.sh adventures

# Show table of contents for an adventure (use the ID from the list)
bash {baseDir}/tools/lookup.sh adventure-outline LMoP

# Read a specific chapter/section from an adventure
bash {baseDir}/tools/lookup.sh adventure-read LMoP "Goblin Arrows"

# Search adventure text for a keyword
bash {baseDir}/tools/lookup.sh adventure-search LMoP "Cragmaw"
```

### Source reference

```bash
# List common source abbreviations
bash {baseDir}/tools/lookup.sh sources
```

## Output format

The tool returns structured JSON with these fields:

- `title` — Name of the entry
- `url` — Link to the 5etools page for this entry
- `description` — Main text content
- `fields` — Array of `{ "name", "value", "inline" }` objects for stats
- `image` — URL to artwork (when available, or `null`)
- `footer` — Source book and page number (plain string)
- `color` — Embed color as a decimal integer

## Presenting results: use the discord-embed skill (REQUIRED)

**You MUST send every 5e-lookup result through the discord-embed skill's `send-embed.sh` tool.** Never dump the JSON as plain text. Never describe the data in a regular message. Always send an embed card.

### Workflow

1. Run the 5e-lookup tool to get the JSON result
2. Build a discord-embed compatible JSON object from the result
3. Send it via `bash {discord-embed:baseDir}/tools/send-embed.sh <channel_id> '<embed_json>'`

### Mapping lookup output → discord-embed JSON

The lookup tool output needs minor reshaping for the discord-embed format:

| Lookup field | Discord embed field | Transform |
|---|---|---|
| `title` | `title` | Use directly |
| `url` | `url` | Use directly |
| `description` | `description` | Use directly |
| `fields` | `fields` | Use directly (array of name/value/inline) |
| `image` | `image` | Wrap: `{"url": "<image_value>"}` — omit if `null` |
| `footer` | `footer` | Wrap: `{"text": "Zordon • <footer_value>"}` |
| `color` | `color` | Use directly |
| *(add)* | `timestamp` | Add current ISO timestamp |

### Example: Monster lookup → embed

After running `lookup.sh monster "Goblin"`, build and send:

```bash
bash {discord-embed:baseDir}/tools/send-embed.sh CHANNEL_ID '{
  "title": "Goblin",
  "url": "https://5e.r2plays.games/bestiary.html#goblin_mm",
  "description": "Small humanoid, Neutral Evil\n\n**Traits**\n...",
  "color": 15158332,
  "image": {"url": "https://5e.r2plays.games/img/MM/Goblin.webp"},
  "fields": [
    {"name": "AC", "value": "15 (leather armor, shield)", "inline": true},
    {"name": "HP", "value": "7 (2d6)", "inline": true},
    {"name": "Speed", "value": "30 ft.", "inline": true},
    {"name": "CR", "value": "1/4", "inline": true},
    {"name": "STR", "value": "8", "inline": true},
    {"name": "DEX", "value": "14", "inline": true}
  ],
  "footer": {"text": "Zordon • Source: MM p.166"},
  "timestamp": "2026-02-12T20:00:00.000Z"
}'
```

### Color scheme

| Content Type | Color | Decimal |
|---|---|---|
| Monster | Red | 15158332 |
| Spell | Blue | 3447003 |
| Item | Gold | 15844367 |
| Condition | Green | 3066993 |
| Background | Teal | 1752220 |
| Adventure | Purple | 10181046 |
| List/Index | Gray | 9807270 |

### Response guidelines

- For single-entry lookups (monster, spell, item, condition, background): send a full embed with all available fields, artwork, and the 5etools link
- For list commands (monsters, spells, items, adventures, conditions, backgrounds): send a compact embed with entries in the description; cap at 20 entries and mention the total count
- For adventure reads: use the embed description for the chapter text; split into multiple embeds if content exceeds 4000 characters
- Always include the 5etools link as the embed `url` so users can click the title to view the full page
- When `image` is not null, include it as `image: {url: "..."}` in the embed — this shows monster art, adventure covers, etc.
- Keep your text response to one sentence or less — the embed IS the response
- If the lookup returns an error or no results, tell the user clearly and suggest checking the name spelling or trying a different source

## When to use this skill

- Someone asks about a **monster or creature** — use `monster <name>`
- Someone asks about a **spell** — use `spell <name>`
- Someone asks about a **magic item or weapon** — use `item <name>`
- Someone asks about a **condition** (blinded, frightened, etc.) — use `condition <name>`
- Someone asks about a **background** — use `background <name>`
- Someone asks about an **adventure module** — use `adventures` to list, then `adventure-outline` and `adventure-read`
- Someone asks **"what source is X from?"** — the footer in every lookup response shows the source
- Someone wants to **browse** what's available — use the list commands

## Reminder

The tool returns data from the owner's personal database. You display it. That's the entire workflow. If you catch yourself typing a stat block, spell description, or item entry from memory instead of running the tool — stop, run the tool, and embed the result.
