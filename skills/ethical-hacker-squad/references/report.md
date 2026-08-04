# Formato del informe

## Resumen ejecutivo

Indicar alcance, modo, componentes revisados, resultado general y los riesgos más importantes. Evitar garantías absolutas.

## Alcance y metodología

Registrar:

- carpeta, repositorio, artefacto o endpoint autorizado;
- commit o versión si está disponible;
- técnicas y herramientas usadas;
- pruebas activas realizadas;
- exclusiones y limitaciones.

## Hallazgos

Ordenar por severidad y después por confianza. Para cada hallazgo incluir:

1. ID y título.
2. Estado, severidad y confianza.
3. Ubicación precisa.
4. Evidencia mínima redactada.
5. Escenario de impacto y precondiciones.
6. Causa raíz.
7. Corrección recomendada o aplicada.
8. Estado de verificación.

No inflar el informe con recomendaciones genéricas. Mantener los descartados en una nota breve solo cuando eviten repetir trabajo.

## Cambios realizados

En modo `reforzar`, listar archivos modificados, objetivo de cada cambio y compatibilidad relevante. Separar rotaciones, despliegues u operaciones pendientes que requieran acción del usuario.

## Verificación

Enumerar comandos o pruebas ejecutadas y su resultado. Distinguir claramente:

- verificado;
- verificado parcialmente;
- no ejecutado;
- bloqueado por autorización o entorno.

## Riesgo residual y próximos pasos

Priorizar acciones concretas. Señalar superficies no revisadas, dependencias de entorno y pruebas remotas que requieran autorización adicional.
