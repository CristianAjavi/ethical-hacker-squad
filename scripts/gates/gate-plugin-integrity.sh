#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-plugin-integrity.sh — integridad del contenido que se sirve al usuario.
#
# POR QUE EXISTE
#   Todo lo que aterriza en skills/ se copia al cache de plugins de CADA usuario
#   en su siguiente arranque de sesion, sin accion humana. Un PR del loop de
#   conocimiento (bot/knowledge-*) que modifique ese arbol es, por construccion,
#   un canal de inyeccion indirecta de prompts hacia todos los instalados.
#   Este gate no juzga el CONTENIDO (eso no es determinista): acota la FORMA,
#   que si lo es — frontmatter, enlaces, tipos de archivo y tamano.
#
# QUE MIDE
#   1. Frontmatter de cada SKILL.md: delimitadores, claves permitidas, nombre
#      que coincide con el directorio, descripcion no vacia.
#   2. Que ningun SKILL.md se auto-conceda herramientas por frontmatter.
#   3. Que todo enlace relativo interno del repo resuelva a un archivo real.
#   4. Presupuesto de tamano y de forma del arbol servido al usuario.
#
# EXIT CODES (contrato del repo: un rc=0 nunca significa "no lo revise")
#   0 = MEDI y esta bien
#   1 = MEDI y FALLA
#   2 = NO PUDE MEDIR (falta herramienta o falta entrada)
#
# VARIABLES DE ENTORNO
#   EHS_REPO_ROOT                 raiz del repo
#   EHS_ALLOW_TOOLS_FRONTMATTER=1 permite 'allowed-tools' en el frontmatter
#                                 (decision explicita de un humano, no del bot)
#   EHS_MAX_SKILL_MD_BYTES        default 12288
#   EHS_MAX_REF_BYTES             default 32768
#   EHS_MAX_TREE_BYTES            default 262144
#   EHS_MAX_TREE_FILES            default 64
# ---------------------------------------------------------------------------
set -uo pipefail

# --- PRESUPUESTO DE TAMANO: umbrales y por que estos numeros ---------------
#
# SKILL.md (12 KiB ~= 3.000 tokens)
#   SKILL.md se carga entero en contexto CADA vez que la skill se dispara; su
#   coste no es opcional ni amortizable. El archivo actual pesa ~8,7 KiB, asi que
#   12 KiB deja ~40% de margen para crecer sin que el umbral estorbe, y frena el
#   patron real de degradacion: una skill que engorda commit a commit hasta que
#   el modelo deja de leerla con atencion. Si un cambio necesita mas de 12 KiB,
#   la respuesta correcta es mover ese texto a references/ (carga bajo demanda),
#   no subir el umbral.
#
# Cada archivo de references/ (32 KiB ~= 8.000 tokens)
#   Se cargan uno a uno y bajo demanda, asi que toleran mas. 32 KiB sigue siendo
#   una lectura de una sola pasada; por encima de eso el archivo deberia partirse
#   para que el modelo no tenga que tragarse material irrelevante.
#
# Arbol completo servido al usuario (256 KiB) y numero de archivos (64)
#   Este es el umbral de SEGURIDAD, no de ergonomia: acota el radio de explosion
#   del loop de conocimiento. Con el corpus actual en ~17 KiB, 256 KiB da mucho
#   margen legitimo y a la vez convierte "un PR de bot mete 3 MB de texto scrapeado
#   de internet en lo que se instala a todos" en un fallo de CI, no en un release.
#   Los umbrales son deliberadamente holgados: si alguno se toca de verdad, es una
#   senal que merece revision humana, no un ajuste automatico.
MAX_SKILL_MD_BYTES="${EHS_MAX_SKILL_MD_BYTES:-12288}"
MAX_REF_BYTES="${EHS_MAX_REF_BYTES:-32768}"
MAX_TREE_BYTES="${EHS_MAX_TREE_BYTES:-262144}"
MAX_TREE_FILES="${EHS_MAX_TREE_FILES:-64}"

# Claves toleradas en el frontmatter de SKILL.md. Todo lo demas se rechaza:
# una clave desconocida en un archivo que se distribuye a terceros es material
# no auditado con semantica potencialmente ejecutable.
ALLOWED_FM_KEYS="name description license metadata"
# Extensiones toleradas dentro de skills/. Solo texto: el arbol servido al
# usuario no tiene por que contener nada ejecutable ni binario.
ALLOWED_EXTENSIONS="md"

FAILURES=0
N_CHECKED=0
SKIPPED=()

