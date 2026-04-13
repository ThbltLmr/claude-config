#!/usr/bin/env bash
# Claude Code status line — Starship Catppuccin Frappe style

input=$(cat)

# --- Data extraction ---
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
model=$(echo "$input" | jq -r '.model.display_name // ""')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
git_branch=""
git_status_str=""

# Shorten path: replace $HOME with ~, then truncate to last 3 segments
home="$HOME"
short_path="${cwd/#$home/~}"
IFS='/' read -ra parts <<< "$short_path"
count=${#parts[@]}
if (( count > 3 )); then
  short_path="…/${parts[$((count-3))]}/${parts[$((count-2))]}/${parts[$((count-1))]}"
fi

# Git info (skip locks gracefully)
if git -C "$cwd" rev-parse --is-inside-work-tree --no-optional-locks 2>/dev/null | grep -q true; then
  git_branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
  # Status flags
  git_flags=""
  git_porcelain=$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)
  if [ -n "$git_porcelain" ]; then
    modified=$(echo "$git_porcelain" | grep -c '^ M\|^M ' 2>/dev/null || true)
    untracked=$(echo "$git_porcelain" | grep -c '^??' 2>/dev/null || true)
    [ "$modified" -gt 0 ] && git_flags="${git_flags}!"
    [ "$untracked" -gt 0 ] && git_flags="${git_flags}?"
  fi
  # Ahead/behind
  ahead=$(git -C "$cwd" --no-optional-locks rev-list --count @{u}..HEAD 2>/dev/null || echo 0)
  behind=$(git -C "$cwd" --no-optional-locks rev-list --count HEAD..@{u} 2>/dev/null || echo 0)
  [ "$ahead" -gt 0 ] && git_flags="${git_flags}⇡${ahead}"
  [ "$behind" -gt 0 ] && git_flags="${git_flags}⇣${behind}"
  [ -n "$git_flags" ] && git_status_str=" $git_flags"
fi

# Context usage bar
ctx_segment=""
if [ -n "$used_pct" ]; then
  used_int=$(printf "%.0f" "$used_pct")
  ctx_segment=" ctx:${used_int}%"
fi

# --- Usage limits (cached 60s) ---
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline"
mkdir -p "$CACHE_DIR" && chmod 700 "$CACHE_DIR"
CACHE_FILE="$CACHE_DIR/usage-cache"
CACHE_MAX_AGE=60

cache_is_stale() {
  [ ! -f "$CACHE_FILE" ] || \
  [ $(($(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0))) -gt $CACHE_MAX_AGE ]
}

if cache_is_stale; then
  CREDS=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
  if [ -n "$CREDS" ]; then
    TOKEN=$(echo "$CREDS" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
    if [ -n "$TOKEN" ]; then
      RESP=$(curl -s --max-time 5 \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TOKEN" \
        -H "anthropic-beta: oauth-2025-04-20" \
        "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)
      if [ -n "$RESP" ] && echo "$RESP" | jq . > /dev/null 2>&1; then
        echo "$RESP" > "$CACHE_FILE.tmp" && mv "$CACHE_FILE.tmp" "$CACHE_FILE"
      fi
    fi
  fi
fi

usage_segment=""
if [ -f "$CACHE_FILE" ]; then
  FIVE_HR=$(jq -r '.five_hour.utilization // empty' "$CACHE_FILE" 2>/dev/null)
  SEVEN_DAY=$(jq -r '.seven_day.utilization // empty' "$CACHE_FILE" 2>/dev/null)
  FIVE_RESET=$(jq -r '.five_hour.resets_at // empty' "$CACHE_FILE" 2>/dev/null)

  if [ -n "$FIVE_HR" ]; then
    FIVE_INT=${FIVE_HR%.*}
    case "$FIVE_INT" in ''|*[!0-9]*) FIVE_INT=0;; esac
    if [ "$FIVE_INT" -ge 80 ]; then usage_color="high"
    elif [ "$FIVE_INT" -ge 50 ]; then usage_color="mid"
    else usage_color="low"; fi

    RESET_INFO=""
    if [ -n "$FIVE_RESET" ]; then
      CLEAN_DATE=$(echo "$FIVE_RESET" | sed 's/\.[0-9]*//; s/[+-][0-9:]*$//; s/Z$//')
      RESET_EPOCH=$(TZ=UTC date -jf "%Y-%m-%dT%H:%M:%S" "$CLEAN_DATE" +%s 2>/dev/null || echo "")
      if [ -n "$RESET_EPOCH" ]; then
        DIFF=$((RESET_EPOCH - $(date +%s)))
        RESET_TIME=$(date -r "$RESET_EPOCH" +%H:%M 2>/dev/null)
        if [ "$DIFF" -gt 0 ]; then
          RESET_INFO=" $((DIFF / 3600))h$(((DIFF % 3600) / 60))m→${RESET_TIME}"
        fi
      fi
    fi

    SEVEN_INT=${SEVEN_DAY%.*}
    case "$SEVEN_INT" in ''|*[!0-9]*) SEVEN_INT=0;; esac

    five_hr_segment="5h:${FIVE_HR}%${RESET_INFO}"
    seven_day_segment="7d:${SEVEN_DAY}%"
  fi
fi

# --- Catppuccin Frappe truecolor ANSI helpers ---
# Colors: crust fg on colored bg (powerline style)
# We use reset + bold dim approach since status line renders dimmed
reset="\033[0m"

# Truecolor: fg r g b
fg() { printf "\033[38;2;%s;%s;%sm" "$1" "$2" "$3"; }
bg() { printf "\033[48;2;%s;%s;%sm" "$1" "$2" "$3"; }

# Catppuccin Frappe palette (RGB)
crust_fg=$(fg 35 38 52)       # #232634
red_bg=$(bg 231 130 132)      # #e78284
peach_bg=$(bg 239 159 118)    # #ef9f76
yellow_bg=$(bg 229 200 144)   # #e5c890
green_bg=$(bg 166 209 137)    # #a6d189
sapphire_bg=$(bg 133 193 220) # #85c1dc
lavender_bg=$(bg 186 187 241) # #babbf1

# --- Build status line ---
output=""

# Segment 1: context (red)
if [ -n "$used_pct" ]; then
  output+="${red_bg}${crust_fg} ctx:${used_int}% ${reset}"
fi

# Segment 2: model (peach)
if [ -n "$model" ]; then
  output+="${peach_bg}${crust_fg} ${model} ${reset}"
fi

# Segment 3: directory (yellow)
output+="${yellow_bg}${crust_fg} ${short_path} ${reset}"

# Segment 4: git (green)
if [ -n "$git_branch" ]; then
  output+="${green_bg}${crust_fg}  ${git_branch}${git_status_str} ${reset}"
fi

# Segment 5: 5h limit (sapphire)
if [ -n "$five_hr_segment" ]; then
  output+="${sapphire_bg}${crust_fg} ${five_hr_segment} ${reset}"
fi

# Segment 6: weekly limit (lavender)
if [ -n "$seven_day_segment" ]; then
  output+="${lavender_bg}${crust_fg} ${seven_day_segment} ${reset}"
fi

printf "%b" "$output"
