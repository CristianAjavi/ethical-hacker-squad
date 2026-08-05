#!/usr/bin/env bash
# scripts/gates/lib/bootstrap-actions-lint.sh
#
# Deja disponibles zizmor y actionlint EN VERSIONES FIJAS, con la misma receta
# en local (macOS, sin sudo, sin brew) y en CI (ubuntu-latest). Se hace `source`.
#
# Define: ZIZMOR_BIN, ACTIONLINT_BIN  (vacios si no se pudo instalar).
# Devuelve 0 si la herramienta quedo lista, 2 si NO se pudo (nunca 0 a ciegas).
#
# Cache: $GATE_TOOLS_DIR (por defecto, fuera del repo, para no ensuciar el
# arbol de trabajo ni obligar a tocar .gitignore).
#
# El tarball de actionlint se verifica contra un SHA-256 FIJADO en este fichero:
# es el equivalente, para un binario, al pin por SHA que exigimos a las acciones.

# shellcheck shell=bash

ZIZMOR_VERSION="${ZIZMOR_VERSION:-1.29.0}"
ACTIONLINT_VERSION="${ACTIONLINT_VERSION:-1.7.12}"
GATE_TOOLS_DIR="${GATE_TOOLS_DIR:-${TMPDIR:-/tmp}/ehs-gate-tools}"

# SHA-256 de los tarballs oficiales de actionlint v1.7.12
# (fuente: actionlint_1.7.12_checksums.txt de la release de rhysd/actionlint,
#  descargado y verificado el 2026-08-04 contra el tarball darwin_arm64).
_ACTIONLINT_SHA_1_7_12_darwin_arm64="aba9ced2dee8d27fecca3dc7feb1a7f9a52caefa1eb46f3271ea66b6e0e6953f"
_ACTIONLINT_SHA_1_7_12_darwin_amd64="5b44c3bc2255115c9b69e30efc0fecdf498fdb63c5d58e17084fd5f16324c644"
_ACTIONLINT_SHA_1_7_12_linux_amd64="8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8"
_ACTIONLINT_SHA_1_7_12_linux_arm64="325e971b6ba9bfa504672e29be93c24981eeb1c07576d730e9f7c8805afff0c6"

ZIZMOR_BIN=""
ACTIONLINT_BIN=""
BOOTSTRAP_NOTES=""

_boot_note() { BOOTSTRAP_NOTES="${BOOTSTRAP_NOTES}${1}"$'\n'; }

_sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  else printf '' ; fi
}

# ---------------------------------------------------------------------------
ensure_zizmor() {
  if [ -n "${ZIZMOR_BIN_OVERRIDE:-}" ] && [ -x "$ZIZMOR_BIN_OVERRIDE" ]; then
    ZIZMOR_BIN="$ZIZMOR_BIN_OVERRIDE"
    _boot_note "zizmor: uso el binario indicado por ZIZMOR_BIN_OVERRIDE ($ZIZMOR_BIN)"
    return 0
  fi

  local venv="$GATE_TOOLS_DIR/zizmor-$ZIZMOR_VERSION/venv"
  if [ -x "$venv/bin/zizmor" ]; then
    ZIZMOR_BIN="$venv/bin/zizmor"
    _boot_note "zizmor: reutilizo la cache $venv"
    return 0
  fi

  if command -v zizmor >/dev/null 2>&1; then
    local have
    have="$(zizmor --version 2>/dev/null | awk '{print $2}')"
    if [ "$have" = "$ZIZMOR_VERSION" ]; then
      ZIZMOR_BIN="$(command -v zizmor)"
      _boot_note "zizmor: encontrado en el PATH con la version fijada ($have)"
      return 0
    fi
    _boot_note "zizmor: hay un zizmor $have en el PATH pero la version fijada es $ZIZMOR_VERSION; instalo la fijada"
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    _boot_note "zizmor: NO instalable — no hay python3"
    return 2
  fi
  mkdir -p "$(dirname "$venv")" || { _boot_note "zizmor: no pude crear $venv"; return 2; }
  if ! python3 -m venv "$venv" >/dev/null 2>&1; then
    _boot_note "zizmor: NO instalable — 'python3 -m venv' fallo"
    return 2
  fi
  if ! "$venv/bin/pip" install --quiet --disable-pip-version-check "zizmor==$ZIZMOR_VERSION" >/dev/null 2>&1; then
    _boot_note "zizmor: NO instalable — 'pip install zizmor==$ZIZMOR_VERSION' fallo (¿sin red?)"
    return 2
  fi
  ZIZMOR_BIN="$venv/bin/zizmor"
  _boot_note "zizmor: instalado $ZIZMOR_VERSION en $venv"
  return 0
}

