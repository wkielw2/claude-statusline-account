#!/bin/bash
# Status line: estilo prompt (usuario@host dir (rama)) + cuenta de Claude.
# Línea 1: equivalente al prompt de la shell. Línea 2: salida de statusline-cuenta.sh.

readonly GREEN=$'\033[32m' BLUE=$'\033[34m' YELLOW=$'\033[33m' RESET=$'\033[0m'

input=$(cat)
dir=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // empty' 2>/dev/null)
[[ -z $dir ]] && dir=$PWD

case $dir in
  "$HOME") shown='~' ;;
  "$HOME"/*) shown="~${dir#"$HOME"}" ;;
  *) shown=$dir ;;
esac
# Quita controles y caracteres de formato invisibles (ESC, CSI de 8 bits, bidi…) antes de pintar.
# Sin jq, al menos los controles C0 y DEL.
strip_controls() {
  jq -rn --arg s "$1" '$s | gsub("[\\p{Cc}\\p{Cf}\\x{2028}\\x{2029}]"; "")' 2>/dev/null ||
    printf '%s' "$1" | LC_ALL=C tr -d '\000-\037\177'
}

# Un nombre de carpeta o de rama de un repo clonado no debe colar secuencias de escape.
shown=$(strip_controls "$shown")
branch=$(git -C "$dir" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
[[ -n $branch ]] && branch=$(strip_controls "$branch")

printf '%s%s@%s%s %s%s%s' "$GREEN" "${USER:-$(id -un)}" "${HOSTNAME%%.*}" "$RESET" "$BLUE" "$shown" "$RESET"
[[ -n $branch ]] && printf ' %s(%s)%s' "$YELLOW" "$branch" "$RESET"
printf '\n'

"$(dirname "$0")/statusline-cuenta.sh" <<< "$input"