ok()      { printf '  [OK]   %s\n' "$*"; N_CHECKED=$((N_CHECKED + 1)); }
fail()    { printf '  [FAIL] %s\n' "$*" >&2; N_CHECKED=$((N_CHECKED + 1)); FAILURES=$((FAILURES + 1)); }
skip()    { printf '  [SKIP] %s\n' "$*"; SKIPPED+=("$*"); }
info()    { printf '         %s\n' "$*"; }
section() { printf '\n== %s\n' "$*"; }

unmeasurable() {
  printf '\n[NO PUDE MEDIR] %s\n' "$*" >&2
  printf 'gate-plugin-integrity: rc=2 (no es un pase; es ausencia de medicion)\n' >&2
  exit 2
}

fsize() { wc -c <"$1" | tr -d ' '; }

# --- 0. herramientas -------------------------------------------------------
section "herramientas"
for tool in grep sed awk find wc sort; do
  command -v "$tool" >/dev/null 2>&1 || unmeasurable "falta la herramienta '$tool'"
done
ok "utilidades POSIX disponibles"

# --- 1. raiz ---------------------------------------------------------------
if [[ -n "${EHS_REPO_ROOT:-}" ]]; then
  ROOT="$EHS_REPO_ROOT"
elif ROOT=$(git rev-parse --show-toplevel 2>/dev/null); then
  :
else
  ROOT="$PWD"
fi
[[ -d "$ROOT/skills" ]] || unmeasurable \
  "no encuentro skills/ bajo '$ROOT' (¿cwd equivocado? esto no es el repo del plugin)"
info "raiz: $ROOT"

