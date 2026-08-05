#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# PRUEBA EN NEGATIVO del comparador de proteccion de ramas.
#
# governance.json declara una docena de campos de proteccion. La pregunta es si
# el comparador los MIRA todos, o si hay campos declarados que nadie compara: un
# campo declarado y no comparado produce un rc=0 que significa "no lo revise",
# que es justo lo que esta doctrina prohibe.
#
# Metodo: se levanta un doble de la API de GitHub que responde exactamente el
# estado deseado (linea base -> rc 0), y despues se desvia UN campo cada vez
# exigiendo rc 1. Si un campo se desvia y el script sigue diciendo rc 0, ese
# campo esta declarado pero no vigilado.
#
# Hallazgo original de esta suite: block_creations y allow_fork_syncing estaban
# declarados en el JSON, se enviaban en el PUT, y no se comparaban nunca.
#
# CODIGOS DE SALIDA:  0 todo vigilado / 1 hay un campo ciego / 2 no pude correr
# ---------------------------------------------------------------------------
set -uo pipefail
SP="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "$SP/../../.." && pwd)"
command -v jq >/dev/null 2>&1 || { echo "  NO PUDE MEDIR: falta jq (rc 2)"; exit 2; }
command -v awk >/dev/null 2>&1 || { echo "  NO PUDE MEDIR: falta awk (rc 2)"; exit 2; }

LAB="$(mktemp -d)"; trap 'rm -rf "$LAB"' EXIT
mkdir -p "$LAB/bin" "$LAB/repo/scripts/gh" "$LAB/repo/.github/workflows" "$LAB/repo/scripts/gates"
cp "$ROOT/scripts/gh/apply-governance.sh" "$LAB/repo/scripts/gh/"
cp "$ROOT/scripts/gh/governance.json"     "$LAB/repo/scripts/gh/"
cp "$ROOT/.github/workflows/promote-stable.yml" "$LAB/repo/.github/workflows/"
printf '#!/usr/bin/env bash\nexit 0\n' >"$LAB/repo/scripts/gates/dummy.sh"
STATE="$LAB/repo/scripts/gh/governance.json"

# --- doble de la API: devuelve el estado DESEADO como si fuese el real -------
cat >"$LAB/bin/gh" <<EOF
#!/usr/bin/env bash
STATE="$STATE"
PROT_OVERRIDE="\${PROT_OVERRIDE:-}"
EOF
cat >>"$LAB/bin/gh" <<'EOF'
path=""; jqf=""
while [ $# -gt 0 ]; do
  case "$1" in
    api) ;;
    --jq) jqf="$2"; shift ;;
    --paginate|--method) [ "$1" = "--method" ] && shift ;;
    -*) ;;
    *) [ -z "$path" ] && path="$1" ;;
  esac
  shift
