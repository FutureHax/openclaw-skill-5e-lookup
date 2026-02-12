#!/usr/bin/env bash
set -euo pipefail

# Ensure jq and common tools are on PATH
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:/usr/local/bin:$PATH"

# 5etools D&D 5E Reference Lookup
# Usage: lookup.sh <command> [args...]
#
# Commands:
#   monster <name> [source]       Look up a monster by name
#   monsters <source>             List monsters from a source
#   spell <name> [source]         Look up a spell by name
#   spells <source>               List spells from a source
#   item <name>                   Look up an item by name
#   items [rarity]                List items, optionally by rarity
#   condition <name>              Look up a condition
#   conditions                    List all conditions
#   background <name>             Look up a background
#   backgrounds                   List all backgrounds
#   adventures                    List all adventures
#   adventure-outline <id>        Table of contents for an adventure
#   adventure-read <id> <section> Read a chapter/section
#   adventure-search <id> <kw>    Search adventure text
#   sources                       List common source abbreviations

BASE_URL="https://5e.r2plays.games"
DATA_URL="${BASE_URL}/data"
IMG_URL="${BASE_URL}/img"

CMD="${1:?Usage: lookup.sh <command> [args...]}"
shift

# --- helpers ---

fetch() {
  local url="$1"
  local response
  for _attempt in 1 2; do
    response=$(curl -sf --connect-timeout 10 --max-time 30 \
      -H "Accept: application/json" \
      "$url" 2>&1) && {
      echo "$response"
      return 0
    }
    [[ $_attempt -eq 1 ]] && sleep 1
  done
  echo "{\"error\":\"Failed to fetch $url after 2 attempts\"}" >&2
  return 1
}

# Strip 5etools markup tags from text
strip_tags() {
  sed -E \
    -e 's/\{@(creature|spell|item|skill|condition|action|sense|status|chance|class|race|background|feat|hazard|disease|reward|deity|card|deck|table|vehicle|object|trap|classFeature|subclassFeature|optfeature|language|charoption|psionic|variantrule|quickref|note|adventure|book|filter) ([^|}]+)\|[^}]*\}/\2/g' \
    -e 's/\{@(creature|spell|item|skill|condition|action|sense|status|chance|class|race|background|feat|hazard|disease|reward|deity|card|deck|table|vehicle|object|trap|classFeature|subclassFeature|optfeature|language|charoption|psionic|variantrule|quickref|note|adventure|book|filter) ([^}]+)\}/\2/g' \
    -e 's/\{@dc ([^}]+)\}/DC \1/g' \
    -e 's/\{@dice ([^}]+)\}/\1/g' \
    -e 's/\{@damage ([^}]+)\}/\1/g' \
    -e 's/\{@scaledice [^}]+\|[^}]+\|([^}]+)\}/\1/g' \
    -e 's/\{@scaledamage [^}]+\|[^}]+\|([^}]+)\}/\1/g' \
    -e 's/\{@hit ([^}]+)\}/+\1/g' \
    -e 's/\{@b ([^}]+)\}/**\1**/g' \
    -e 's/\{@i ([^}]+)\}/*\1*/g' \
    -e 's/\{@atk mw\}/Melee Weapon Attack/g' \
    -e 's/\{@atk rw\}/Ranged Weapon Attack/g' \
    -e 's/\{@atk ms\}/Melee Spell Attack/g' \
    -e 's/\{@atk rs\}/Ranged Spell Attack/g' \
    -e 's/\{@atk mw,rw\}/Melee or Ranged Weapon Attack/g' \
    -e 's/\{@h\}/Hit: /g' \
    -e 's/\{@recharge ([^}]*)\}/Recharge \1/g' \
    -e 's/\{@recharge\}/Recharge 6/g' \
    -e 's/\{@[a-zA-Z]+ ([^|}]+)\|[^}]*\}/\1/g' \
    -e 's/\{@[a-zA-Z]+ ([^}]+)\}/\1/g'
}

# Recursively extract text from 5etools entries array
extract_text() {
  jq -r '
    def walk_entries:
      if type == "string" then .
      elif type == "object" then
        (if .name then ("**" + .name + "**\n") else "" end) +
        (if .entries then (.entries | map(walk_entries) | join("\n")) else "" end) +
        (if .items then
          (if (.items[0] | type) == "string" then
            (.items | map("* " + .) | join("\n"))
          elif (.items[0] | type) == "object" then
            (.items | map(
              if .name then
                "**" + .name + "** " + (if .entry then .entry elif .entries then (.entries | map(walk_entries) | join("\n")) else "" end)
              else walk_entries
              end
            ) | join("\n"))
          else ""
          end)
        else "" end) +
        (if .type == "table" then
          (if .caption then ("**" + .caption + "**\n") else "" end) +
          (if .colLabels then ((.colLabels | join(" | ")) + "\n") else "" end) +
          (if .rows then (.rows | map(map(tostring) | join(" | ")) | join("\n")) else "" end)
        else "" end)
      elif type == "array" then (map(walk_entries) | join("\n"))
      else tostring
      end;
    if type == "array" then (map(walk_entries) | join("\n"))
    elif type == "object" then walk_entries
    else tostring
    end
  '
}

