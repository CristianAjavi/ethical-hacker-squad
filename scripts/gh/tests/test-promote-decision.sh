#!/usr/bin/env bash
# Banco de pruebas de la logica de decision de promote-stable.yml.
# Construye un repo git sintetico con commits retrofechados y sustituye 'gh'
# por un doble que devuelve respuestas controladas. Todo local, cero red.
set -uo pipefail

SP="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "$SP/../../.." && pwd)"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
DECIDE="$WORK/decide.sh"
LAB="$WORK/lab"
BIN="$WORK/fakebin"
PASS=0; FAIL=0

# El paso 'Decidir' del workflow se extrae tal cual del YAML: la prueba corre
# EXACTAMENTE el codigo que correra GitHub, no una copia que se desincroniza.
command -v python3 >/dev/null || { echo "  ABORTA: falta python3 (rc 2)"; exit 2; }
python3 - "$ROOT/.github/workflows/promote-stable.yml" "$DECIDE" <<'PY' || exit 2
import sys, pathlib, yaml
d = yaml.safe_load(pathlib.Path(sys.argv[1]).read_text())
for s in d['jobs']['candidate']['steps']:
    if s.get('name') == 'Decidir':
        pathlib.Path(sys.argv[2]).write_text(s['run']); break
else:
    sys.exit("no encuentro el paso 'Decidir' en el workflow")
PY

# --- doble de gh ------------------------------------------------------------
mkdir -p "$BIN"
cat >"$BIN/gh" <<'EOF'
#!/usr/bin/env bash
# Doble de 'gh api'. Ignora --jq y devuelve lo que digan FAKE_*.
for a in "$@"; do
  case "$a" in
    *check-runs*) [ "${FAKE_CHECKS_FAIL:-0}" = 1 ] && exit 22; printf '%s\n' "${FAKE_CHECKS:-[]}"; exit 0 ;;
    *issues*)     [ "${FAKE_ISSUES_FAIL:-0}" = 1 ] && exit 22; [ -n "${FAKE_ISSUES:-}" ] && printf '%s\n' "$FAKE_ISSUES"; exit 0 ;;
  esac
done
exit 0
EOF
chmod +x "$BIN/gh"

green_check='[{"name":"gates","app":15368,"status":"completed","conclusion":"success","started_at":"2026-01-01T00:00:00Z"}]'

# --- laboratorio git --------------------------------------------------------
# Este git rechaza approxidate en GIT_COMMITTER_DATE, hay que darle ISO 8601.
ago() { date -u -v-"$1"d +%Y-%m-%dT%H:%M:%S+0000; }

build_lab() {   # build_lab <version_old> <version_new> <dias_old> <dias_new>
  rm -rf "$LAB"; mkdir -p "$LAB/repo"
  local d_old d_new; d_old=$(ago "$3"); d_new=$(ago "$4")
  (
    cd "$LAB/repo"
    git init -q -b main
    git config user.email t@t; git config user.name t
    mkdir -p .claude-plugin scripts/gh
    cp "$ROOT/scripts/gh/governance.json" scripts/gh/governance.json
    printf '{"version":"%s"}\n' "$1" >.claude-plugin/plugin.json
    git add -A
    GIT_AUTHOR_DATE="$d_old" GIT_COMMITTER_DATE="$d_old" git commit -qm old
    OLD=$(git rev-parse HEAD)
    printf '{"version":"%s"}\n' "$2" >.claude-plugin/plugin.json
    # marcador que siempre cambia: si no, con la misma version el segundo
    # commit no tendria nada que commitear y el laboratorio solo tendria uno.
    echo "segundo commit" >marker.txt
    git add -A
    GIT_AUTHOR_DATE="$d_new" GIT_COMMITTER_DATE="$d_new" git commit -qm new
    # 'origin' apunta a si mismo: basta para poblar refs/remotes/origin/*
    git remote add origin "$PWD"
    git fetch -q origin '+refs/heads/*:refs/remotes/origin/*'
    echo "$OLD" >"$LAB/old_sha"
  )
}

set_stable() {  # set_stable <sha>
  ( cd "$LAB/repo"; git branch -f stable "$1"; git fetch -q --force origin '+refs/heads/*:refs/remotes/origin/*' )
}

run_case() {    # run_case <nombre> <rc_esperado> <decision_esperada> <substring_motivo>
  local name="$1" want_rc="$2" want_dec="$3" want_sub="$4"
  local out rc
  : >"$LAB/gh_output"
  out=$( cd "$LAB/repo" && PATH="$BIN:$PATH" \
         STATE_FILE=scripts/gh/governance.json REPO=o/r \
         GITHUB_OUTPUT="$LAB/gh_output" bash "$DECIDE" 2>&1 )
  rc=$?
  local dec reason
  dec=$(grep '^decision=' "$LAB/gh_output" | tail -1 | cut -d= -f2-)
  reason=$(grep '^reason=' "$LAB/gh_output" | tail -1 | cut -d= -f2-)
  if [ "$rc" = "$want_rc" ] && [ "$dec" = "$want_dec" ] && [[ "$reason" == *"$want_sub"* ]]; then
    printf '  PASS  %-46s rc=%s decision=%s\n' "$name" "$rc" "$dec"; PASS=$((PASS+1))
  else
    printf '  FAIL  %-46s rc=%s (esperado %s) decision=%s (esperado %s)\n' \
      "$name" "$rc" "$want_rc" "$dec" "$want_dec"
    printf '        motivo: %s\n        esperaba contener: %s\n' "$reason" "$want_sub"
    printf '%s\n' "$out" | sed 's/^/        | /' | tail -12
    FAIL=$((FAIL+1))
  fi
}