# --- 2. frontmatter de cada SKILL.md ---------------------------------------
section "frontmatter de SKILL.md"
# NOTA de portabilidad: nada de `mapfile` — macOS trae bash 3.2 y no lo tiene.
SKILL_FILES=()
while IFS= read -r _f; do SKILL_FILES+=("$_f"); done < <(find "$ROOT/skills" -type f -name 'SKILL.md' | sort)
if ((${#SKILL_FILES[@]} == 0)); then
  unmeasurable "no hay ningun SKILL.md bajo skills/ — nada que validar (arbol incompleto)"
fi

for sf in "${SKILL_FILES[@]}"; do
  rel="${sf#"$ROOT"/}"
  dirname_of_skill=$(basename "$(dirname "$sf")")

  if [[ ! -s "$sf" ]]; then
    fail "$rel esta vacio"
    continue
  fi

  first_line=$(head -n 1 "$sf")
  if [[ "$first_line" != "---" ]]; then
    fail "$rel no empieza con el delimitador '---' (frontmatter ausente o corrupto)"
    continue
  fi

  # Linea del delimitador de cierre (primer '---' a partir de la 2).
  close_line=$(awk 'NR>1 && $0=="---" {print NR; exit}' "$sf")
  if [[ -z "$close_line" ]]; then
    fail "$rel abre frontmatter pero nunca lo cierra con '---'"
    continue
  fi
  ok "$rel: frontmatter delimitado (lineas 1..$close_line)"

  fm=$(sed -n "2,$((close_line - 1))p" "$sf")

  # Claves de primer nivel (sin indentar).
  fm_keys=$(printf '%s\n' "$fm" | grep -E '^[A-Za-z_][A-Za-z0-9_-]*:' | sed 's/:.*//' | sort -u)

  bad_keys=""
  while IFS= read -r k; do
    [[ -n "$k" ]] || continue
    case " $ALLOWED_FM_KEYS " in
      *" $k "*) ;;
      *)
        if [[ "$k" == "allowed-tools" && "${EHS_ALLOW_TOOLS_FRONTMATTER:-0}" == "1" ]]; then
          skip "$rel declara 'allowed-tools' y EHS_ALLOW_TOOLS_FRONTMATTER=1 lo permite (decision humana explicita)"
        else
          bad_keys+="$k "
        fi
        ;;
    esac
  done <<<"$fm_keys"

  if [[ -n "$bad_keys" ]]; then
    fail "$rel: clave(s) de frontmatter no permitida(s): $bad_keys"
    info "permitidas: $ALLOWED_FM_KEYS"
    [[ "$bad_keys" == *"allowed-tools"* ]] && \
      info "'allowed-tools' concede herramientas a la skill: no puede entrar por un PR automatico. Exportar EHS_ALLOW_TOOLS_FRONTMATTER=1 solo tras revision humana."
  else
    ok "$rel: solo claves permitidas en el frontmatter"
  fi

  fm_name=$(printf '%s\n' "$fm" | sed -n 's/^name:[[:space:]]*//p' | head -n 1 | sed 's/[[:space:]]*$//' | tr -d '"'"'")
  fm_desc=$(printf '%s\n' "$fm" | sed -n 's/^description:[[:space:]]*//p' | head -n 1 | sed 's/[[:space:]]*$//')

  if [[ -z "$fm_name" ]]; then
    fail "$rel: falta 'name' en el frontmatter (campo obligatorio)"
  elif [[ ! "$fm_name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    fail "$rel: name='$fm_name' no cumple ^[a-z0-9]+(-[a-z0-9]+)*$"
  elif [[ "$fm_name" != "$dirname_of_skill" ]]; then
    fail "$rel: name='$fm_name' no coincide con el directorio '$dirname_of_skill' (la skill no se resolveria)"
  else
    ok "$rel: name='$fm_name' valido y coincide con su directorio"
  fi

  if [[ -z "$fm_desc" ]]; then
    fail "$rel: falta 'description' o esta vacia (sin ella la skill nunca se dispara)"
  elif [[ ${#fm_desc} -gt 1024 ]]; then
    fail "$rel: description de ${#fm_desc} caracteres (limite de este repo: 1024)"
  else
    ok "$rel: description presente (${#fm_desc} caracteres)"
  fi
done

# --- 3. enlaces relativos internos ------------------------------------------
section "enlaces relativos internos"
MD_FILES=()
if command -v git >/dev/null 2>&1 && git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  while IFS= read -r _f; do MD_FILES+=("$_f"); done < <(git -C "$ROOT" ls-files '*.md' | sed "s|^|$ROOT/|" | sort)
  info "conjunto: archivos .md rastreados por git"
else
  while IFS= read -r _f; do MD_FILES+=("$_f"); done < <(find "$ROOT" -type f -name '*.md' -not -path '*/.git/*' | sort)
  skip "no es un repo git: uso find en vez de 'git ls-files' (puede incluir .md no versionados)"
fi

if ((${#MD_FILES[@]} == 0)); then
  unmeasurable "no encontre ningun archivo .md que analizar"
fi

BROKEN=0
LINKS_SEEN=0
for md in "${MD_FILES[@]}"; do
  [[ -f "$md" ]] || continue
  mdrel="${md#"$ROOT"/}"
  mddir=$(dirname "$md")

  # Enlaces inline ](destino) + definiciones de referencia [id]: destino
  {
    grep -oE '\]\([^)]+\)' "$md" 2>/dev/null | sed -E 's/^\]\(//; s/\)$//'
    grep -oE '^\[[^]]+\]:[[:space:]]*[^[:space:]]+' "$md" 2>/dev/null | sed -E 's/^\[[^]]+\]:[[:space:]]*//'
  } | while IFS= read -r target; do
    [[ -n "$target" ]] || continue
    # quitar titulo:  ruta.md "Titulo"
    target="${target%%[[:space:]]\"*}"
    target="${target%%[[:space:]]\'*}"
    # descartar externos, anclas, plantillas
    case "$target" in
      http://*|https://*|mailto:*|tel:*|ftp://*|data:*|\#*|\<*|'$'*|'{'*|'%7B'*) continue ;;
    esac
    # quitar ancla y query
    target="${target%%#*}"
    target="${target%%\?*}"
    [[ -n "$target" ]] || continue
    # decodificar el unico escape realista en rutas de repo
    target="${target//%20/ }"

    if [[ "$target" == /* ]]; then
      resolved="$ROOT$target"   # absoluto = relativo a la raiz del repo
    else
      resolved="$mddir/$target"
    fi

    if [[ -e "$resolved" ]]; then
      printf 'OK\n'
    else
      printf 'BROKEN\t%s\t%s\n' "$mdrel" "$target"
    fi
  done
done >/tmp/ehs-links.$$ 2>/dev/null

LINKS_SEEN=$(wc -l </tmp/ehs-links.$$ | tr -d ' ')
BROKEN=$(grep -c '^BROKEN' /tmp/ehs-links.$$ 2>/dev/null || true)
BROKEN=${BROKEN:-0}
if (( BROKEN > 0 )); then
  fail "$BROKEN enlace(s) relativo(s) apuntan a archivos inexistentes"
  grep '^BROKEN' /tmp/ehs-links.$$ | awk -F'\t' '{printf "         | %s -> %s\n", $2, $3}' >&2
else
  ok "los $LINKS_SEEN enlace(s) relativo(s) internos resuelven a archivos existentes"
fi
rm -f /tmp/ehs-links.$$ 2>/dev/null || true

# --- 4. forma del arbol servido al usuario ---------------------------------
section "forma del arbol skills/"
TREE_FILES=()
TREE_LINKS=()
while IFS= read -r _f; do TREE_FILES+=("$_f"); done < <(find "$ROOT/skills" -type f | sort)
while IFS= read -r _f; do [[ -n "$_f" ]] && TREE_LINKS+=("$_f"); done < <(find "$ROOT/skills" -type l | sort)

if ((${#TREE_LINKS[@]} > 0)); then
  fail "${#TREE_LINKS[@]} symlink(s) dentro de skills/ (pueden apuntar fuera del arbol distribuido)"
  for l in "${TREE_LINKS[@]}"; do info "| ${l#"$ROOT"/}"; done
else
  ok "sin symlinks dentro de skills/"
fi

bad_ext=""
exec_bits=""
for f in "${TREE_FILES[@]}"; do
  rel="${f#"$ROOT"/}"
  ext="${f##*.}"
  case " $ALLOWED_EXTENSIONS " in
    *" $ext "*) ;;
    *) bad_ext+="$rel " ;;
  esac
  [[ -x "$f" ]] && exec_bits+="$rel "
done
if [[ -n "$bad_ext" ]]; then
  fail "archivo(s) con extension no permitida en skills/ (permitidas: $ALLOWED_EXTENSIONS): $bad_ext"
else
  ok "todos los archivos de skills/ son .md (nada ejecutable ni binario se distribuye)"
fi
if [[ -n "$exec_bits" ]]; then
  fail "archivo(s) con bit de ejecucion en skills/: $exec_bits"
else
  ok "ningun archivo de skills/ tiene bit de ejecucion"
fi

# --- 5. presupuesto de tamano ----------------------------------------------
section "presupuesto de tamano"
for sf in "${SKILL_FILES[@]}"; do
  rel="${sf#"$ROOT"/}"
  sz=$(fsize "$sf")
  if (( sz > MAX_SKILL_MD_BYTES )); then
    fail "$rel pesa $sz B > $MAX_SKILL_MD_BYTES B (se carga entero en cada disparo; mover texto a references/)"
  else
    ok "$rel: $sz B / $MAX_SKILL_MD_BYTES B"
  fi
done

REF_OVER=0
for f in "${TREE_FILES[@]}"; do
  [[ "$(basename "$f")" == "SKILL.md" ]] && continue
  sz=$(fsize "$f")
  if (( sz > MAX_REF_BYTES )); then
    fail "${f#"$ROOT"/} pesa $sz B > $MAX_REF_BYTES B (partir el archivo)"
    REF_OVER=$((REF_OVER + 1))
  fi
done
(( REF_OVER == 0 )) && ok "ningun archivo de referencia supera $MAX_REF_BYTES B"

TREE_BYTES=0
for f in "${TREE_FILES[@]}"; do TREE_BYTES=$((TREE_BYTES + $(fsize "$f"))); done
if (( TREE_BYTES > MAX_TREE_BYTES )); then
  fail "skills/ pesa $TREE_BYTES B > $MAX_TREE_BYTES B (limite de radio de explosion del corpus)"
else
  ok "skills/ pesa $TREE_BYTES B / $MAX_TREE_BYTES B"
fi
if (( ${#TREE_FILES[@]} > MAX_TREE_FILES )); then
  fail "skills/ tiene ${#TREE_FILES[@]} archivos > $MAX_TREE_FILES"
else
  ok "skills/ tiene ${#TREE_FILES[@]} archivo(s) / $MAX_TREE_FILES"
fi

# --- resumen ---------------------------------------------------------------
section "resumen"
printf '  revisado: %d comprobacion(es) sobre %d SKILL.md y %d archivo(s) .md\n' \
  "$N_CHECKED" "${#SKILL_FILES[@]}" "${#MD_FILES[@]}"
printf '  NO revisado (fuera de alcance por diseno): el CONTENIDO semantico de los .md;\n'
printf '    este gate acota forma, enlaces, tipos y tamano, no juzga texto.\n'
if ((${#SKIPPED[@]} > 0)); then
  printf '  omitido en esta ejecucion: %d\n' "${#SKIPPED[@]}"
  for s in "${SKIPPED[@]}"; do printf '    - %s\n' "$s"; done
fi

if (( FAILURES > 0 )); then
  printf '\ngate-plugin-integrity: rc=1 — %d fallo(s) MEDIDO(s)\n' "$FAILURES" >&2
  exit 1
fi
printf '\ngate-plugin-integrity: rc=0 — medido y correcto\n'
exit 0
