<!--
  No borres las secciones. Los apartados se rellenan; los que no apliquen se marcan
  "no aplica" con una razon.

  QUE BLOQUEA DE VERDAD (scripts/gates/gate-issue-closure.sh, en cada PR):
  si este PR declara cerrar un issue etiquetado tipo/falso-positivo o tipo/falso-negativo
  y NO toca ningun fichero de scripts/gates/, tests/ o cases/, el gate falla (rc=1).
  Borrar ese fichero tampoco cuenta: el gate descarta los ficheros que el PR elimina.

  QUE NO BLOQUEA (lo revisa una persona): no declarar ningun issue no falla el gate,
  porque hay PRs legitimos sin issue (infraestructura, el loop de conocimiento).
  Tampoco puede comprobar que el fichero tocado contenga DE VERDAD el caso de esta
  regresion. Eso es lo que se revisa leyendo las secciones de abajo.
-->

## Que cierra

<!--
  OBLIGATORIO. Una palabra clave de cierre por issue, en el CUERPO de este PR:
  Fixes #N   |   Closes #N   |   Resolves #N
  (GitHub solo enlaza si el PR apunta a la rama por defecto del repo.)
  Si este PR no cierra ningun issue, escribe: "No cierra ningun issue porque <razon>"
  y abre el issue antes si el cambio corrige un comportamiento observado.
-->

Fixes #

## Que quedo vigilando la regresion

<!--
  OBLIGATORIO cuando se cierra un issue de tipo/falso-positivo o tipo/falso-negativo.
  Doctrina del repo: un issue no se cierra con el arreglo, se cierra con el arreglo
  MAS el check que impide que reaparezca. Un arreglo sin check es una recaida programada.

  Rellena las tres lineas. El gate exige que el PR toque de verdad un gate o el corpus de casos.
-->

- **Gate o caso:** <!-- ruta exacta: scripts/gates/<x>.sh, tests/cases/<x>, cases/<x> -->
- **Que detecta:** <!-- la entrada concreta que antes pasaba y ahora falla -->
- **Como falla si la regresion vuelve:** <!-- salida y codigo de salida esperados: 1 = medi y falla -->

Verificacion en negativo (obligatoria para gates nuevos o modificados):

```
# pega el comando y su salida: primero con el defecto presente (debe dar rc=1),
# luego con el arreglo aplicado (debe dar rc=0)
```

## Cambio

<!-- Que cambia y por que. Si toca las instrucciones de la skill, di que rol afecta. -->

## Impacto en la distribucion

<!-- Marca lo que corresponda -->

- [ ] Toca `skills/**` o `.claude-plugin/**` (afecta a lo que reciben los usuarios instalados)
- [ ] Requiere subir `version` en `.claude-plugin/plugin.json` (sin bump, los usuarios NO reciben nada)
- [ ] Solo toca infraestructura del repo (`.github/**`, `scripts/**`): no requiere bump

## Origen

- [ ] `origen/humano` — lo escribio una persona
- [ ] `origen/loop` — lo abrio el loop de conocimiento (rama `bot/knowledge-YYYY-WW`)

Si es `origen/loop`, ademas:

- [ ] Cada afirmacion nueva del corpus cita una **fuente publica primaria** enlazada
- [ ] Ninguna fuente introduce instrucciones dirigidas al agente (revisado como texto, no ejecutado)

## Reglas duras (marcar solo lo que se verifico, no lo que se supone)

- [ ] Ningun workflow nuevo o modificado usa `pull_request_target`, `issues`, `issue_comment` ni `discussion`
- [ ] Ningun job que procese contenido no confiable recibe secretos
- [ ] `permissions:` declarado **por job**, con el minimo necesario
- [ ] Toda accion de terceros fijada por SHA de 40 caracteres, con el tag en comentario
- [ ] Ningun `${{ github.event.* }}` interpolado dentro de un bloque `run:`
- [ ] Ningun secreto real, credencial ni dato personal en el diff (incluidos ficheros de prueba)

## Alcance etico

- [ ] Este cambio no añade capacidad de ataque contra sistemas de terceros ni payloads armados
- [ ] Los ejemplos y casos usan datos sinteticos
