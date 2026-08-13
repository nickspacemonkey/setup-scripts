#!/usr/bin/env bash

input=$(cat)

# Claude/session information
MODEL=$(jq -r '.model.display_name // .model.id // "unknown"' <<< "$input")
DIR=$(jq -r '.workspace.current_dir // .cwd // "."' <<< "$input")

# Context information
USED=$(jq -r '.context_window.total_input_tokens // 0' <<< "$input")
MAX=$(jq -r '.context_window.context_window_size // 0' <<< "$input")
PCT=$(jq -r '.context_window.used_percentage // 0 | floor' <<< "$input")
REMAINING=$(jq -r '.context_window.remaining_percentage // 100 | floor' <<< "$input")

# Optional manual context-size override.
# Example: export CLAUDE_CONTEXT_MAX=131072
export CLAUDE_CONTEXT_MAX=131072
if [[ -n "${CLAUDE_CONTEXT_MAX:-}" ]]; then
    MAX="$CLAUDE_CONTEXT_MAX"

    if (( MAX > 0 )); then
        PCT=$(( USED * 100 / MAX ))
        REMAINING=$(( 100 - PCT ))
    fi
fi

# Human-readable token count
format_tokens() {
    local n="$1"

    if (( n >= 1000000 )); then
        awk -v n="$n" 'BEGIN { printf "%.1fM", n / 1000000 }'
    elif (( n >= 1000 )); then
        awk -v n="$n" 'BEGIN { printf "%.1fK", n / 1000 }'
    else
        printf "%d" "$n"
    fi
}

USED_H=$(format_tokens "$USED")
MAX_H=$(format_tokens "$MAX")

# 20-character progress bar
BAR_WIDTH=20
FILLED=$(( PCT * BAR_WIDTH / 100 ))

(( FILLED > BAR_WIDTH )) && FILLED=$BAR_WIDTH
(( FILLED < 0 )) && FILLED=0

EMPTY=$(( BAR_WIDTH - FILLED ))

BAR=""
(( FILLED > 0 )) && printf -v FILL "%${FILLED}s" && BAR="${FILL// /█}"
(( EMPTY > 0 )) && printf -v PAD "%${EMPTY}s" && BAR="${BAR}${PAD// /░}"

# Colour based on context usage
RESET='\033[0m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
CYAN='\033[36m'
MAGENTA='\033[35m'

if (( PCT >= 80 )); then
    BAR_COLOR="$RED"
elif (( PCT >= 60 )); then
    BAR_COLOR="$YELLOW"
else
    BAR_COLOR="$GREEN"
fi

# Git information
GIT_INFO=""

if git -C "$DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    BRANCH=$(git -C "$DIR" branch --show-current 2>/dev/null)

    # Handles detached HEAD
    if [[ -z "$BRANCH" ]]; then
        BRANCH=$(git -C "$DIR" rev-parse --short HEAD 2>/dev/null)
    fi

    if [[ -n "$(git -C "$DIR" status --porcelain 2>/dev/null)" ]]; then
        GIT_INFO=" | ${MAGENTA}git:${BRANCH} *${RESET}"
    else
        GIT_INFO=" | ${MAGENTA}git:${BRANCH}${RESET}"
    fi
fi

printf "%b%s%b | %b%s%b %s %d%% used | %d%% left%b\n" \
    "$CYAN" "$MODEL" "$RESET" \
    "$BAR_COLOR" "$BAR" "$RESET" \
    "$USED_H/$MAX_H" \
    "$PCT" \
    "$REMAINING" \
    "$GIT_INFO"
