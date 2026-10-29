# Registro de cambios

El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/).

## Sin publicar

### Añadido

- StatusLine de Claude Code en dos líneas: el prompt (usuario, máquina, directorio y rama) y la cuenta de claude.ai de la sesión, con soporte para varios perfiles mediante `CLAUDE_CONFIG_DIR`.
- Instalador `install.sh` para uno o varios directorios de configuración, con copia previa de `settings.json`.
- Suite de tests ejecutable con `bash tests/run.sh`.
- Licencia MIT.

### Seguridad

- El comando guardado en `settings.json` usa la ruta absoluta y escapada del script: funciona con rutas relativas y no ejecuta nada si la ruta lleva comillas, `$` o comillas invertidas.
- Se eliminan los caracteres de control de email, organización, directorio y rama antes de pintarlos.
- `settings.json` se crea con permisos 600 si no existía.
