#!/bin/bash
# Instala la statusLine (prompt + cuenta de Claude) en uno o varios directorios de configuración.
# Uso: ./install.sh [dir...]   Sin argumentos: $CLAUDE_CONFIG_DIR o ~/.claude.
set -euo pipefail

SOURCE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/scripts" && pwd)
readonly SOURCE_DIR
readonly SCRIPTS=(statusline-ps1.sh statusline-cuenta.sh)

if ! command -v jq >/dev/null; then
  echo "Falta jq (brew install jq)." >&2
  exit 1
fi

install_into() {
  local dir=$1
  mkdir -p "$dir"
  # Claude Code ejecuta el comando desde la carpeta del proyecto: la ruta guardada debe ser absoluta.
  dir=$(CDPATH= cd -- "$dir" && pwd)
  local settings="$dir/settings.json"

  for script in "${SCRIPTS[@]}"; do
    install -m 755 "$SOURCE_DIR/$script" "$dir/$script"
  done

  # settings.json puede guardar secretos (env): si lo creamos, solo legible por su dueño.
  [[ -f $settings ]] || (umask 077 && echo '{}' > "$settings")
  [[ -f $settings.bak-statusline-claude ]] || cp -p "$settings" "$settings.bak-statusline-claude"

  # %q escapa la ruta para la shell que ejecuta el comando (espacios, comillas, $, `).
  local cmd updated
  printf -v cmd 'bash %q' "$dir/statusline-ps1.sh"
  updated=$(jq --arg cmd "$cmd" '.statusLine = {type: "command", command: $cmd}' "$settings")
  printf '%s\n' "$updated" > "$settings"

  echo "✔ $dir (copia previa: settings.json.bak-statusline-claude)"
}

if (($# == 0)); then
  set -- "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
fi

for dir in "$@"; do
  install_into "$dir"
done
