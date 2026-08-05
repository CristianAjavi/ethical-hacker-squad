# Triaje determinista de entradas externas

Regla dura del repo: **los labels de una entrada externa se derivan de campos del
formulario, nunca del juicio de un LLM**, y ningun workflow procesa contenido
escrito por desconocidos.

## Como se cumple hoy

La **eleccion de plantilla es el campo**. Los issue forms no soportan labels
condicionales: `labels:` es de nivel plantilla y se aplica igual a todas las issues
creadas con ella ([syntax for issue forms][forms]). Por eso hay una plantilla por
categoria, cada una con su `labels:` cableado:

| Plantilla | Labels aplicados |
|---|---|
| `1-falso-positivo.yml` | `tipo/falso-positivo`, `origen/humano`, `estado/needs-triage` |
| `2-falso-negativo.yml` | `tipo/falso-negativo`, `origen/humano`, `estado/needs-triage` |
| `3-knowledge-gap.yml` | `tipo/knowledge-gap`, `origen/humano`, `estado/needs-triage` |
| `4-bug.yml` | `tipo/bug`, `origen/humano`, `estado/needs-triage` |

`config.yml` pone `blank_issues_enabled: false`, que elimina la issue en blanco (la
unica via para entrar sin ningun label), y desvia el reporte de vulnerabilidad al
formulario privado de advisory **antes** de que se publique en un issue publico.

Los labels `area/<rol>` y `severidad/<valor>` **no** se aplican solos: viven en
dropdowns cuyas opciones son literalmente los sufijos de esos labels
(`scripts/gh/labels.sh` crea la taxonomia). Un mantenedor los copia sin ejercer
juicio: la respuesta esta en el cuerpo del issue, en texto exacto y cerrado.

Superficie de ataque de este diseno: **cero**. Sin trigger `issues:`, sin token, sin
parser, sin LLM leyendo texto de desconocidos.

## Opcion evaluada y RECHAZADA: parsear los dropdowns en un workflow

El cuerpo de una issue creada desde un form se renderiza de forma predecible
(`### <label del campo>`, linea en blanco, valor; los opcionales vacios quedan como
el literal `_No response_`), asi que seria tecnicamente posible derivar
`area/*` y `severidad/*` con un workflow: partir por `/^### /`, comparar el valor
contra una lista blanca cerrada y no poner label si no hay coincidencia exacta.

Se rechaza por dos razones:

1. **Exige `on: issues`**, es decir un workflow que se dispara con contenido escrito
   por cualquiera y que necesita `issues: write` para etiquetar. Eso es exactamente
   la clase de canal que las reglas duras de este repo prohiben, y el beneficio
   (dos labels mas finos) no paga esa superficie.
2. **El formato no es un contrato estable.** `### label` y `_No response_` estan
   verificados empiricamente en issues reales, pero GitHub no los documenta como
   garantia. Parsearlos seria construir un automatismo sobre algo que puede cambiar
   sin aviso, y un parser que falla en silencio deja issues sin etiquetar.

Si algun dia se revisa la politica, esta es la nota que hay que releer primero.

[forms]: https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/syntax-for-issue-forms