echo "== Banco de pruebas de la decision de promocion"

# 1. cuarentena sin cumplir: los dos commits son de hoy
build_lab 1.0.0 1.1.0 0 0
FAKE_CHECKS="$green_check" run_case "cuarentena sin cumplir -> skip" 0 skip "cuarentena aun no se cumple"

# A partir de aqui: old = hace 30d, new = hace 10d (los dos pasan la cuarentena)
build_lab 1.0.0 1.1.0 30 10
OLD=$(cat "$LAB/old_sha")

# 2. camino feliz: stable en el commit viejo, version subida, checks verdes
set_stable "$OLD"
FAKE_CHECKS="$green_check" run_case "camino feliz -> promote" 0 promote "cumplio 7d de cuarentena"

# 3. cero check runs
FAKE_CHECKS='[]' run_case "cero check runs -> block" 1 block "NINGUN check run"

# 4. check requerido en 'skipped' (un job saltado reporta exito: no cuela)
FAKE_CHECKS='[{"name":"gates","app":15368,"status":"completed","conclusion":"skipped","started_at":"2026-01-01T00:00:00Z"}]' \
  run_case "context requerido skipped -> block" 1 block "contexts requeridos no satisfechos"

# 5. check verde pero de OTRA app (status verde falsificado)
FAKE_CHECKS='[{"name":"gates","app":99999,"status":"completed","conclusion":"success","started_at":"2026-01-01T00:00:00Z"}]' \
  run_case "context verde de app equivocada -> block" 1 block "contexts requeridos no satisfechos"

# 6. check en rojo
FAKE_CHECKS='[{"name":"gates","app":15368,"status":"completed","conclusion":"failure","started_at":"2026-01-01T00:00:00Z"}]' \
  run_case "check en failure -> block" 1 block "check runs en rojo"

# 7. check aun corriendo
FAKE_CHECKS='[{"name":"gates","app":15368,"status":"in_progress","conclusion":null,"started_at":"2026-01-01T00:00:00Z"}]' \
  run_case "check sin completar -> block" 1 block "sin completar"

# 8. issue bloqueante abierto
FAKE_CHECKS="$green_check" FAKE_ISSUES='#7 corpus envenenado' \
  run_case "issue con label bloqueante -> block" 1 block "issues abiertos con label"

# 9. la API de issues no responde: no se si esta bloqueado -> no promuevo
FAKE_CHECKS="$green_check" FAKE_ISSUES_FAIL=1 \
  run_case "API de issues caida -> block" 1 block "no pude consultar los issues"

# 10. la API de checks no responde
FAKE_CHECKS_FAIL=1 run_case "API de check-runs caida -> block" 1 block "no pude leer los check runs"

# 11. sin bump de version: promover no llegaria a ningun usuario
build_lab 1.0.0 1.0.0 30 10
set_stable "$(cat "$LAB/old_sha")"
FAKE_CHECKS="$green_check" run_case "sin bump de version -> skip" 0 skip "sin bump de version"

# 12. version que baja
build_lab 2.0.0 1.9.0 30 10
set_stable "$(cat "$LAB/old_sha")"
FAKE_CHECKS="$green_check" run_case "version que degrada -> block" 1 block "es MENOR que la de stable"

# 13. version no semver estricto (prerelease)
build_lab 1.0.0 1.1.0-rc1 30 10
set_stable "$(cat "$LAB/old_sha")"
FAKE_CHECKS="$green_check" run_case "prerelease en stable -> block" 1 block "no es semver"

# 14. stable ya apunta al candidato
build_lab 1.0.0 1.1.0 30 10
( cd "$LAB/repo"; git branch -f stable HEAD; git fetch -q --force origin '+refs/heads/*:refs/remotes/origin/*' )
FAKE_CHECKS="$green_check" run_case "stable ya en el candidato -> skip" 0 skip "nada nuevo que promover"

# 15. stable divergido (no es ancestro del candidato)
build_lab 1.0.0 1.1.0 30 10
( cd "$LAB/repo"
  git checkout -q -b stable "$(cat "$LAB/old_sha")"
  echo x >aparte; git add -A
  D=$(ago 20); GIT_AUTHOR_DATE="$D" GIT_COMMITTER_DATE="$D" git commit -qm divergente
  git checkout -q main
  git fetch -q --force origin '+refs/heads/*:refs/remotes/origin/*' )
FAKE_CHECKS="$green_check" run_case "stable divergido -> block" 1 block "NO es ancestro"

# 16. el tag ya existe apuntando a otro commit
build_lab 1.0.0 1.1.0 30 10
set_stable "$(cat "$LAB/old_sha")"
( cd "$LAB/repo"; git tag stable-v1.1.0 "$(cat "$LAB/old_sha")" )
FAKE_CHECKS="$green_check" run_case "tag ya publicado en otro sha -> block" 1 block "ya existe y apunta a"

# 17. primera creacion de stable (la rama no existe)
build_lab 1.0.0 1.1.0 30 10
FAKE_CHECKS="$green_check" run_case "stable inexistente -> promote (creacion)" 0 promote "cumplio 7d de cuarentena"

echo ""
echo "  $PASS PASS / $FAIL FAIL"
[ "$FAIL" -eq 0 ] || exit 1
