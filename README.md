# statusline-claude

StatusLine de Claude Code en dos líneas, debajo del prompt:

```
usuario@host ~/proyecto (rama)
👤 persona@empresa.com · Empresa
```

- **Línea 1:** usuario, máquina, directorio y rama de git (si la hay).
- **Línea 2:** la cuenta de claude.ai con la que está iniciada la sesión, leída de `oauthAccount` en `.claude.json` (solo email y organización). La organización se omite si solo repite el email, como en las cuentas personales. Sin sesión de claude.ai muestra «sin sesión de claude.ai».

Respeta `CLAUDE_CONFIG_DIR`, así que cada perfil (por ejemplo, uno personal y otro del trabajo) muestra su propia cuenta.

## Requisitos

- `bash`, `git` y [`jq`](https://jqlang.org/) (`brew install jq`).

## Instalar

```bash
git clone https://github.com/wkielw2/claude-statusline-account.git
cd claude-statusline-account
./install.sh
```

Sin argumentos instala en `$CLAUDE_CONFIG_DIR` o, si no está definida, en `~/.claude`. Para varios perfiles, pasa sus directorios:

```bash
./install.sh ~/.claude-personal ~/.claude-trabajo
```

En cada directorio, el instalador:

1. Copia `statusline-ps1.sh` y `statusline-cuenta.sh` con permiso de ejecución.
2. Pone `statusLine` en `settings.json` y conserva el resto de ajustes. Si no existe, lo crea legible solo por ti (600). El comando guarda la ruta absoluta del script, aunque pases una relativa.
3. La primera vez, guarda el `settings.json` original en `settings.json.bak-statusline-claude` (las reinstalaciones no lo pisan).

Reinstalar es seguro: sobrescribe los scripts y vuelve a fijar la misma `statusLine`. La statusLine se refresca sola; no hace falta reiniciar Claude Code.

## Desinstalar

Quita la clave `statusLine` de `settings.json` (`jq 'del(.statusLine)'`) y borra los dos scripts. También puedes restaurar `settings.json.bak-statusline-claude`, pero perderás los cambios que hicieras en `settings.json` después de instalar.

## Tests

```bash
bash tests/run.sh
```

Necesita `jq`. Ejecuta los tests en un directorio temporal (`HOME` y `CLAUDE_CONFIG_DIR` apuntan allí), así que no toca tu `~/.claude` ni tu `~/.claude.json`. Termina con el resumen `Resultado: N ok, M fallos`.

## Seguridad

- Del `.claude.json` solo se leen `oauthAccount.emailAddress` y `oauthAccount.organizationName`; nada sale de tu equipo.
- Se eliminan los caracteres de control del email, la organización, el directorio y la rama antes de pintarlos, para que no lleguen secuencias de escape al terminal.
- Si Claude Code no encuentra `jq` al pintar la statusLine, la segunda línea dice «falta jq».

## Licencia

[MIT](LICENSE).