# Build a 5etools page URL
page_url() {
  local page="$1" name="$2" source="$3"
  local slug
  slug=$(echo "$name" | tr '[:upper:]' '[:lower:]' | sed 's/ /%20/g')
  local src_lower
  src_lower=$(echo "$source" | tr '[:upper:]' '[:lower:]')
  echo "${BASE_URL}/${page}#${slug}_${src_lower}"
}

# Build image URL for a monster
monster_image_url() {
  local source="$1" name="$2"
  local encoded_name
  encoded_name=$(echo "$name" | sed 's/ /%20/g')
  echo "${IMG_URL}/${source}/${encoded_name}.webp"
}

# --- colors ---
COLOR_MONSTER=15158332
COLOR_SPELL=3447003
COLOR_ITEM=15844367
COLOR_CONDITION=3066993
COLOR_BACKGROUND=1752220
COLOR_ADVENTURE=10181046
COLOR_LIST=9807270

# --- commands ---

case "$CMD" in

# ============================================================
# MONSTER
# ============================================================
monster)
  NAME="${1:?Usage: lookup.sh monster <name> [source]}"
  SOURCE="${2:-}"

  if [[ -n "$SOURCE" ]]; then
    SOURCES_TO_TRY=("$SOURCE")
  else
    SOURCES_TO_TRY=(MM XMM MPMM VGM MTF BGDIA CoS IDRotF ToA SKT WDH WDMM OotA PotA)
  fi

  INDEX=$(fetch "${DATA_URL}/bestiary/index.json") || exit 1

  FOUND=""
  for src in "${SOURCES_TO_TRY[@]}"; do
    FILE=$(echo "$INDEX" | jq -r --arg s "$src" '.[$s] // empty')
    [[ -z "$FILE" ]] && continue

    DATA=$(fetch "${DATA_URL}/bestiary/${FILE}") || continue

    MATCH=$(echo "$DATA" | jq -c --arg name "$NAME" '
      [.monster[] | select(.name | ascii_downcase == ($name | ascii_downcase))][0] // empty
    ' 2>/dev/null)

    if [[ -n "$MATCH" && "$MATCH" != "null" ]]; then
      FOUND="$MATCH"
      FOUND_SRC="$src"
      break
    fi
  done

  if [[ -z "$FOUND" ]]; then
    echo "{\"error\":\"Monster '${NAME}' not found. Try specifying a source code (e.g. MM, VGM, MPMM).\"}"
    exit 0
  fi

  M_NAME=$(echo "$FOUND" | jq -r '.name')
  M_SOURCE=$(echo "$FOUND" | jq -r '.source')
  M_PAGE=$(echo "$FOUND" | jq -r '.page // ""')
  M_SIZE=$(echo "$FOUND" | jq -r '
    if .size then
      (.size | if type == "array" then .[0] else . end) |
      {"T":"Tiny","S":"Small","M":"Medium","L":"Large","H":"Huge","G":"Gargantuan"}[.] // .
    else "Unknown" end')
  M_TYPE=$(echo "$FOUND" | jq -r '
    if .type | type == "string" then .type
    elif .type | type == "object" then .type.type
    else "Unknown" end')
  M_ALIGN=$(echo "$FOUND" | jq -r '
    if .alignment then
      [.alignment[] |
        {"L":"Lawful","N":"Neutral","C":"Chaotic","G":"Good","E":"Evil","U":"Unaligned","A":"Any"}[.] // .
      ] | join(" ")
    else "Unaligned" end')
  M_AC=$(echo "$FOUND" | jq -r '
    if .ac then
      [.ac[] |
        if type == "number" then tostring
        elif type == "object" then
          (.ac | tostring) + (if .from then " (" + (.from | map(.) | join(", ")) + ")" else "" end)
        else tostring end
      ] | join(", ")
    else "?" end' | strip_tags)
  M_HP=$(echo "$FOUND" | jq -r '
    if .hp then
      if .hp.average then
        (.hp.average | tostring) + (if .hp.formula then " (" + .hp.formula + ")" else "" end)
      elif .hp.special then .hp.special
      else "?" end
    else "?" end')
  M_SPEED=$(echo "$FOUND" | jq -r '
    if .speed then
      [.speed | to_entries[] |
        if .key == "walk" then
          if .value | type == "number" then (.value | tostring) + " ft."
          elif .value | type == "object" then (.value.number | tostring) + " ft. " + (.value.condition // "")
          else "" end
        else
          .key + " " + (
            if .value | type == "number" then (.value | tostring) + " ft."
            elif .value | type == "object" then (.value.number | tostring) + " ft. " + (.value.condition // "")
            else "" end
          )
        end
      ] | map(select(. != "")) | join(", ")
    else "?" end' | strip_tags)
  M_CR=$(echo "$FOUND" | jq -r '
    if .cr then
      if .cr | type == "string" then .cr
      elif .cr | type == "object" then .cr.cr
      else "?" end
    else "?" end')
  M_STR=$(echo "$FOUND" | jq -r '.str // "?"')
  M_DEX=$(echo "$FOUND" | jq -r '.dex // "?"')
  M_CON=$(echo "$FOUND" | jq -r '.con // "?"')
  M_INT=$(echo "$FOUND" | jq -r '.int // "?"')
  M_WIS=$(echo "$FOUND" | jq -r '.wis // "?"')
  M_CHA=$(echo "$FOUND" | jq -r '.cha // "?"')
  M_HAS_IMG=$(echo "$FOUND" | jq -r '.hasFluffImages // false')

  M_TRAITS=""
  RAW_TRAITS=$(echo "$FOUND" | jq -c '.trait // []')
  if [[ "$RAW_TRAITS" != "[]" ]]; then
    M_TRAITS=$(echo "$RAW_TRAITS" | jq -r '
      map("**" + .name + ".** " + (.entries | map(if type == "string" then . else "" end) | join(" "))) | join("\n\n")
    ' | strip_tags)
  fi

  M_ACTIONS=""
  RAW_ACTIONS=$(echo "$FOUND" | jq -c '.action // []')
  if [[ "$RAW_ACTIONS" != "[]" ]]; then
    M_ACTIONS=$(echo "$RAW_ACTIONS" | jq -r '
      map("**" + .name + ".** " + (.entries | map(if type == "string" then . else "" end) | join(" "))) | join("\n\n")
    ' | strip_tags)
  fi

  DESC="${M_SIZE} ${M_TYPE}, ${M_ALIGN}"
  DETAILS=""
  [[ -n "$M_TRAITS" ]] && DETAILS="${DETAILS}\n\n**Traits**\n${M_TRAITS}"
  [[ -n "$M_ACTIONS" ]] && DETAILS="${DETAILS}\n\n**Actions**\n${M_ACTIONS}"

  if [[ ${#DETAILS} -gt 3800 ]]; then
    DETAILS="${DETAILS:0:3800}...\n\n*[Content truncated — see full entry on 5etools]*"
  fi

  FULL_DESC="${DESC}${DETAILS}"

  IMAGE=""
  if [[ "$M_HAS_IMG" == "true" ]]; then
    IMAGE=$(monster_image_url "$M_SOURCE" "$M_NAME")
  fi

  URL=$(page_url "bestiary.html" "$M_NAME" "$M_SOURCE")
  FOOTER="Source: ${M_SOURCE}"
  [[ -n "$M_PAGE" ]] && FOOTER="${FOOTER} p.${M_PAGE}"

  jq -n \
    --arg title "$M_NAME" \
    --arg url "$URL" \
    --arg image "$IMAGE" \
    --arg desc "$FULL_DESC" \
    --arg ac "$M_AC" \
    --arg hp "$M_HP" \
    --arg speed "$M_SPEED" \
    --arg cr "$M_CR" \
    --arg str "$M_STR" --arg dex "$M_DEX" --arg con "$M_CON" \
    --arg int "$M_INT" --arg wis "$M_WIS" --arg cha "$M_CHA" \
    --arg footer "$FOOTER" \
    --argjson color "$COLOR_MONSTER" \
    '{
      title: $title,
      url: $url,
      image: (if $image != "" then $image else null end),
      description: $desc,
      fields: [
        { name: "AC", value: $ac, inline: true },
        { name: "HP", value: $hp, inline: true },
        { name: "Speed", value: $speed, inline: true },
        { name: "CR", value: $cr, inline: true },
        { name: "STR", value: $str, inline: true },
        { name: "DEX", value: $dex, inline: true },
        { name: "CON", value: $con, inline: true },
        { name: "INT", value: $int, inline: true },
        { name: "WIS", value: $wis, inline: true },
        { name: "CHA", value: $cha, inline: true }
      ],
      footer: $footer,
      color: $color
    }'
  ;;

# ============================================================
# MONSTERS (list)
# ============================================================
monsters)
  SOURCE="${1:?Usage: lookup.sh monsters <source>}"
  INDEX=$(fetch "${DATA_URL}/bestiary/index.json") || exit 1
  FILE=$(echo "$INDEX" | jq -r --arg s "$SOURCE" '.[$s] // empty')
  if [[ -z "$FILE" ]]; then
    echo "{\"error\":\"Unknown source '${SOURCE}'. Use 'lookup.sh sources' to see valid codes.\"}"
    exit 0
  fi
  DATA=$(fetch "${DATA_URL}/bestiary/${FILE}") || exit 1
  echo "$DATA" | jq --arg src "$SOURCE" --argjson color "$COLOR_LIST" '{
    title: ("Monsters - " + $src),
    url: ("https://5e.r2plays.games/bestiary.html"),
    description: (
      [.monster | sort_by(.name) | .[:30][] |
        .name + " (CR " + (if .cr | type == "string" then .cr elif .cr | type == "object" then .cr.cr else "?" end) + ")"
      ] | to_entries | map((.key + 1 | tostring) + ". " + .value) | join("\n")
    ),
    fields: [
      { name: "Total", value: (.monster | length | tostring), inline: true }
    ],
    footer: ("Source: " + $src),
    color: $color
  }'
  ;;

# ============================================================
# SPELL
# ============================================================
spell)
  NAME="${1:?Usage: lookup.sh spell <name> [source]}"
  SOURCE="${2:-}"

  if [[ -n "$SOURCE" ]]; then
    SOURCES_TO_TRY=("$SOURCE")
  else
    SOURCES_TO_TRY=(PHB XPHB XGE TCE SCC AAG EGW FTD)
  fi

  INDEX=$(fetch "${DATA_URL}/spells/index.json") || exit 1

  FOUND=""
  for src in "${SOURCES_TO_TRY[@]}"; do
    FILE=$(echo "$INDEX" | jq -r --arg s "$src" '.[$s] // empty')
    [[ -z "$FILE" ]] && continue

    DATA=$(fetch "${DATA_URL}/spells/${FILE}") || continue

    MATCH=$(echo "$DATA" | jq -c --arg name "$NAME" '
      [.spell[] | select(.name | ascii_downcase == ($name | ascii_downcase))][0] // empty
    ' 2>/dev/null)

    if [[ -n "$MATCH" && "$MATCH" != "null" ]]; then
      FOUND="$MATCH"
      break
    fi
  done

  if [[ -z "$FOUND" ]]; then
    echo "{\"error\":\"Spell '${NAME}' not found. Try specifying a source code (e.g. PHB, XGE, TCE).\"}"
    exit 0
  fi

  S_NAME=$(echo "$FOUND" | jq -r '.name')
  S_SOURCE=$(echo "$FOUND" | jq -r '.source')
  S_PAGE=$(echo "$FOUND" | jq -r '.page // ""')
  S_LEVEL=$(echo "$FOUND" | jq -r '.level')
  S_SCHOOL=$(echo "$FOUND" | jq -r '
    {"A":"Abjuration","C":"Conjuration","D":"Divination","E":"Enchantment",
     "V":"Evocation","I":"Illusion","N":"Necromancy","T":"Transmutation"}[.school] // .school')
  S_TIME=$(echo "$FOUND" | jq -r '
    [.time[] | (.number | tostring) + " " + .unit + (if .condition then " " + .condition else "" end)] | join(", ")' | strip_tags)
  S_RANGE=$(echo "$FOUND" | jq -r '
    if .range.type == "point" then
      if .range.distance.type == "self" then "Self"
      elif .range.distance.type == "touch" then "Touch"
      elif .range.distance.type == "sight" then "Sight"
      elif .range.distance.type == "unlimited" then "Unlimited"
      else (.range.distance.amount | tostring) + " " + .range.distance.type
      end
    elif .range.type == "cone" then
      "Self (" + (.range.distance.amount | tostring) + "-foot cone)"
    elif .range.type == "line" then
      "Self (" + (.range.distance.amount | tostring) + "-foot line)"
    elif .range.type == "cube" then
      "Self (" + (.range.distance.amount | tostring) + "-foot cube)"
    elif .range.type == "sphere" then
      "Self (" + (.range.distance.amount | tostring) + "-foot sphere)"
    elif .range.type == "hemisphere" then
      "Self (" + (.range.distance.amount | tostring) + "-foot hemisphere)"
    elif .range.type == "radius" then
      "Self (" + (.range.distance.amount | tostring) + "-foot radius)"
    elif .range.type == "special" then "Special"
    else "Unknown"
    end')
  S_COMP=$(echo "$FOUND" | jq -r '
    [
      (if .components.v then "V" else empty end),
      (if .components.s then "S" else empty end),
      (if .components.m then
        if .components.m | type == "string" then "M (" + .components.m + ")"
        elif .components.m | type == "object" then "M (" + .components.m.text + ")"
        else "M" end
      else empty end)
    ] | join(", ")' | strip_tags)
  S_DUR=$(echo "$FOUND" | jq -r '
    [.duration[] |
      if .type == "instant" then "Instantaneous"
      elif .type == "timed" then
        (if .concentration then "Concentration, up to " else "" end) +
        (.duration.amount | tostring) + " " + .duration.type + (if .duration.amount > 1 then "s" else "" end)
      elif .type == "permanent" then "Until dispelled"
      elif .type == "special" then "Special"
      else .type
      end
    ] | join(", ")')
  S_CLASSES=$(echo "$FOUND" | jq -r '
    if .classes and .classes.fromClassList then
      [.classes.fromClassList[] | .name] | unique | join(", ")
    else "" end')
  S_RITUAL=$(echo "$FOUND" | jq -r 'if .meta and .meta.ritual then "Yes" else "No" end')

  if [[ "$S_LEVEL" == "0" ]]; then
    LEVEL_TEXT="${S_SCHOOL} cantrip"
  else
    LEVEL_TEXT="Level ${S_LEVEL} ${S_SCHOOL}"
  fi

  S_TEXT=$(echo "$FOUND" | jq '.entries // []' | extract_text | strip_tags)
  S_HIGHER=""
  RAW_HIGHER=$(echo "$FOUND" | jq -c '.entriesHigherLevel // []')
  if [[ "$RAW_HIGHER" != "[]" ]]; then
    S_HIGHER=$(echo "$RAW_HIGHER" | extract_text | strip_tags)
  fi

  DESC="${LEVEL_TEXT}\n\n${S_TEXT}"
  [[ -n "$S_HIGHER" ]] && DESC="${DESC}\n\n**At Higher Levels.** ${S_HIGHER}"

  if [[ ${#DESC} -gt 3800 ]]; then
    DESC="${DESC:0:3800}...\n\n*[Content truncated — see full entry on 5etools]*"
  fi

  URL=$(page_url "spells.html" "$S_NAME" "$S_SOURCE")
  FOOTER="Source: ${S_SOURCE}"
  [[ -n "$S_PAGE" ]] && FOOTER="${FOOTER} p.${S_PAGE}"

  jq -n \
    --arg title "$S_NAME" \
    --arg url "$URL" \
    --arg desc "$DESC" \
    --arg time "$S_TIME" \
    --arg range "$S_RANGE" \
    --arg comp "$S_COMP" \
    --arg dur "$S_DUR" \
    --arg classes "$S_CLASSES" \
    --arg ritual "$S_RITUAL" \
    --arg footer "$FOOTER" \
    --argjson color "$COLOR_SPELL" \
    '{
      title: $title,
      url: $url,
      image: null,
      description: $desc,
      fields: [
        { name: "Casting Time", value: $time, inline: true },
        { name: "Range", value: $range, inline: true },
        { name: "Components", value: $comp, inline: true },
        { name: "Duration", value: $dur, inline: true },
        { name: "Classes", value: (if $classes != "" then $classes else "-" end), inline: true },
        { name: "Ritual", value: $ritual, inline: true }
      ],
      footer: $footer,
      color: $color
    }'
  ;;

# ============================================================
# SPELLS (list)
# ============================================================
spells)
  SOURCE="${1:?Usage: lookup.sh spells <source>}"
  INDEX=$(fetch "${DATA_URL}/spells/index.json") || exit 1
  FILE=$(echo "$INDEX" | jq -r --arg s "$SOURCE" '.[$s] // empty')
  if [[ -z "$FILE" ]]; then
    echo "{\"error\":\"Unknown source '${SOURCE}'. Use 'lookup.sh sources' to see valid codes.\"}"
    exit 0
  fi
  DATA=$(fetch "${DATA_URL}/spells/${FILE}") || exit 1
  echo "$DATA" | jq --arg src "$SOURCE" --argjson color "$COLOR_LIST" '{
    title: ("Spells - " + $src),
    url: "https://5e.r2plays.games/spells.html",
    description: (
      [.spell | sort_by(.level, .name) | .[:30][] |
        (if .level == 0 then "Cantrip" else "Lvl " + (.level | tostring) end) + " - " + .name
      ] | to_entries | map((.key + 1 | tostring) + ". " + .value) | join("\n")
    ),
    fields: [
      { name: "Total", value: (.spell | length | tostring), inline: true }
    ],
    footer: ("Source: " + $src),
    color: $color
  }'
  ;;

# ============================================================
# ITEM
# ============================================================
item)
  NAME="${1:?Usage: lookup.sh item <name>}"

  FOUND=""
  for endpoint in "items.json:item" "items-base.json:baseitem"; do
    IFS=: read -r file key <<< "$endpoint"
    DATA=$(fetch "${DATA_URL}/${file}") || continue
    MATCH=$(echo "$DATA" | jq -c --arg name "$NAME" --arg key "$key" '
      [.[$key][] | select(.name | ascii_downcase == ($name | ascii_downcase))][0] // empty
    ' 2>/dev/null)
    if [[ -n "$MATCH" && "$MATCH" != "null" ]]; then
      FOUND="$MATCH"
      break
    fi
  done

  if [[ -z "$FOUND" ]]; then
    echo "{\"error\":\"Item '${NAME}' not found.\"}"
    exit 0
  fi

  I_NAME=$(echo "$FOUND" | jq -r '.name')
  I_SOURCE=$(echo "$FOUND" | jq -r '.source')
  I_PAGE=$(echo "$FOUND" | jq -r '.page // ""')
  I_RARITY=$(echo "$FOUND" | jq -r '.rarity // "unknown"')
  I_TYPE=$(echo "$FOUND" | jq -r '
    if .wondrous then "Wondrous item"
    elif .type then .type
    else "Item" end')
  I_ATTUNE=$(echo "$FOUND" | jq -r '
    if .reqAttune == true then "Yes"
    elif .reqAttune then "Yes (" + .reqAttune + ")"
    else "No" end')
  I_WEIGHT=$(echo "$FOUND" | jq -r 'if .weight then (.weight | tostring) + " lb." else "-" end')
  I_VALUE=$(echo "$FOUND" | jq -r '
    if .value then
      (.value / 100 | floor | tostring) + " gp"
    else "-" end')
  I_TEXT=$(echo "$FOUND" | jq '.entries // []' | extract_text | strip_tags)
  I_HAS_IMG=$(echo "$FOUND" | jq -r '.hasFluffImages // false')

  DESC="${I_TYPE}, ${I_RARITY}"
  [[ -n "$I_TEXT" ]] && DESC="${DESC}\n\n${I_TEXT}"

  if [[ ${#DESC} -gt 3800 ]]; then
    DESC="${DESC:0:3800}...\n\n*[Content truncated — see full entry on 5etools]*"
  fi

  IMAGE=""
  if [[ "$I_HAS_IMG" == "true" ]]; then
    IMAGE="${IMG_URL}/items/${I_SOURCE}/$(echo "$I_NAME" | sed 's/ /%20/g').webp"
  fi

  URL=$(page_url "items.html" "$I_NAME" "$I_SOURCE")
  FOOTER="Source: ${I_SOURCE}"
  [[ -n "$I_PAGE" ]] && FOOTER="${FOOTER} p.${I_PAGE}"

  jq -n \
    --arg title "$I_NAME" \
    --arg url "$URL" \
    --arg image "$IMAGE" \
    --arg desc "$DESC" \
    --arg rarity "$I_RARITY" \
    --arg attune "$I_ATTUNE" \
    --arg weight "$I_WEIGHT" \
    --arg value "$I_VALUE" \
    --arg footer "$FOOTER" \
    --argjson color "$COLOR_ITEM" \
    '{
      title: $title,
      url: $url,
      image: (if $image != "" then $image else null end),
      description: $desc,
      fields: [
        { name: "Rarity", value: $rarity, inline: true },
        { name: "Attunement", value: $attune, inline: true },
        { name: "Weight", value: $weight, inline: true },
        { name: "Value", value: $value, inline: true }
      ],
      footer: $footer,
      color: $color
    }'
  ;;

# ============================================================
# ITEMS (list)
# ============================================================
items)
  RARITY="${1:-}"
  DATA=$(fetch "${DATA_URL}/items.json") || exit 1

  FILTER=""
  if [[ -n "$RARITY" ]]; then
    FILTER="| select(.rarity | ascii_downcase == (\"$RARITY\" | ascii_downcase))"
  fi

  echo "$DATA" | jq --arg rarity "$RARITY" --argjson color "$COLOR_LIST" \
    --arg filter_desc "$(if [[ -n "$RARITY" ]]; then echo " ($RARITY)"; else echo ""; fi)" \
    '{
      title: ("Magic Items" + $filter_desc),
      url: "https://5e.r2plays.games/items.html",
      description: (
        [.item | sort_by(.name) | .[] '"${FILTER}"' | .name + " (" + (.rarity // "?") + ")"] |
        .[:30] | to_entries | map((.key + 1 | tostring) + ". " + .value) | join("\n")
      ),
      fields: [
        { name: "Shown", value: ([.item[] '"${FILTER}"'] | length | if . > 30 then "30 of " + (. | tostring) else (. | tostring) end), inline: true }
      ],
      footer: "5etools Item Reference",
      color: $color
    }'
  ;;

# ============================================================
# CONDITION
# ============================================================
condition)
  NAME="${1:?Usage: lookup.sh condition <name>}"
  DATA=$(fetch "${DATA_URL}/conditionsdiseases.json") || exit 1

  FOUND=$(echo "$DATA" | jq -c --arg name "$NAME" '
    [(.condition + .disease)[] | select(.name | ascii_downcase == ($name | ascii_downcase))][0] // empty
  ' 2>/dev/null)

  if [[ -z "$FOUND" ]]; then
    echo "{\"error\":\"Condition or disease '${NAME}' not found.\"}"
    exit 0
  fi

  C_NAME=$(echo "$FOUND" | jq -r '.name')
  C_SOURCE=$(echo "$FOUND" | jq -r '.source')
  C_PAGE=$(echo "$FOUND" | jq -r '.page // ""')
  C_TEXT=$(echo "$FOUND" | jq '.entries // []' | extract_text | strip_tags)

  URL=$(page_url "conditionsdiseases.html" "$C_NAME" "$C_SOURCE")
  FOOTER="Source: ${C_SOURCE}"
  [[ -n "$C_PAGE" ]] && FOOTER="${FOOTER} p.${C_PAGE}"

  jq -n \
    --arg title "$C_NAME" \
    --arg url "$URL" \
    --arg desc "$C_TEXT" \
    --arg footer "$FOOTER" \
    --argjson color "$COLOR_CONDITION" \
    '{
      title: $title,
      url: $url,
      image: null,
      description: $desc,
      fields: [],
      footer: $footer,
      color: $color
    }'
  ;;

# ============================================================
# CONDITIONS (list)
# ============================================================
conditions)
  DATA=$(fetch "${DATA_URL}/conditionsdiseases.json") || exit 1
  echo "$DATA" | jq --argjson color "$COLOR_LIST" '{
    title: "Conditions & Diseases",
    url: "https://5e.r2plays.games/conditionsdiseases.html",
    description: (
      "**Conditions:**\n" +
      ([.condition | unique_by(.name) | sort_by(.name) | .[].name] | join(", ")) +
      "\n\n**Diseases:**\n" +
      ([.disease | unique_by(.name) | sort_by(.name) | .[].name] | join(", "))
    ),
    fields: [],
    footer: "5etools Reference",
    color: $color
  }'
  ;;

# ============================================================
# BACKGROUND
# ============================================================
background)
  NAME="${1:?Usage: lookup.sh background <name>}"
  DATA=$(fetch "${DATA_URL}/backgrounds.json") || exit 1

  FOUND=$(echo "$DATA" | jq -c --arg name "$NAME" '
    [.background[] | select(.name | ascii_downcase == ($name | ascii_downcase))][0] // empty
  ' 2>/dev/null)

  if [[ -z "$FOUND" ]]; then
    echo "{\"error\":\"Background '${NAME}' not found.\"}"
    exit 0
  fi

  B_NAME=$(echo "$FOUND" | jq -r '.name')
  B_SOURCE=$(echo "$FOUND" | jq -r '.source')
  B_PAGE=$(echo "$FOUND" | jq -r '.page // ""')
  B_SKILLS=$(echo "$FOUND" | jq -r '
    if .skillProficiencies then
      [.skillProficiencies[0] | to_entries[] | select(.value == true) | .key] | join(", ")
    else "-" end')
  B_TEXT=$(echo "$FOUND" | jq '.entries // []' | extract_text | strip_tags)
  B_HAS_IMG=$(echo "$FOUND" | jq -r '.hasFluffImages // false')

  if [[ ${#B_TEXT} -gt 3800 ]]; then
    B_TEXT="${B_TEXT:0:3800}...\n\n*[Content truncated — see full entry on 5etools]*"
  fi

  IMAGE=""
  if [[ "$B_HAS_IMG" == "true" ]]; then
    IMAGE="${IMG_URL}/backgrounds/${B_SOURCE}/$(echo "$B_NAME" | sed 's/ /%20/g').webp"
  fi

  URL=$(page_url "backgrounds.html" "$B_NAME" "$B_SOURCE")
  FOOTER="Source: ${B_SOURCE}"
  [[ -n "$B_PAGE" ]] && FOOTER="${FOOTER} p.${B_PAGE}"

  jq -n \
    --arg title "$B_NAME" \
    --arg url "$URL" \
    --arg image "$IMAGE" \
    --arg desc "$B_TEXT" \
    --arg skills "$B_SKILLS" \
    --arg footer "$FOOTER" \
    --argjson color "$COLOR_BACKGROUND" \
    '{
      title: $title,
      url: $url,
      image: (if $image != "" then $image else null end),
      description: $desc,
      fields: [
        { name: "Skill Proficiencies", value: $skills, inline: true }
      ],
      footer: $footer,
      color: $color
    }'
  ;;

# ============================================================
# BACKGROUNDS (list)
# ============================================================
backgrounds)
  DATA=$(fetch "${DATA_URL}/backgrounds.json") || exit 1
  echo "$DATA" | jq --argjson color "$COLOR_LIST" '{
    title: "Backgrounds",
    url: "https://5e.r2plays.games/backgrounds.html",
    description: (
      [.background | unique_by(.name) | sort_by(.name) | .[:40][] |
        .name + " (" + .source + ")"
      ] | to_entries | map((.key + 1 | tostring) + ". " + .value) | join("\n")
    ),
    fields: [
      { name: "Total", value: (.background | unique_by(.name) | length | tostring), inline: true }
    ],
    footer: "5etools Reference",
    color: $color
  }'
  ;;

# ============================================================
# ADVENTURES (list)
# ============================================================
adventures)
  DATA=$(fetch "${DATA_URL}/adventures.json") || exit 1
  echo "$DATA" | jq --argjson color "$COLOR_LIST" '{
    title: "D&D 5E Adventures",
    url: "https://5e.r2plays.games/adventures.html",
    description: (
      [.adventure | sort_by(.published) | .[] |
        "**" + .name + "** (`" + .id + "`) - Levels " +
        (if .level then ((.level.start | tostring) + "-" + (.level.end | tostring)) else "?" end) +
        (if .storyline then " - " + .storyline else "" end)
      ] | join("\n")
    ),
    fields: [
      { name: "Total", value: (.adventure | length | tostring), inline: true }
    ],
    footer: "Use adventure-outline <ID> for chapter details",
    color: $color
  }'
  ;;

# ============================================================
# ADVENTURE-OUTLINE
# ============================================================
adventure-outline)
  ID="${1:?Usage: lookup.sh adventure-outline <adventure-id>}"
  DATA=$(fetch "${DATA_URL}/adventures.json") || exit 1

  FOUND=$(echo "$DATA" | jq -r --arg id "$ID" '
    .adventure[] | select(.id | ascii_downcase == ($id | ascii_downcase))
  ')

  if [[ -z "$FOUND" ]]; then
    echo "{\"error\":\"Adventure '${ID}' not found. Use 'adventures' to list available IDs.\"}"
    exit 0
  fi

  A_NAME=$(echo "$FOUND" | jq -r '.name')
  A_ID=$(echo "$FOUND" | jq -r '.id')
  A_COVER="${IMG_URL}/covers/${A_ID}.webp"

  echo "$FOUND" | jq --arg name "$A_NAME" --arg id "$A_ID" --arg cover "$A_COVER" --argjson color "$COLOR_ADVENTURE" '{
    title: $name,
    url: ("https://5e.r2plays.games/adventure.html#" + ($id | ascii_downcase)),
    image: $cover,
    description: (
      [.contents[] |
        (if .ordinal then
          (if .ordinal.type == "chapter" then "Ch. " + (.ordinal.identifier | tostring) + ": "
           elif .ordinal.type == "appendix" then "App. " + .ordinal.identifier + ": "
           elif .ordinal.type == "part" then "Part " + (.ordinal.identifier | tostring) + ": "
           else "" end)
        else "" end) + .name
      ] | to_entries | map((.key + 1 | tostring) + ". " + .value) | join("\n")
    ),
    fields: [
      { name: "Levels", value: (if .level then ((.level.start | tostring) + "-" + (.level.end | tostring)) else "?" end), inline: true },
      { name: "Published", value: (.published // "?"), inline: true },
      { name: "Storyline", value: (.storyline // "-"), inline: true }
    ],
    footer: ("Use adventure-read " + $id + " \"<section>\" to read a chapter"),
    color: $color
  }'
  ;;

# ============================================================
# ADVENTURE-READ
# ============================================================
adventure-read)
  ID="${1:?Usage: lookup.sh adventure-read <adventure-id> <section-name>}"
  SECTION="${2:?Usage: lookup.sh adventure-read <adventure-id> <section-name>}"
  ID_LOWER=$(echo "$ID" | tr '[:upper:]' '[:lower:]')

  DATA=$(fetch "${DATA_URL}/adventure/adventure-${ID_LOWER}.json") || exit 1

  MATCH=$(echo "$DATA" | jq -r --arg sec "$SECTION" '
    .data[] | select(.name | ascii_downcase == ($sec | ascii_downcase))
  ' 2>/dev/null)

  if [[ -z "$MATCH" ]]; then
    SECTIONS=$(echo "$DATA" | jq -r '[.data[].name] | join(", ")')
    echo "{\"error\":\"Section '${SECTION}' not found. Available: ${SECTIONS}\"}"
    exit 0
  fi

  SEC_NAME=$(echo "$MATCH" | jq -r '.name')
  SEC_TEXT=$(echo "$MATCH" | jq '.entries // []' | extract_text | strip_tags)

  if [[ ${#SEC_TEXT} -gt 3800 ]]; then
    SEC_TEXT="${SEC_TEXT:0:3800}...\n\n*[Content truncated — use 5etools for the full chapter]*"
  fi

  URL="https://5e.r2plays.games/adventure.html#${ID_LOWER}"
  COVER="${IMG_URL}/covers/${ID}.webp"

  jq -n \
    --arg title "${SEC_NAME} - ${ID}" \
    --arg url "$URL" \
    --arg cover "$COVER" \
    --arg desc "$SEC_TEXT" \
    --argjson color "$COLOR_ADVENTURE" \
    '{
      title: $title,
      url: $url,
      image: $cover,
      description: $desc,
      fields: [],
      footer: "5etools Adventure Content",
      color: $color
    }'
  ;;

# ============================================================
# ADVENTURE-SEARCH
# ============================================================
adventure-search)
  ID="${1:?Usage: lookup.sh adventure-search <adventure-id> <keyword>}"
  KEYWORD="${2:?Usage: lookup.sh adventure-search <adventure-id> <keyword>}"
  ID_LOWER=$(echo "$ID" | tr '[:upper:]' '[:lower:]')

  DATA=$(fetch "${DATA_URL}/adventure/adventure-${ID_LOWER}.json") || exit 1

  RESULTS=$(echo "$DATA" | jq -r --arg kw "$KEYWORD" '
    [.data[] |
      . as $section |
      ($section | tostring | ascii_downcase) as $text |
      if ($text | contains($kw | ascii_downcase)) then
        $section.name
      else empty end
    ] | unique | join(", ")
  ')

  if [[ -z "$RESULTS" || "$RESULTS" == "" ]]; then
    echo "{\"error\":\"No matches for '${KEYWORD}' in adventure ${ID}.\"}"
    exit 0
  fi

  jq -n \
    --arg title "Search: \"${KEYWORD}\" in ${ID}" \
    --arg url "https://5e.r2plays.games/adventure.html#${ID_LOWER}" \
    --arg desc "Keyword found in the following sections:\n\n**${RESULTS}**\n\nUse adventure-read ${ID} \"<section>\" to read a specific section." \
    --argjson color "$COLOR_ADVENTURE" \
    '{
      title: $title,
      url: $url,
      image: null,
      description: $desc,
      fields: [],
      footer: "5etools Adventure Search",
      color: $color
    }'
  ;;

# ============================================================
# SOURCES
# ============================================================
sources)
  jq -n --argjson color "$COLOR_LIST" '{
    title: "Common 5E Source Abbreviations",
    url: "https://5e.r2plays.games",
    description: null,
    fields: [
      { name: "Core Rules", value: "**PHB** Players Handbook (2014)\n**XPHB** Players Handbook (2024)\n**DMG** Dungeon Masters Guide\n**XDMG** DMG (2024)\n**MM** Monster Manual\n**XMM** Monster Manual (2024)", inline: false },
      { name: "Supplements", value: "**XGE** Xanathars Guide\n**TCE** Tashas Cauldron\n**FTD** Fizbans Treasury\n**MPMM** Monsters of the Multiverse\n**VGM** Volos Guide\n**MTF** Mordenkainens Tome", inline: false },
      { name: "Adventures", value: "**LMoP** Lost Mine of Phandelver\n**CoS** Curse of Strahd\n**ToA** Tomb of Annihilation\n**WDH** Waterdeep Dragon Heist\n**BGDIA** Baldurs Gate Descent\n**IDRotF** Icewind Dale\n**SKT** Storm Kings Thunder", inline: false },
      { name: "Settings", value: "**ERLW** Eberron\n**EGW** Explorers Guide Wildemount\n**GGR** Ravnica\n**MOT** Theros\n**SCC** Strixhaven\n**AAG** Astral Adventurers", inline: false }
    ],
    footer: "Use these codes with monster, spell, and list commands",
    color: $color
  }'
  ;;

# ============================================================
# UNKNOWN COMMAND
# ============================================================
*)
  echo "{\"error\":\"Unknown command '${CMD}'. Valid: monster, monsters, spell, spells, item, items, condition, conditions, background, backgrounds, adventures, adventure-outline, adventure-read, adventure-search, sources\"}"
  exit 1
  ;;
esac
