#!/bin/bash
# Status line: cuenta de Claude con la que está iniciada la sesión.
# Formato: 👤 persona@empresa.com · Empresa
# Respeta CLAUDE_CONFIG_DIR (un perfil por directorio de configuración).

readonly DIM=$'\033[2m' CYAN=$'\033[36m' RESET=$'\033[0m'
# Controles y caracteres de formato invisibles (ESC, OSC, bidi…): nunca llegan al terminal.
readonly STRIP_CONTROLS='gsub("[\\p{Cc}\\p{Cf}\\x{2028}\\x{2029}]"; "")'

if ! command -v jq >/dev/null; then
  printf '👤 %sfalta jq%s\n' "$DIM" "$RESET"
  exit 0
fi

if [[ -n $CLAUDE_CONFIG_DIR ]]; then
  account_file="$CLAUDE_CONFIG_DIR/.claude.json"
else
  account_file="$HOME/.claude.json"
fi

account_field() {
  jq -r ".oauthAccount.$1 // empty | strings | $STRIP_CONTROLS" "$account_file" 2>/dev/null
}

email=$(account_field emailAddress)
org=$(account_field organizationName)

if [[ -z $email ]]; then
  printf '👤 %ssin sesión de claude.ai%s\n' "$DIM" "$RESET"
  exit 0
fi

# Las cuentas personales traen una organización que solo repite el email.
shopt -s nocasematch
[[ $org == *"$email"* ]] && org=
shopt -u nocasematch

printf '👤 %s%s%s' "$CYAN" "$email" "$RESET"
[[ -n $org ]] && printf ' %s· %s%s' "$DIM" "$org" "$RESET"
printf '\n'
