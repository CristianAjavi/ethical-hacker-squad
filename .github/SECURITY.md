# Politica de seguridad

Este repositorio contiene un plugin de Claude Code que instruye a un escuadron de
subagentes de seguridad ofensiva **etica**. Sus ficheros de instrucciones se ejecutan
como contexto dentro del agente de cada persona que lo instala, asi que un defecto
aqui no es solo un bug: es un cambio en el comportamiento de una herramienta de
seguridad en maquinas ajenas. Se trata en consecuencia.

## Versiones con soporte

| Canal | Rama | Soporte |
|---|---|---|
| `stable` | `stable` | Si. Recibe correcciones de seguridad. |
| `latest` | `main` | Si, en la punta. Solo se corrige hacia adelante. |
| Copias instaladas a mano | — | No. Reinstala desde el marketplace. |

Solo se da soporte a la ultima version publicada de cada canal. No hay backports a
versiones anteriores.

## Como reportar una vulnerabilidad

**No abras un issue publico.** Los issues de este repositorio son publicos desde el
primer segundo y el reporte quedaria divulgado antes de existir la correccion.

Canal unico:

- **Aviso de seguridad privado de GitHub:**
  <https://github.com/CristianAjavi/ethical-hacker-squad/security/advisories/new>

Se usa ese formulario y no una direccion de correo a proposito: es privado, queda
trazado, permite discutir el parche con quien reporta antes de publicar y permite
solicitar un CVE al publicarlo. No se publica ninguna direccion de correo para
reportes de seguridad, para que no lleguen por canales sin cifrar.

Incluye en el reporte:

1. Que hace el defecto y cual es el impacto para quien tiene el plugin instalado.
2. Version del plugin (`version` en `.claude-plugin/plugin.json`) y canal (`latest` o `stable`).
3. Pasos minimos de reproduccion, con datos sinteticos y secretos redactados.
4. Si aplica, el identificador de estandar (CWE, OWASP) que corresponda.

## Plazos de respuesta

| Hito | Compromiso |
|---|---|
| Acuse de recibo | 3 dias naturales |
| Triaje y veredicto inicial (aplica / no aplica / falta informacion) | 10 dias naturales |
| Correccion publicada en el canal `latest` | 30 dias naturales para severidad alta o critica |
| Divulgacion coordinada del aviso publico | 90 dias desde el reporte, o antes si ya hay correccion publicada |

Si el plazo de 90 dias se va a incumplir, se avisa a quien reporto y se acuerda una
extension. Se acredita a quien reporta en el aviso, salvo que prefiera el anonimato.

## Que entra en el alcance

- Ejecucion de codigo, filtracion de contexto o escalada de permisos provocada por
  instalar o usar el plugin.
- **Inyeccion indirecta de prompts a traves del corpus de conocimiento**: contenido
  en `skills/**` que induzca al agente del usuario a actuar fuera de lo que la skill
  declara. Es el vector principal de esta herramienta, porque hay un loop automatico
  que lee fuentes publicas y propone cambios al corpus.
- Cadena de publicacion: cualquier via por la que un tercero pueda hacer llegar
  contenido a los canales `latest` o `stable` sin pasar por los gates.
- Workflows de este repositorio: manejo de secretos, permisos de token, acciones sin
  fijar por SHA, disparadores que procesen contenido no confiable.
- Instrucciones que hagan que el escuadron actue fuera del alcance autorizado por su
  usuario (por ejemplo, tocar objetivos que no se le indicaron).

## Que NO entra en el alcance

- **Falsos positivos y falsos negativos del analisis.** Son defectos de calidad, no
  vulnerabilidades: van por los issues publicos
  ([falso positivo](https://github.com/CristianAjavi/ethical-hacker-squad/issues/new?template=1-falso-positivo.yml),
  [falso negativo](https://github.com/CristianAjavi/ethical-hacker-squad/issues/new?template=2-falso-negativo.yml)).
- Vulnerabilidades de software de terceros descubiertas usando esta herramienta.
  Divulgalas de forma coordinada con el proveedor afectado; este repositorio no es su
  canal de reporte ni las va a intermediar.
- Vulnerabilidades de la plataforma Claude Code o de Anthropic. Reportalas por sus
  propios canales.
- Resultados crudos de un escaner sobre este repositorio sin analisis de
  explotabilidad en su contexto.

## Alcance de uso etico

El plugin existe para auditar, reforzar y verificar sistemas **propios o
explicitamente autorizados**. El contrato de seguridad esta en
`skills/ethical-hacker-squad/SKILL.md` y es parte del producto, no una advertencia
decorativa.

Condiciones de uso y de contribucion:

1. **Autorizacion previa y verificable.** Usarlo contra sistemas, cuentas, dominios o
   datos de terceros sin permiso explicito es ilegal en la mayoria de jurisdicciones y
   queda fuera de todo soporte.
2. **No se aceptan contribuciones que armen ataques.** Ni exploits funcionales, ni
   payloads listos para usar, ni tecnicas de persistencia, exfiltracion, evasion
   furtiva, denegacion de servicio o movimiento lateral. Lo que entra al corpus es
   capacidad de deteccion y de correccion.
3. **No se aceptan 0-days sin parche** como aportacion al corpus. Divulgacion
   coordinada con el proveedor primero; el corpus se actualiza cuando la informacion
   ya es publica.
4. **Nada de datos reales.** Casos, ejemplos y pruebas usan datos sinteticos.
   Secretos, credenciales y datos personales se redactan siempre.
5. **La licencia MIT no otorga autorizacion.** Que puedas ejecutar la herramienta no
   significa que puedas ejecutarla contra un sistema que no controlas.

Quien contribuya material que viole estos puntos vera el aporte rechazado y, si es
deliberado, el acceso bloqueado.
