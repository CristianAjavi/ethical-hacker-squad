# Ethical Hacker Squad

Skill/plugin para [Claude Code](https://claude.com/claude-code) que convierte el hilo principal en el **líder de un escuadrón adaptable de subagentes de seguridad ofensiva ética**: inventaría el proyecto, forma el equipo según los artefactos que realmente existen, investiga con evidencia reproducible, repara solo lo confirmado y verifica cada cambio con un agente distinto al que lo reparó.

> **Uso autorizado únicamente.** Esta skill está diseñada para auditar sistemas propios o con autorización explícita. Su contrato de seguridad prohíbe persistencia, exfiltración, destrucción, denegación de servicio, phishing real, evasión furtiva y movimiento lateral, y exige autorización antes de escanear objetivos remotos, explotar una vulnerabilidad o tocar producción.

## Qué hace distinto

- **Equipo adaptativo, no checklist fijo.** Lanza entre dos y cuatro especialistas pertinentes; no gasta un agente `mobile` si no hay APK.
- **Detección y verificación separadas.** El verificador trabaja desde el hallazgo y el diff, nunca desde la conclusión del reparador, e intenta refutar ambos.
- **Evidencia antes que ruido.** La coincidencia de una herramienta no es una vulnerabilidad confirmada: hay que trazar entrada → transformación → destino y demostrar impacto.
- **Honestidad de alcance.** Nunca declara un sistema "seguro"; separa hallazgos confirmados, riesgos probables, endurecimiento y pruebas no ejecutadas por límites de autorización.

## Modos

| Modo | Qué hace |
|---|---|
| `auditar` | Detecta y prioriza **sin modificar archivos** (default ante la duda). |
| `reforzar` | Audita, repara los hallazgos confirmados dentro del repo y verifica. |
| `verificar` | Comprueba correcciones o controles ya existentes. |

## Roles del escuadrón

`security-lead` (líder) · `web-api` · `mobile` (APK) · `infra-cloud` · `supply-chain` (dependencias y secretos) · `ai-safety` (agentes, chatbots, prompt injection) · `privacy-abuse` · `remediator` · `verifier`

Las órdenes textuales de cada rol están en [`skills/ethical-hacker-squad/references/team.md`](skills/ethical-hacker-squad/references/team.md), la cobertura por tecnología en [`coverage.md`](skills/ethical-hacker-squad/references/coverage.md) y el formato de informe en [`report.md`](skills/ethical-hacker-squad/references/report.md).

## Instalación

**Como plugin (recomendado)** — desde Claude Code:

```
/plugin marketplace add CristianAjavi/ethical-hacker-squad
/plugin install ethical-hacker-squad@ethical-hacker-squad
```

**Como skill personal** — disponible en todos tus proyectos:

```bash
git clone https://github.com/CristianAjavi/ethical-hacker-squad.git /tmp/ehs
cp -R /tmp/ehs/skills/ethical-hacker-squad ~/.claude/skills/
```

**Como skill de un proyecto** — se versiona junto al repo que audita:

```bash
mkdir -p .claude/skills
cp -R /tmp/ehs/skills/ethical-hacker-squad .claude/skills/
```

## Uso

```
Usa la skill ethical-hacker-squad para auditar este repositorio sin modificar archivos.
Usa ethical-hacker-squad en modo reforzar sobre /ruta/proyecto y corrige los hallazgos confirmados.
Usa ethical-hacker-squad para revisar esta APK local; no pruebes servicios remotos.
Usa ethical-hacker-squad para analizar el chatbot, especialmente prompt injection, herramientas y fuga de datos.
```

Cada hallazgo vuelve al líder con ID, estado (confirmado/probable/endurecimiento/descartado), severidad, confianza, ubicación, evidencia redactada, impacto, corrección recomendada y método de verificación.

## Estructura

```
.claude-plugin/
  plugin.json        # metadata del plugin
  marketplace.json   # permite instalarlo con /plugin marketplace add
skills/
  ethical-hacker-squad/
    SKILL.md         # contrato de seguridad + flujo del líder
    references/
      team.md        # órdenes textuales por rol
      coverage.md    # cobertura por tecnología
      report.md      # formato del informe final
```

## Licencia

MIT — ver [LICENSE](LICENSE).
