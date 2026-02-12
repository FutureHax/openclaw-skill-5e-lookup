---
name: 5e-lookup
description: Look up D&D 5th Edition content from 5etools — monsters, spells, items, adventures, conditions, and backgrounds — and present results as rich Discord embeds.
---

# 5etools D&D 5E Reference

You have access to the full D&D 5th Edition reference library via the 5etools mirror. Use this skill to look up monsters, spells, items, adventures, conditions, backgrounds, and more.

**This skill is for the Zordon agent on Discord only.**

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

The tool returns structured JSON with fields ready for Discord embed formatting. Every response includes:

- `title` — Name of the entry
- `url` — Link to the 5etools page for this entry
- `description` — Main text content
- `fields` — Array of `{ "name", "value", "inline" }` objects for stats
- `image` — URL to artwork (when available)
- `footer` — Source book and page number
- `color` — Suggested embed color as a decimal integer

## Formatting for Discord

When presenting results to users, you MUST format the tool output as a rich Discord embed. Use the JSON fields directly:

- Set the embed **title** to the `title` field — make it a clickable link using the `url` field
- Set the embed **description** from the `description` field
- Add each item in `fields` as an embed field (use `inline: true` for stat blocks)
- Set the embed **image** or **thumbnail** from the `image` field when present
- Set the embed **footer** from the `footer` field
- Set the embed **color** from the `color` field

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

- For single-entry lookups (monster, spell, item, condition, background): always use a full embed with all available fields, artwork, and the link
- For list commands (monsters, spells, items, adventures, conditions, backgrounds): present as a compact embed with entries as a numbered list in the description; cap at 20 entries and mention the total count
- For adventure reads: use the embed description for the chapter text; split into multiple messages if content exceeds 4000 characters
- Always include the 5etools link so the user can view the full page
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
