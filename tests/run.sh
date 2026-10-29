#!/bin/bash
# Suite ligera de tests (bash 3.2, solo requiere jq). Uso: tests/run.sh
# Todo ocurre en directorios temporales: HOME y CLAUDE_CONFIG_DIR apuntan allí,
# así que nunca se toca el ~/.claude ni el ~/.claude.json reales.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/statusline-tests.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"
unset CLAUDE_CONFIG_DIR

PASS=0 FAIL=0

ok()   { PASS=$((PASS + 1)); echo "  ok   $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL $1"; [[ -n ${2:-} ]] && echo "       $2"; }

assert_eq() { # nombre esperado actual
  if [[ $2 == "$3" ]]; then ok "$1"; else fail "$1" "esperado [$2] actual [$3]"; fi
}
assert_contains() { # nombre texto aguja
  if [[ $2 == *"$3"* ]]; then ok "$1"; else fail "$1" "no contiene [$3] en [$2]"; fi
}
assert_not_contains() {
  if [[ $2 != *"$3"* ]]; then ok "$1"; else fail "$1" "contiene [$3] en [$2]"; fi
}

new_dir() { local d="$SANDBOX/$1"; rm -rf "$d"; mkdir -p "$d"; printf '%s' "$d"; }
strip_ansi() { sed $'s/\033\\[[0-9;]*m//g'; }
# Comando que install.sh debe guardar para un directorio: ruta absoluta escapada con %q.
expected_cmd() { local c; printf -v c 'bash %q' "$(cd "$1" && pwd)/statusline-ps1.sh"; printf '%s' "$c"; }

# Ejecuta statusline-cuenta.sh con un .claude.json sintético y devuelve la salida sin colores.
run_cuenta() { # contenido_json
  local cfg; cfg=$(new_dir cuenta)
  [[ -n $1 ]] && printf '%s' "$1" > "$cfg/.claude.json"
  CLAUDE_CONFIG_DIR="$cfg" bash "$ROOT/scripts/statusline-cuenta.sh" </dev/null | strip_ansi
}

echo "statusline-cuenta.sh"
out=$(run_cuenta '{"oauthAccount":{"emailAddress":"ana@example.test","organizationName":"Acme Test"}}')
assert_eq "organización real se muestra" "👤 ana@example.test · Acme Test" "$out"

out=$(run_cuenta '{"oauthAccount":{"emailAddress":"ana@example.test","organizationName":"ana@example.test'"'"'s Organization"}}')
assert_eq "organización que repite el email se omite" "👤 ana@example.test" "$out"

out=$(run_cuenta '{"oauthAccount":{"emailAddress":"Ana@Example.Test","organizationName":"ANA@EXAMPLE.TEST org"}}')
assert_eq "repetición detectada sin distinguir mayúsculas" "👤 Ana@Example.Test" "$out"

out=$(run_cuenta '{"oauthAccount":{"emailAddress":"ana@example.test"}}')
assert_eq "sin organización solo muestra el email" "👤 ana@example.test" "$out"

out=$(run_cuenta '{"numStartups":3}')
assert_eq "sin oauthAccount: sin sesión" "👤 sin sesión de claude.ai" "$out"

out=$(run_cuenta '')
assert_eq "sin .claude.json: sin sesión" "👤 sin sesión de claude.ai" "$out"

out=$(run_cuenta 'esto no es json')
assert_eq "json corrupto: sin sesión" "👤 sin sesión de claude.ai" "$out"

# Sin CLAUDE_CONFIG_DIR se usa $HOME/.claude.json (HOME es temporal).
printf '%s' '{"oauthAccount":{"emailAddress":"home@example.test","organizationName":"Casa Test"}}' > "$HOME/.claude.json"
out=$(env -u CLAUDE_CONFIG_DIR bash "$ROOT/scripts/statusline-cuenta.sh" </dev/null | strip_ansi)
assert_eq "sin CLAUDE_CONFIG_DIR lee HOME/.claude.json" "👤 home@example.test · Casa Test" "$out"

# CLAUDE_CONFIG_DIR tiene prioridad sobre HOME.
out=$(run_cuenta '{"oauthAccount":{"emailAddress":"cfg@example.test"}}')
assert_eq "CLAUDE_CONFIG_DIR tiene prioridad sobre HOME" "👤 cfg@example.test" "$out"
rm -f "$HOME/.claude.json"

echo "install.sh"
dest=$(new_dir "con espacios/dir de config")
out=$(bash "$ROOT/install.sh" "$dest" 2>&1); rc=$?
assert_eq "instala en directorio con espacios (exit 0)" "0" "$rc"
for s in statusline-ps1.sh statusline-cuenta.sh; do
  if [[ -x "$dest/$s" ]]; then ok "$s copiado y ejecutable"; else fail "$s copiado y ejecutable"; fi