# ---------------------------------------------------------------------------
_actionlint_platform() {
  local os arch
  case "$(uname -s)" in
    Linux)  os="linux" ;;
    Darwin) os="darwin" ;;
    *)      printf ''; return 1 ;;
  esac
  case "$(uname -m)" in
    x86_64|amd64)  arch="amd64" ;;
    arm64|aarch64) arch="arm64" ;;
    *)             printf ''; return 1 ;;
  esac
  printf '%s_%s\n' "$os" "$arch"
}

ensure_actionlint() {
  if [ -n "${ACTIONLINT_BIN_OVERRIDE:-}" ] && [ -x "$ACTIONLINT_BIN_OVERRIDE" ]; then
    ACTIONLINT_BIN="$ACTIONLINT_BIN_OVERRIDE"
    _boot_note "actionlint: uso el binario indicado por ACTIONLINT_BIN_OVERRIDE ($ACTIONLINT_BIN)"
    return 0
  fi

  local dir="$GATE_TOOLS_DIR/actionlint-$ACTIONLINT_VERSION"
  if [ -x "$dir/actionlint" ]; then
    ACTIONLINT_BIN="$dir/actionlint"
    _boot_note "actionlint: reutilizo la cache $dir"
    return 0
  fi

  if command -v actionlint >/dev/null 2>&1; then
    local have
    have="$(actionlint --version 2>/dev/null | head -1)"
    if [ "$have" = "$ACTIONLINT_VERSION" ]; then
      ACTIONLINT_BIN="$(command -v actionlint)"
      _boot_note "actionlint: encontrado en el PATH con la version fijada ($have)"
      return 0
    fi
    _boot_note "actionlint: hay un actionlint $have en el PATH pero la version fijada es $ACTIONLINT_VERSION; descargo la fijada"
  fi

  local plat
  plat="$(_actionlint_platform)" || { _boot_note "actionlint: plataforma no soportada ($(uname -s)/$(uname -m))"; return 2; }

  local asset="actionlint_${ACTIONLINT_VERSION}_${plat}.tar.gz"
  local url="https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/${asset}"
  local varname="_ACTIONLINT_SHA_${ACTIONLINT_VERSION//./_}_${plat}"
  local want="${!varname:-}"
  if [ -z "$want" ]; then
    _boot_note "actionlint: no tengo SHA-256 fijado para $asset; me niego a instalar un binario sin verificar"
    return 2
  fi

  mkdir -p "$dir" || { _boot_note "actionlint: no pude crear $dir"; return 2; }
  local tarball="$dir/$asset" how=""

  # 1) gh (autenticado): es lo que hay en la maquina del autor, sin curl.
  if [ ! -f "$tarball" ] && command -v gh >/dev/null 2>&1; then
    if gh auth status >/dev/null 2>&1 || [ -n "${GH_TOKEN:-}${GITHUB_TOKEN:-}" ]; then
      if gh release download "v${ACTIONLINT_VERSION}" --repo rhysd/actionlint \
           --pattern "$asset" --dir "$dir" --clobber >/dev/null 2>&1; then
        how="gh release download"
      fi
    fi
  fi
  # 2) curl: es lo que hay en los runners de GitHub, donde gh no tiene token.
  if [ ! -f "$tarball" ] && command -v curl >/dev/null 2>&1; then
    if curl -fsSL --retry 3 -o "$tarball" "$url" >/dev/null 2>&1; then
      how="curl"
    fi
  fi
  if [ ! -f "$tarball" ]; then
    _boot_note "actionlint: NO descargable — ni gh (autenticado) ni curl pudieron traer $asset"
    return 2
  fi

  local got
  got="$(_sha256_of "$tarball")"
  if [ -z "$got" ]; then
    _boot_note "actionlint: no hay sha256sum ni shasum para verificar el tarball; no instalo lo que no puedo verificar"
    return 2
  fi
  if [ "$got" != "$want" ]; then
    _boot_note "actionlint: SHA-256 NO coincide para $asset (esperado $want, obtenido $got); aborto"
    return 2
  fi

  if ! tar -xzf "$tarball" -C "$dir" actionlint >/dev/null 2>&1; then
    _boot_note "actionlint: no pude extraer el binario de $asset"
    return 2
  fi
  chmod +x "$dir/actionlint" 2>/dev/null || true
  ACTIONLINT_BIN="$dir/actionlint"
  _boot_note "actionlint: instalado $ACTIONLINT_VERSION via $how, SHA-256 verificado ($want)"
  return 0
}
