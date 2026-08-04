# Cobertura por tecnología

Leer solo las secciones que correspondan al inventario real.

## Web, backend y API

- Límites de autenticación, autorización y tenants.
- Entradas HTTP, jobs, webhooks, colas, archivos y plantillas.
- ORM y consultas; llamadas de red; sistema de archivos; procesos del sistema.
- Cookies, tokens, CORS, CSRF, cabeceras y caché.
- Errores, logs, rate limiting, idempotencia y abuso de flujos.

## Frontend

- XSS y sinks DOM, URLs controlables, HTML/Markdown y postMessage.
- Tokens, almacenamiento local, datos sensibles y source maps.
- Dependencia indebida de controles exclusivamente cliente.
- Integridad de recursos, iframes y comunicación entre orígenes.

## Android, iOS y APK

- Manifiesto/entitlements, componentes exportados y enlaces profundos.
- Permisos, backups, capturas, portapapeles, logs y almacenamiento.
- WebViews, bridges nativos, intents, URL schemes y archivos compartidos.
- TLS, trust managers, ATS/network security config y secretos incrustados.
- Ofuscación no sustituye controles de servidor.

## Infraestructura, contenedores y CI/CD

- IAM y mínimo privilegio; redes, puertos, ingress y egress.
- Imágenes, usuario root, capabilities, montajes y aislamiento.
- Secretos, variables, artefactos, caches y logs.
- Workflows de PR, forks, runners, tokens, acciones y versiones fijadas.
- Terraform, Kubernetes y configuración por entorno.

## Dependencias y supply chain

- Manifiesto y lock sincronizados; versiones y advisories pertinentes.
- Alcanzabilidad del componente vulnerable y mitigaciones presentes.
- Scripts lifecycle, paquetes internos, registries y nombres confundibles.
- Firmas, hashes, procedencia, SBOM y flujo de publicación cuando existan.

## IA, LLM y chatbot

- Separación entre instrucciones confiables y contenido no confiable.
- Autorización por herramienta y por usuario, no delegada al texto del modelo.
- Prompt injection indirecto en web, documentos, correo, RAG y memoria.
- Fuga de prompts, secretos, contexto cruzado y datos de otros tenants.
- Validación de argumentos/resultados, sandbox, SSRF y rutas de exfiltración.
- Límites de coste, tamaño, recursión, reintentos y acciones humanas críticas.
- Evaluaciones adversariales reproducibles con corpus sintético.

## Datos y privacidad

- Clasificación, necesidad, consentimiento, retención y borrado.
- Cifrado, acceso, auditoría, exportaciones y copias de seguridad.
- Aislamiento multitenant y referencias directas a objetos.
- Analítica, SDK de terceros y datos introducidos en modelos.

## Aplicaciones de escritorio, CLI y librerías

- Manejo de rutas, archivos temporales, enlaces simbólicos y permisos.
- Argumentos, variables de entorno, configuración y ejecución de procesos.
- Formatos no confiables, deserialización y actualizaciones.
- Seguridad de API pública, defaults y documentación de comportamientos peligrosos.