done
cmd=$(jq -r '.statusLine.command' "$dest/settings.json")
assert_eq "comando con ruta escapada" "$(expected_cmd "$dest")" "$cmd"
assert_eq "statusLine.type = command" "command" "$(jq -r '.statusLine.type' "$dest/settings.json")"

# El comando instalado se ejecuta tal cual lo haría Claude Code.
mkdir -p "$dest/proyecto"
echo '{"oauthAccount":{"emailAddress":"run@example.test","organizationName":"Run Test"}}' > "$dest/.claude.json"
out=$(printf '{"workspace":{"current_dir":"%s"}}' "$dest/proyecto" \
  | CLAUDE_CONFIG_DIR="$dest" bash -c "$cmd" | strip_ansi)
assert_contains "comando instalado: línea de prompt" "$out" "proyecto"
assert_contains "comando instalado: línea de cuenta" "$out" "👤 run@example.test · Run Test"
assert_eq "comando instalado: dos líneas" "2" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')"

# settings.json previo: conserva claves.
d=$(new_dir previo)
echo '{"theme":"dark","env":{"FOO":"bar"},"statusLine":{"type":"command","command":"viejo"}}' > "$d/settings.json"
bash "$ROOT/install.sh" "$d" >/dev/null 2>&1
assert_eq "conserva clave theme" "dark" "$(jq -r '.theme' "$d/settings.json")"
assert_eq "conserva clave anidada env.FOO" "bar" "$(jq -r '.env.FOO' "$d/settings.json")"
assert_contains "reemplaza statusLine previo" "$(jq -r '.statusLine.command' "$d/settings.json")" "statusline-ps1.sh"
assert_eq "copia de seguridad = original" \
  '{"theme":"dark","env":{"FOO":"bar"},"statusLine":{"type":"command","command":"viejo"}}' \
  "$(jq -c . "$d/settings.json.bak-statusline-claude")"

# Reinstalar no pisa la copia.
echo '{"theme":"light"}' > "$d/settings.json"
bash "$ROOT/install.sh" "$d" >/dev/null 2>&1
assert_eq "reinstalar no pisa la copia de seguridad" "dark" "$(jq -r '.theme' "$d/settings.json.bak-statusline-claude")"
assert_eq "reinstalar conserva el settings actual" "light" "$(jq -r '.theme' "$d/settings.json")"

# settings.json inexistente.
d=$(new_dir nuevo)
bash "$ROOT/install.sh" "$d" >/dev/null 2>&1; rc=$?
assert_eq "sin settings.json previo: exit 0" "0" "$rc"
assert_eq "sin settings.json previo: se crea con statusLine" "command" "$(jq -r '.statusLine.type' "$d/settings.json")"
assert_eq "sin settings.json previo: copia es {}" "{}" "$(jq -c . "$d/settings.json.bak-statusline-claude")"

# Varios directorios y barra final.
a=$(new_dir multi-a); b=$(new_dir multi-b)
bash "$ROOT/install.sh" "$a/" "$b" >/dev/null 2>&1
assert_eq "varios directorios: A" "command" "$(jq -r '.statusLine.type' "$a/settings.json")"
assert_eq "varios directorios: B" "command" "$(jq -r '.statusLine.type' "$b/settings.json")"
assert_eq "barra final normalizada" "$(expected_cmd "$a")" "$(jq -r '.statusLine.command' "$a/settings.json")"

# Sin argumentos usa CLAUDE_CONFIG_DIR.
d=$(new_dir envdir)
CLAUDE_CONFIG_DIR="$d" bash "$ROOT/install.sh" >/dev/null 2>&1
assert_eq "sin argumentos usa CLAUDE_CONFIG_DIR" "command" "$(jq -r '.statusLine.type' "$d/settings.json")"

# Sin argumentos ni variable usa HOME/.claude (HOME temporal).
env -u CLAUDE_CONFIG_DIR bash "$ROOT/install.sh" >/dev/null 2>&1
assert_eq "sin variable usa HOME/.claude" "command" "$(jq -r '.statusLine.type' "$HOME/.claude/settings.json")"

# Falta jq: PATH con solo dirname y sin jq.
nojq=$(new_dir nojq-bin)
ln -s "$(command -v dirname)" "$nojq/dirname"
d="$SANDBOX/sin-jq-destino"
out=$(PATH="$nojq" /bin/bash "$ROOT/install.sh" "$d" 2>&1); rc=$?
assert_eq "sin jq: exit 1" "1" "$rc"
assert_contains "sin jq: mensaje claro" "$out" "Falta jq"
if [[ ! -e $d ]]; then ok "sin jq: no crea nada"; else fail "sin jq: no crea nada"; fi