done
APP=$(jq -r '.actions_app_id' "$STATE")
# Forma real de la respuesta GET: los booleanos vienen anidados en {enabled:...}
protection() {
  jq -c --argjson app "$APP" --arg b "$1" '
    .branches[$b].protection as $p
    | { allow_force_pushes:{enabled:($p.allow_force_pushes // false)},
        allow_deletions:{enabled:($p.allow_deletions // false)},
        required_linear_history:{enabled:($p.required_linear_history // false)},
        required_conversation_resolution:{enabled:($p.required_conversation_resolution // false)},
        lock_branch:{enabled:($p.lock_branch // false)},
        enforce_admins:{enabled:($p.enforce_admins // false)},
        block_creations:{enabled:($p.block_creations // false)},
        allow_fork_syncing:{enabled:($p.allow_fork_syncing // false)} }
      + (if $p.required_status_checks != null then
           {required_status_checks:{strict:$p.required_status_checks.strict,
             checks:[$p.required_status_checks.checks[] | {context:.context, app_id:$app}]}}
         else {} end)
      + (if $p.required_pull_request_reviews != null then
           {required_pull_request_reviews:$p.required_pull_request_reviews} else {} end)
  ' "$STATE"
}
case "$path" in
  user) out='{"login":"'"$(jq -r .expected_account "$STATE")"'"}' ;;
  repos/*/branches/*/protection)
    b=$(echo "$path" | awk -F/ '{print $5}'); out=$(protection "$b")
    [ -n "$PROT_OVERRIDE" ] && out=$(jq -c "$PROT_OVERRIDE" <<<"$out") ;;
  repos/*/branches/*) b=$(echo "$path" | awk -F/ '{print $5}'); out='{"name":"'"$b"'"}' ;;
  repos/*/topics) out=$(jq -c '{names: .topics}' "$STATE") ;;
  repos/*/labels*) out=$(jq -c '[.labels[] | {name, color, description}]' "$STATE") ;;
  repos/*/vulnerability-alerts) exit 0 ;;
  repos/*/commits/*/check-runs)
    out='{"check_runs":[{"name":"gates","app":{"id":'"$APP"'},"status":"completed","conclusion":"success"}]}' ;;
  repos/*commits*) out='[{"sha":"deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"}]' ;;
  repos/*)
    out=$(jq -c '.settings + {permissions:{admin:true}, owner:{type:"User"},
      security_and_analysis:{
        secret_scanning:{status:(if .secret_scanning.enabled then "enabled" else "disabled" end)},
        secret_scanning_push_protection:{status:(if .secret_scanning.push_protection then "enabled" else "disabled" end)}}}' "$STATE") ;;
  *) out='{}' ;;
esac
if [ -n "$jqf" ]; then printf '%s' "$out" | jq -r "$jqf"; else printf '%s\n' "$out"; fi
EOF
chmod +x "$LAB/bin/gh"

G="$LAB/repo/scripts/gh/apply-governance.sh"
PASS=0; FAIL=0
probe() { # nombre, override-jq, rc_esperado
  local out rc
  out=$(PROT_OVERRIDE="$2" PATH="$LAB/bin:$PATH" "$G" --no-color 2>&1); rc=$?
  if [ "$rc" = "$3" ]; then printf '  PASS  %-56s rc=%s\n' "$1" "$rc"; PASS=$((PASS+1))
  else printf '  FAIL  %-56s rc=%s (esperado %s)\n' "$1" "$rc" "$3"
       printf '        campo declarado y NO vigilado: un rc=0 que no midio nada\n'; FAIL=$((FAIL+1)); fi
}

echo "== Linea base: rc=0 tiene que ser alcanzable (si no, es un codigo muerto)"
probe "estado real == estado deseado -> 0" "" 0

echo ""
echo "== Cada campo declarado, desviado de uno en uno -> 1"
probe "allow_force_pushes=true (el canal se podria reescribir)"  '.allow_force_pushes.enabled = true' 1
probe "allow_deletions=true (el canal se podria borrar)"          '.allow_deletions.enabled = true' 1
probe "enforce_admins=true (dejaria el rollback sin salida)"      '.enforce_admins.enabled = true' 1
probe "required_linear_history=false"                             '.required_linear_history.enabled = false' 1
probe "required_conversation_resolution=false"                    '.required_conversation_resolution.enabled = false' 1
probe "lock_branch=true"                                          '.lock_branch.enabled = true' 1
probe "block_creations=true"                                      '.block_creations.enabled = true' 1
probe "allow_fork_syncing=true"                                   '.allow_fork_syncing.enabled = true' 1
probe "check requerido reportable por OTRA app (app_id 99999)"    '.required_status_checks.checks = [{context:"gates",app_id:99999}]' 1
probe "check requerido borrado del estado real"                   '.required_status_checks.checks = []' 1
probe "strict cambiado"                                           '.required_status_checks.strict = true' 1
probe "el camino del PR deja de ser obligatorio"                  'del(.required_pull_request_reviews)' 1
probe "required_approving_review_count subido a 1"                '.required_pull_request_reviews.required_approving_review_count = 1' 1
probe "require_code_owner_reviews activado por la espalda"        '.required_pull_request_reviews.require_code_owner_reviews = true' 1

echo ""
echo "  $PASS PASS / $FAIL FAIL"
[ "$FAIL" -eq 0 ] || exit 1
