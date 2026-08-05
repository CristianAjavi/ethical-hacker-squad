#!/usr/bin/env bash
# scripts/gates/lib/bootstrap-actions-lint.sh
#
# Makes zizmor and actionlint available AT PINNED VERSIONS, with the same recipe
# locally (macOS, no sudo, no brew) and in CI (ubuntu-latest). Meant to be sourced.
#
# Defines: ZIZMOR_BIN, ACTIONLINT_BIN  (empty if the tool could not be installed).
# Returns 0 if the tool is ready, 2 if it could NOT be (never 0 blindly).
#
# Cache: $GATE_TOOLS_DIR (by default outside the repo, so the work tree stays
# clean and .gitignore does not have to be touched).
#
# The actionlint tarball is verified against a SHA-256 PINNED in this file: for a
# binary, it is the equivalent of the SHA pin we demand from actions.

# shellcheck shell=bash

ZIZMOR_VERSION="${ZIZMOR_VERSION:-1.29.0}"
ACTIONLINT_VERSION="${ACTIONLINT_VERSION:-1.7.12}"
GATE_TOOLS_DIR="${GATE_TOOLS_DIR:-${TMPDIR:-/tmp}/ehs-gate-tools}"

# SHA-256 of the official actionlint v1.7.12 tarballs
# (source: actionlint_1.7.12_checksums.txt from the rhysd/actionlint release,
#  downloaded and verified on 2026-08-04 against the darwin_arm64 tarball).
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
    _boot_note "zizmor: using the binary pointed to by ZIZMOR_BIN_OVERRIDE ($ZIZMOR_BIN)"
    return 0
  fi

  local venv="$GATE_TOOLS_DIR/zizmor-$ZIZMOR_VERSION/venv"
  if [ -x "$venv/bin/zizmor" ]; then
    ZIZMOR_BIN="$venv/bin/zizmor"
    _boot_note "zizmor: reusing the cache at $venv"
    return 0
  fi

  if command -v zizmor >/dev/null 2>&1; then
    local have
    have="$(zizmor --version 2>/dev/null | awk '{print $2}')"
    if [ "$have" = "$ZIZMOR_VERSION" ]; then
      ZIZMOR_BIN="$(command -v zizmor)"
      _boot_note "zizmor: found in PATH at the pinned version ($have)"
      return 0
    fi
    _boot_note "zizmor: there is a zizmor $have in PATH but the pinned version is $ZIZMOR_VERSION; installing the pinned one"
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    _boot_note "zizmor: NOT installable - there is no python3"
    return 2
  fi
  mkdir -p "$(dirname "$venv")" || { _boot_note "zizmor: I could not create $venv"; return 2; }
  if ! python3 -m venv "$venv" >/dev/null 2>&1; then
    _boot_note "zizmor: NOT installable - 'python3 -m venv' failed"
    return 2
  fi
  if ! "$venv/bin/pip" install --quiet --disable-pip-version-check "zizmor==$ZIZMOR_VERSION" >/dev/null 2>&1; then
    _boot_note "zizmor: NOT installable - 'pip install zizmor==$ZIZMOR_VERSION' failed (no network?)"
    return 2
  fi
  ZIZMOR_BIN="$venv/bin/zizmor"
  _boot_note "zizmor: installed $ZIZMOR_VERSION in $venv"
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
    _boot_note "actionlint: using the binary pointed to by ACTIONLINT_BIN_OVERRIDE ($ACTIONLINT_BIN)"
    return 0
  fi

  local dir="$GATE_TOOLS_DIR/actionlint-$ACTIONLINT_VERSION"
  if [ -x "$dir/actionlint" ]; then
    ACTIONLINT_BIN="$dir/actionlint"
    _boot_note "actionlint: reusing the cache at $dir"
    return 0
  fi

  if command -v actionlint >/dev/null 2>&1; then
    local have
    have="$(actionlint --version 2>/dev/null | head -1)"
    if [ "$have" = "$ACTIONLINT_VERSION" ]; then
      ACTIONLINT_BIN="$(command -v actionlint)"
      _boot_note "actionlint: found in PATH at the pinned version ($have)"
      return 0
    fi
    _boot_note "actionlint: there is an actionlint $have in PATH but the pinned version is $ACTIONLINT_VERSION; downloading the pinned one"
  fi

  local plat
  plat="$(_actionlint_platform)" || { _boot_note "actionlint: unsupported platform ($(uname -s)/$(uname -m))"; return 2; }

  local asset="actionlint_${ACTIONLINT_VERSION}_${plat}.tar.gz"
  local url="https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/${asset}"
  local varname="_ACTIONLINT_SHA_${ACTIONLINT_VERSION//./_}_${plat}"
  local want="${!varname:-}"
  if [ -z "$want" ]; then
    _boot_note "actionlint: I have no pinned SHA-256 for $asset; I refuse to install an unverified binary"
    return 2
  fi

  mkdir -p "$dir" || { _boot_note "actionlint: I could not create $dir"; return 2; }
  local tarball="$dir/$asset" how=""

  # 1) gh (authenticated): that is what the author's machine has, without curl.
  if [ ! -f "$tarball" ] && command -v gh >/dev/null 2>&1; then
    if gh auth status >/dev/null 2>&1 || [ -n "${GH_TOKEN:-}${GITHUB_TOKEN:-}" ]; then
      if gh release download "v${ACTIONLINT_VERSION}" --repo rhysd/actionlint \
           --pattern "$asset" --dir "$dir" --clobber >/dev/null 2>&1; then
        how="gh release download"
      fi
    fi
  fi
  # 2) curl: that is what the GitHub runners have, where gh has no token.
  if [ ! -f "$tarball" ] && command -v curl >/dev/null 2>&1; then
    if curl -fsSL --retry 3 -o "$tarball" "$url" >/dev/null 2>&1; then
      how="curl"
    fi
  fi
  if [ ! -f "$tarball" ]; then
    _boot_note "actionlint: NOT downloadable - neither gh (authenticated) nor curl could fetch $asset"
    return 2
  fi

  local got
  got="$(_sha256_of "$tarball")"
  if [ -z "$got" ]; then
    _boot_note "actionlint: there is no sha256sum or shasum to verify the tarball; I do not install what I cannot verify"
    return 2
  fi
  if [ "$got" != "$want" ]; then
    _boot_note "actionlint: SHA-256 does NOT match for $asset (expected $want, got $got); aborting"
    return 2
  fi

  if ! tar -xzf "$tarball" -C "$dir" actionlint >/dev/null 2>&1; then
    _boot_note "actionlint: I could not extract the binary from $asset"
    return 2
  fi
  chmod +x "$dir/actionlint" 2>/dev/null || true
  ACTIONLINT_BIN="$dir/actionlint"
  _boot_note "actionlint: installed $ACTIONLINT_VERSION via $how, SHA-256 verified ($want)"
  return 0
}