echo "seguridad y robustez"
# Ruta relativa: se guarda absoluta y funciona desde otra carpeta.
rel_parent=$(new_dir relativa)
(cd "$rel_parent" && bash "$ROOT/install.sh" cfg >/dev/null 2>&1)
cmd=$(jq -r '.statusLine.command' "$rel_parent/cfg/settings.json")
assert_eq "ruta relativa se guarda absoluta" "$(expected_cmd "$rel_parent/cfg")" "$cmd"
out=$(cd "$SANDBOX" && echo '{}' | bash -c "$cmd" 2>&1 | strip_ansi); rc=$?
assert_eq "ruta relativa: el comando funciona desde otra carpeta" "0" "$rc"
assert_contains "ruta relativa: muestra la línea de cuenta" "$out" "👤"

# Ruta con comillas, $ y comillas invertidas: el comando no ejecuta nada ni se rompe.
weird=$(new_dir 'raro"$(touch PWNED)`touch PWNED2`')
(cd "$SANDBOX" && bash "$ROOT/install.sh" "$weird" >/dev/null 2>&1)
cmd=$(jq -r '.statusLine.command' "$weird/settings.json")
out=$(cd "$SANDBOX" && echo '{}' | sh -c "$cmd" 2>&1 | strip_ansi); rc=$?
assert_eq "ruta con caracteres especiales: el comando funciona" "0" "$rc"
if [[ ! -e $SANDBOX/PWNED && ! -e $SANDBOX/PWNED2 ]]; then ok "ruta con caracteres especiales: no ejecuta código"; else fail "ruta con caracteres especiales: no ejecuta código"; fi

# settings.json creado por el instalador: solo legible por su dueño.
d=$(new_dir permisos)
bash "$ROOT/install.sh" "$d" >/dev/null 2>&1
assert_eq "settings.json nuevo con permisos 600" "600" "$(stat -f '%Lp' "$d/settings.json" 2>/dev/null || stat -c '%a' "$d/settings.json")"

# Secuencias de escape en email y organización no llegan al terminal.
out=$(run_cuenta '{"oauthAccount":{"emailAddress":"e\u001b]52;c;eA==\u0007v@example.test","organizationName":"Org\u001b]0;TITULO\u0007\u009b31m\u202eX\nY"}}')
assert_eq "controles eliminados de email y organización" "👤 e]52;c;eA==v@example.test · Org]0;TITULO31mXY" "$out"
raw=$(CLAUDE_CONFIG_DIR="$SANDBOX/cuenta" bash "$ROOT/scripts/statusline-cuenta.sh" </dev/null | strip_ansi)
assert_not_contains "sin ESC tras quitar colores" "$raw" $'\033'

# Directorio con ESC en el nombre no llega al terminal.
esc_dir="$SANDBOX/dir"$'\033'"]0;X"$'\007'"fin"
mkdir -p "$esc_dir"
out=$(jq -n --arg d "$esc_dir" '{workspace:{current_dir:$d}}' | bash "$ROOT/scripts/statusline-ps1.sh" | strip_ansi | head -1)
assert_not_contains "directorio con ESC: sin ESC" "$out" $'\033'
assert_not_contains "directorio con ESC: sin BEL" "$out" $'\007'

# C1 (CSI de 8 bits) y bidi en directorio y rama: se eliminan sin romper el UTF-8.
c1_dir="$SANDBOX/c1"$'\xc2\x9b'"31m"$'\xe2\x80\xae'"ñandú"
mkdir -p "$c1_dir"
git -C "$c1_dir" init -q -b "rama"$'\xc2\x9b'"31m"$'\xe2\x80\xae'"x" 2>/dev/null
out=$(jq -n --arg d "$c1_dir" '{workspace:{current_dir:$d}}' | bash "$ROOT/scripts/statusline-ps1.sh" | strip_ansi | head -1)
assert_not_contains "directorio y rama sin CSI de 8 bits" "$out" $'\xc2\x9b'
assert_not_contains "directorio y rama sin bidi" "$out" $'\xe2\x80\xae'
assert_contains "directorio conserva el UTF-8 válido" "$out" "c131mñandú"
assert_contains "rama limpia" "$out" "(rama31mx)"

# Abreviatura ~ solo en el límite de carpeta.
first_line() { jq -n --arg d "$1" '{workspace:{current_dir:$d}}' | bash "$ROOT/scripts/statusline-ps1.sh" | strip_ansi | head -1; }
assert_contains "HOME exacto se muestra como ~" "$(first_line "$HOME")" " ~"
assert_contains "subcarpeta de HOME con ~/" "$(first_line "$HOME/p")" " ~/p"
assert_contains "carpeta hermana de HOME sin abreviar" "$(first_line "${HOME}extra/x")" " ${HOME}extra/x"

# Sin jq al ejecutar la statusLine: lo dice en vez de «sin sesión».
out=$(PATH="$nojq" /bin/bash "$ROOT/scripts/statusline-cuenta.sh" </dev/null | strip_ansi)
assert_eq "sin jq en ejecución: avisa" "👤 falta jq" "$out"

echo
echo "Resultado: $PASS ok, $FAIL fallos"
((FAIL == 0))
