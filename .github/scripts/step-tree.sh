#!/usr/bin/env bash
# step-tree.sh — boxed, colorized step tree for GitHub Actions logs.
#
# Usage:
#   step_tree <job-title> <current-id> <spec> [statuses]
#
#   spec:      pipe-separated "id:Label" entries for every step in the job
#   statuses:  optional "id=outcome" pairs separated by ";" — build from the
#              steps context, e.g. "checkout=${{ steps.checkout.outcome }}"
#
# Markers:  ✓ success   ✗ failure   − skipped   → running   · pending

step_tree() {
  local job_title="$1"
  local current_id="$2"
  local spec="$3"
  local statuses="${4:-}"

  local -a ids=() labels=()
  local entry
  IFS='|' read -r -a entries <<<"$spec"
  for entry in "${entries[@]}"; do
    ids+=("${entry%%:*}")
    labels+=("${entry#*:}")
  done

  local title="🥊 ${job_title}"
  local width=0 len
  (( len = ${#title} + 6 ))
  (( width = len > width ? len : width ))
  for label in "${labels[@]}"; do
    (( len = ${#label} + 11 ))
    (( width = len > width ? len : width ))
  done

  local RESET=$'\033[0m' GREEN=$'\033[32m' RED=$'\033[31m' CYAN=$'\033[36m' DIM=$'\033[2m'

  local dash fill
  dash=$(printf '%*s' "$((width - ${#title} - 7))" '' | tr ' ' '─')
  printf '\n╭── %s %s╮\n' "$title" "$dash"

  local i=0 idx marker color out pair
  for label in "${labels[@]}"; do
    idx=$(printf '%2d' $((i + 1)))
    if [[ "${ids[$i]}" == "$current_id" ]]; then
      marker="→"
      color="$CYAN"
    else
      out=""
      if [[ -n "$statuses" ]]; then
        for pair in $(printf '%s' "$statuses" | tr ';' ' '); do
          [[ "${pair%%=*}" == "${ids[$i]}" ]] && out="${pair#*=}"
        done
      fi
      case "$out" in
        success) marker="✓" color="$GREEN" ;;
        failure) marker="✗" color="$RED" ;;
        skipped) marker="−" color="$DIM" ;;
        *) marker="·" color="$DIM" ;;
      esac
    fi
    fill=$(printf '%*s' "$((width - ${#label} - 9))" '')
    printf '│ %s %b %s%s %b│\n' "$idx" "$color$marker$RESET" "$label" "$fill" "$RESET"
    (( i += 1 ))
  done

  fill=$(printf '%*s' "$width" '' | tr ' ' '─')
  printf '╰%s╯\n\n' "$fill"
}