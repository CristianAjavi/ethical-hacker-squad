# Analisis de cobertura — curriculos de nube (Microsoft AZ-500 / SC-500 / SC-100 / SC-200, MCSB v2, AWS SCS-C02, GCP PCSE) contra INF-01..18 y PRV-01..11

**Fecha:** 2026-08-11 · **Modo:** solo lectura sobre `/Users/cristianajavi/ethical-hacker-squad` · **Entregable:** este archivo, fuera del repo.

**Corpus leido:** `references/knowledge/infra-cloud.md` (387 lineas, INF-01..INF-18), `references/knowledge/privacy-abuse.md` (268 lineas, PRV-01..PRV-11), `references/traceability.md`. Consultados por adyacencia (para no proponer duplicados): `supply-chain.md` (SUP-01..20), `ai-safety.md` (AI-01..22), `web-api.md` (WEB-01..22), `remediation.md` (REM/VER).

**Encuadre.** El producto no es resumen del temario. Un temario de certificacion es un mapa de competencias: lo que la industria espera que un profesional sepa *hacer*. Lo unico que se importa aqui son (1) identificadores y codigos como hechos, (2) nombres de dominio/tema, (3) el hecho estructural de que competencia exige el mercado. Ni una linea de redaccion ajena. Todos los borradores de abajo estan escritos desde cero con los 6 campos del corpus.

**Regla de estrictez aplicada.** "El pack menciona X" no es cobertura de X. Cobertura = un agente siguiendo ese procedimiento *encontraria* ese fallo, con los simbolos concretos que hay que buscar. Ejemplo: INF-03 dice "sin clave gestionada por el cliente baja de severidad", pero ningun procedimiento mira la *politica* de la clave; eso no es cobertura de gestion de claves, es una nota al margen.

---

## 1. Lo que el corpus YA cubre (y no hay que tocar)

| Tema del temario profesional | Procedimiento que lo cubre | Calidad de la cobertura |
|---|---|---|
| Reglas de red abiertas a internet (AZ-500 secure networking · AWS 3.2 · GCP 2.2 · MCSB v2 NS) | `INF-04` | Completa: NSG/SG/firewall, `0.0.0.0/0`, clasificacion por puerto, descarte del LB publico |
| Almacenamiento de objetos publico (AWS 5.2 S3 Block Public Access · AZ-500 storage · GCP 3.1) | `INF-02` | Completa en los tres proveedores, con el matiz de "bucket publico por diseno" |
| Cifrado en reposo y en transito, TLS minimo (AWS 5.1/5.2 · AZ-500 disk/TDE · GCP 3.2) | `INF-03` | Cubre presencia/ausencia y version de TLS. **No** cubre la clave (ver hueco INF-22) |
| Politicas IAM sobre-permisivas con comodin (AWS 4.2 · AZ-500 roles · GCP 1.4 · SC-500 asignaciones sobre-privilegiadas) | `INF-01` | Completa para el caso wildcard y para `Owner`/`Contributor`/`roles/owner`. **No** cubre escalada sin wildcard (hueco INF-19) |
| Credenciales estaticas de larga vida vs federacion (AWS 4.1 · GCP 1.2 service account keys / Workload Identity Federation · AZ-500 managed identities) | `INF-05` | Completa para el plano de control y CI. **No** cubre claves de plano de datos (SAS, HMAC, connection strings) |
| Logging de auditoria, retencion y alerta en la definicion de infra (AWS 2.3 · GCP 4.2 · MCSB v2 LT) | `INF-06` | Completa para plano de control. **No** cubre plano de datos (hueco PRV-13) |
| Imagenes de contenedor: usuario root y tag movil (AWS 3.3 imagenes endurecidas · GCP 4.1 hardening de imagenes) | `INF-07` | Completa |
| Paso inseguro de secretos a la carga de computo (AWS 3.3 "securely pass secrets to compute") | `INF-08` + `SUP-16..18` | Completa |
| Runtime privilegiado y socket de Docker | `INF-09` | Completa |
| Requisitos de seguridad de contenedores y de orquestacion (SC-100 · SC-500 Defender for Containers · AKS/GKE) | `INF-10`, `INF-11`, `INF-12` | Completa a nivel manifiesto. **No** cubre admision (verificacion de firma en el despliegue) |
| RBAC de Kubernetes con minimo privilegio | `INF-11` | Completa |
| Secretos en manifiestos y token de ServiceAccount automontado | `INF-12` | Completa |
| Seguridad del pipeline: codigo no confiable, permisos, acciones no fijadas (GCP 4.1 · AZ-400 · MCSB v2 DS · CICD-SEC-*) | `INF-13`..`INF-16` | Completa para GitHub Actions; declarado como parcial para otras plataformas en `traceability.md` |
| Escaneo automatizado de CVE en el pipeline y triaje (GCP 4.1) | `SUP-01`..`SUP-15` | Completa, con triaje por alcanzabilidad y KEV/EPSS |
| IaC como mecanismo de control, plantillas endurecidas, estado (AWS 6.2 · SC-500 controles por IaC) | `INF-17` + todo §1 | Completa para estado y separacion de entornos |
| Estrategia multi-cuenta / separacion dev-staging-prod (AWS 6.1) | `INF-17` | Parcial: cubre separacion, no cubre la capa de guardarrailes (hueco INF-24) |
| Exposicion de red efectiva, IP publicas, NetworkPolicy (AWS 3.2 segmentacion · GCP 2.2 aislamiento) | `INF-18` | Completa, con la puerta de `REQUIRES AUTHORIZATION` bien puesta |
| SSRF hacia el servicio de metadatos de instancia (GCP 3.1 "proteccion de metadatos de instancias") | `WEB-10` | Parcial: lado aplicacion si, lado infra (IMDSv2 obligatorio) no |
| Aislamiento multi-inquilino de datos (AWS 4.2 · privacidad) | `PRV-05` + `WEB-04` | Completa |
| Descubrimiento y clasificacion de datos (AWS 6.3 Macie · GCP 3.1 SDP · Purview) | `PRV-01` | Parcial: alcance repositorio/esquema, no almacenes no estructurados |
| Ciclo de vida y retencion de datos (AWS 5.3 · GCP 3.2 lifecycle) | `PRV-04` | Completa desde el angulo privacidad (se guarda de mas) |
| PII en logs y APM (MCSB v2 LT) | `PRV-09` | Completa |
| Transferencia de datos a terceros y a proveedores de IA (GCP 3.3 · SC-500 datos en cargas de IA) | `PRV-06`, `PRV-07` | Completa |
| Seguridad de aplicaciones y agentes de IA (SC-500 "implement security for AI" · MCSB v2 AI, capa aplicacion) | `AI-01`..`AI-22` | Completa en capa aplicacion. **No** cubre la infra del servicio de IA (hueco INF-26) |

---

## 2. Huecos (lo que el escuadron NO encuentra hoy)

### Severidad alta — con borrador de procedimiento (seccion 3)

1. **Escalada de privilegios IAM sin comodin** (`INF-19`). `INF-01` busca `"*"`. La escalada real de nube casi nunca lleva comodin: `iam:PassRole` a un rol concreto + `lambda:CreateFunction`; `iam.serviceAccounts.actAs` + desplegar en Cloud Build; un rol personalizado de Azure con `Microsoft.Authorization/roleAssignments/write`. Hoy el escuadron pasa por encima de una politica que en el papel es de minimo privilegio y en la practica es administrador. Es el hueco mas caro del pack.
2. **Servicios PaaS de datos publicados en internet sin ruta privada** (`INF-20`). `INF-04` mira reglas de firewall de red; `INF-18` mira IP publicas y Services de Kubernetes. Nadie mira `public_network_access_enabled`, `publicly_accessible`, `ipv4_enabled` + `authorized_networks 0.0.0.0/0`, ni la **ausencia** de private endpoint / Private Service Connect / VPC endpoint. Es el hallazgo numero uno de cualquier auditoria de nube real y hoy sale limpio.
3. **Puntos de entrada serverless/PaaS invocables sin autenticacion** (`INF-21`). `INF-02` conoce `allUsers` solo para buckets. Nadie mira `authorization_type = "NONE"` en Lambda Function URL o API Gateway, `roles/run.invoker` a `allUsers`, `authLevel: anonymous` en Azure Functions, App Service sin `auth_settings`. Es el equivalente de nube a un endpoint sin autenticacion, y el pack web no lo ve porque no esta en el codigo de la app.
4. **Gestion de claves y secretos: politica, rotacion y radio de explosion** (`INF-22`). `INF-03` verifica que el atributo `encrypted` este en `true`. Ninguna linea del corpus mira la politica de la clave KMS (principal comodin, sin condicion `kms:ViaService`), la rotacion, la ventana de borrado, `purge_protection_enabled` de Key Vault, ni el hecho de que la misma identidad administra la clave y lee el dato. Cifrado con una clave que todos pueden usar pasa todos los escaneres y protege exactamente de una amenaza: el robo fisico del disco.
5. **Backups, snapshots y traza de auditoria borrables por la identidad de la carga** (`INF-23`). `INF-06` menciona "bucket de logs sin object lock" de pasada y para nada mas. No hay procedimiento para inmutabilidad de respaldos, versionado, `management_lock`, ni para la pregunta que decide el impacto de un ransomware: *quien puede borrar esto*. El mapeo declara BCDR fuera de alcance salvo su configuracion — esto es exactamente esa configuracion.
6. **Ausencia de capa de guardarrailes organizacionales** (`INF-24`). `INF-01`, `INF-02` y `INF-04` usan "hay un SCP / Azure Policy / organization policy mas arriba" como descargo de falso positivo, y ningun procedimiento verifica que exista. El corpus se apoya en una capa que nunca audita. Sin SCP/RCP, sin Azure Policy en modo `Deny` a nivel de management group, sin `constraints/*` de GCP, el unico control que impide una mala configuracion es la revision de codigo.
7. **Registro de aplicacion / cliente OAuth: permisos, consentimiento y redirect URIs** (`INF-25`). AZ-500 y SC-500 lo listan por separado los dos. Nadie mira `required_resource_access` pidiendo roles de aplicacion de Graph tipo `Directory.ReadWrite.All`, redirect URIs con `http://` o comodin, `implicit_grant`, `sign_in_audience` multi-inquilino en una app interna. Una identidad de aplicacion comprometida con permisos de todo el tenant sobrevive a cualquier parche en el codigo.
8. **Servicio de IA gestionado con auth por clave, red publica y sin logging** (`INF-26`). El pack `ai-safety` termina en la capa de aplicacion (prompt, herramientas, memoria). SC-500 es literalmente la certificacion "Cloud and AI Security Engineer" y MCSB v2 anadio un dominio `AI` completo. Un `azurerm_cognitive_account` con `local_auth_enabled = true` y `public_network_access_enabled = true`, sin diagnostic setting y sin cuota, no lo ve nadie: ni infra (no tiene procedimiento) ni ai-safety (no mira IaC).
9. **Donde aterrizan fisicamente los datos personales y a donde se replican** (`PRV-12`). El pack de privacidad no tiene ni una linea sobre region, replicacion o servicios globales. `PRV-07` menciona "region de procesamiento" solo para el proveedor de IA. Es el unico control de privacidad que esta *escrito en el codigo* (`region =`, replicacion cruzada, tablas globales, Cosmos multi-region) y hoy se ignora.
10. **Leer datos personales no deja rastro** (`PRV-13`). Los logs de plano de datos estan apagados por defecto en los tres proveedores (data events de S3, `DATA_READ` en GCP, categorias de lectura en los diagnostic settings de Azure) y ademas cuestan dinero. `INF-06` audita el plano de control. Consecuencia operativa: tras un incidente nadie puede responder de quien se accedieron los datos, asi que hay que tratar a toda la poblacion como afectada. Incluye el caso interno, mas frecuente que el externo: el panel de soporte donde cualquier agente abre cualquier cuenta sin motivo registrado.

### Severidad media — sin borrador, con recomendacion de donde encajarlos

11. **Endurecimiento del servicio de metadatos de instancia**: `http_tokens = "required"` (IMDSv2), metadata concealment en GKE, `block-project-ssh-keys`. Complemento de infra a `WEB-10`. Recomendacion: ampliar el campo *Where to look* de `WEB-10` con el lado IaC, o una linea en `INF-20`. Sin esto, un SSRF confirmado por el pack web se reporta sin la mitigacion de infra que lo neutraliza.
12. **WAF presente pero en modo deteccion**: reglas gestionadas en `count`, sin regla de rate limit, WAF no asociado al recurso. Aplica a AWS WAF, Azure WAF y Cloud Armor. Peor que no tener WAF, porque genera falsa sensacion de cobertura. Recomendacion: procedimiento propio a futuro o variante dentro de `INF-20`.
13. **Credenciales de plano de datos**: claves de cuenta de almacenamiento, tokens SAS sin expiracion o con `sp=rwdl`, claves HMAC de GCS, connection strings de Cosmos/Service Bus/Redis. Recomendacion: ampliar `INF-05`, que hoy solo mira credenciales de despliegue y de CI.
14. **Verificacion de procedencia en el despliegue**: `SUP-12` cubre *producir* firma y atestacion; nadie cubre *exigirlas* en admision (Binary Authorization, Kyverno `verifyImages`, content trust de ACR, tags inmutables en ECR). Recomendacion: ampliar `SUP-12` o `INF-10`.
15. **Deriva: el IaC no es la realidad desplegada**. Todo el pack asume que el repositorio describe produccion. Sin deteccion de deriva ni politica que la impida, esa premisa puede ser falsa y las conclusiones no valen. Recomendacion: nota en `INF-17` y entrada obligatoria en `VER-07` ("lo que no se comprobo").
16. **Composicion de rutas de ataque**: encadenar los hallazgos individuales (ingreso publico -> identidad -> dato) en un camino extremo a extremo. Es la diferencia entre un listado de escaner y una auditoria. Recomendacion: no es un procedimiento de INF, es capa de lider/informe; encaja junto a `REM-07`.
17. **Seguridad a nivel de plataforma de base de datos**: autenticacion por Entra/IAM en lugar de contrasena, auditoria de base de datos, TDE con clave del cliente. Parcialmente en `INF-03` y `INF-06`. Recomendacion: ampliar ambos, no procedimiento nuevo.
18. **Descubrimiento automatizado sobre almacenes no estructurados**: sobreexposicion en repositorios de documentos, data lake, warehouse analitico. `PRV-01` es de esquema. Recomendacion: ampliar `PRV-01`.

### Severidad baja

19. Ciclo de vida de certificados (expiracion, autofirmados, CA privada). Parcial en `INF-03`.
20. Filtrado de salida a nivel de nube (Cloud NAT, restricted API access, egress firewall). Parcial en `INF-18` y `WEB-10`.
21. Nivel de proteccion DDoS y rate limit de borde. Solo se audita que exista; nunca se genera carga.
22. Secure boot, vTPM, integrity monitoring, computo confidencial. Casilla de endurecimiento con muy poca senal en una auditoria de codigo.
23. Estructura de landing zone / jerarquia de carpetas y management groups mas alla de la separacion de entornos. Parcial entre `INF-17` e `INF-24`.

---

## 3. Borradores de procedimientos nuevos (ingles, estilo exacto del pack)

> Numeracion: `INF-19`..`INF-26` continuan `infra-cloud.md`; `PRV-12`..`PRV-13` continuan `privacy-abuse.md`. Ojo al estilo: `infra-cloud.md` usa formato compacto con `\` al final de *Minimal test* y *Traceability*; `privacy-abuse.md` usa formato expandido con cada campo en su propia linea. Los borradores respetan cada uno.
>
> Nota de trazabilidad: los identificadores `MCSB v2 <DOMINIO>` (NS, IM, PA, DP, AM, LT, IR, PV, ES, BR, DS, AI) son citables como hechos, pero **exigen anadir una fila nueva a `references/traceability.md`** declarando el estandar, que v2 esta en preview y que la licencia no esta confirmada como abierta (repo `MicrosoftDocs/security-benchmark-docs-pr` es privado). Si esa fila no se anade, quitar los `MCSB v2 *` de los borradores antes de integrarlos.
>
> Secciones nuevas que hay que crear en `infra-cloud.md` y anadir al indice de carga selectiva: §7 Cloud identity and privilege paths (`INF-19`, `INF-25`), §8 Managed service exposure (`INF-20`, `INF-21`, `INF-26`), §9 Keys, backups and guardrails (`INF-22`, `INF-23`, `INF-24`). En `privacy-abuse.md`: §9 Data location (`PRV-12`), §10 Read traceability (`PRV-13`).

### INF-19 Privilege escalation paths in cloud IAM that need no wildcard

**Where to look**
- AWS: `iam:PassRole` next to a service that assumes the role (`ec2:RunInstances`, `lambda:CreateFunction` + `lambda:InvokeFunction`, `ecs:RegisterTaskDefinition`, `cloudformation:CreateStack`, `glue:CreateDevEndpoint`), and the verbs that rewrite authorization itself: `iam:CreatePolicyVersion`, `iam:SetDefaultPolicyVersion`, `iam:AttachUserPolicy`, `iam:PutRolePolicy`, `iam:UpdateAssumeRolePolicy`.
- GCP: `iam.serviceAccounts.actAs`, `roles/iam.serviceAccountUser`, `roles/iam.serviceAccountTokenCreator`, `roles/iam.workloadIdentityUser`, and deploy roles (`cloudbuild.builds.editor`, `cloudfunctions.developer`) bound to a service account more privileged than the caller.
- Azure: custom `azurerm_role_definition` carrying `Microsoft.Authorization/roleAssignments/write` or `roleDefinitions/write`, `Microsoft.ManagedIdentity/userAssignedIdentities/assign/action`, `Microsoft.Compute/virtualMachines/runCommand/action`; and permanent `azurerm_role_assignment` where an eligible, time-bound assignment was the design.
- Module inputs where the caller picks the role to attach: `iam_instance_profile = var.role`, `service_account { email = var.sa }`.

**Vulnerable pattern**
```hcl
statement {                                                    # no wildcard anywhere
  actions   = ["iam:PassRole"]
  resources = ["arn:aws:iam::111122223333:role/deploy-admin"]  # a concrete ARN: INF-01 sees nothing
}
statement {
  actions   = ["lambda:CreateFunction", "lambda:InvokeFunction"]
  resources = ["arn:aws:lambda:*:111122223333:function:build-*"]
}
# the identity cannot read the data; it can create a function that runs as one that can
```
**What rules it out (false positive)**
- `PassRole`/`actAs` is narrowed by a condition (`iam:PassedToService`, an `iam.serviceAccounts.actAs` binding scoped to one account) **and** the destination holds no permission the origin lacks: the path closes when the hop gains nothing.
- The escalating verb belongs to a platform identity whose job is issuing roles (the Terraform deploy identity, Config Connector, an ACK controller) running from a pipeline that already passes INF-13..INF-16: report it as concentrated risk with a named owner, not as a defect.
- Azure: the assignment is eligible with expiry and approval rather than permanent.

**Minimal test**: build the list of `(principal → action → role it can pass or impersonate)` from the `*.tf` files and find **one** pair where the destination holds permissions the origin lacks. One hop proves it; do not chase the whole graph. It is confirmed on documentation, and **executing the escalation is prohibited even inside the auditee's own account**.\
**Traceability**: `CWE-266` · `CWE-269` · `CWE-863` · `A01:2025` · `NIST 800-53 AC` · `CCM IAM` · `CIS v8.1 Control 6` · `MCSB v2 PA` · `ATT&CK T1098` · `ATT&CK T1078`\
**Tooling**: manual policy reading. `checkov` and `trivy config` are structurally blind here: the finding lives in two statements plus the contents of a role defined somewhere else, and neither resolves variables, remote modules or resources created outside the repo. A clean scan is not evidence of absence (VER-06).

### INF-20 PaaS data services published on the internet with no private path

**Where to look**
- Azure: `public_network_access_enabled = true` on `azurerm_storage_account`, `azurerm_key_vault`, `azurerm_cosmosdb_account`, `azurerm_mssql_server`; `network_rules`/`network_acls` with `default_action = "Allow"`; the SQL firewall rule from `0.0.0.0` to `0.0.0.0`; and no `azurerm_private_endpoint` anywhere in the repo.
- AWS: `publicly_accessible = true` on `aws_db_instance`/`aws_rds_cluster_instance`; OpenSearch or ElastiCache declared outside a VPC; bucket policies with no `aws:SourceVpce`/`aws:SourceVpc` condition; absence of `aws_vpc_endpoint` for the services the workload consumes.
- GCP: `google_sql_database_instance` with `ip_configuration.ipv4_enabled = true` and `authorized_networks` at `0.0.0.0/0`; no Private Service Connect or Private Google Access; no VPC Service Controls perimeter around the projects holding data.

**Vulnerable pattern**
```hcl
resource "azurerm_storage_account" "data" {
  public_network_access_enabled = true        # the data plane is on the internet
  network_rules { default_action = "Allow" }  # and the allow-list is empty
}                                             # no private endpoint declared anywhere
```
**What rules it out (false positive)**
- The service is reached only through a private endpoint / PSC / VPC endpoint declared in the same repo and public access is explicitly disabled. A resolvable DNS name is not exposure by itself.
- An authenticated gateway fronts it **and** the data plane keeps identity-based authorization plus an allow-list of the egress ranges: then it drops to defense in depth, and only if you can actually see the allow-list.
- The store holds public assets by design — that case belongs to INF-02, not here.

**Minimal test**: inventory every data resource in the repo and answer two questions per resource in writing: is public access off, and does a private path exist. `rg -n 'public_network_access_enabled|publicly_accessible|ipv4_enabled|default_action'` and diff the result against `rg -l 'private_endpoint|private_service_connect|vpc_endpoint|psc'`. Resolving the endpoint name or connecting to the port **REQUIRES AUTHORIZATION** under INF-18.\
**Traceability**: `CWE-1327` · `CWE-668` · `CWE-306` · `A01:2025` · `A02:2025` · `NIST 800-53 SC` · `CCM IVS` · `CIS v8.1 Control 12` · `MCSB v2 NS`\
**Tooling**: `trivy config . --skip-check-update --format sarif -o o.sarif` and `checkov -d . --framework terraform --skip-download --compact -o json` carry rules for `publicly_accessible` and for Azure network rules, but **neither detects the absence of a private endpoint**, which is the half that matters. Audit it by absence, the way INF-06 audits logging.

### INF-21 Serverless and PaaS entry points invocable with no authentication

**Where to look**
- AWS: `aws_lambda_function_url` with `authorization_type = "NONE"`; `aws_apigatewayv2_route` with `authorization_type = "NONE"` or no `authorizer_id`; `aws_lambda_permission` with `principal = "*"`; SNS/SQS policies with `Principal = "*"`.
- GCP: `google_cloud_run_service_iam_member` or `google_cloudfunctions2_function_iam_member` with `member = "allUsers"`; `ingress = "all"` on the Cloud Run service.
- Azure: `authLevel: "anonymous"` in `function.json`; `azurerm_linux_function_app`/`azurerm_windows_web_app` with no `auth_settings_v2` and `https_only = false`; a Logic App whose only credential is the SAS in the trigger URL; API Management APIs with no `subscription_required` and no JWT validation policy.

**Vulnerable pattern**
```yaml
# function.json
{ "bindings": [{ "type": "httpTrigger", "authLevel": "anonymous",
                 "methods": ["post"] }] }     # anonymous POST with a side effect
```
**What rules it out (false positive)**
- The handler authenticates in code — verify the handler, not the intent; WEB-01 and WEB-05 own that verification — and the public invocation is the deliberate design of a public API.
- It is a webhook receiver with signature verification (Stripe, GitHub) and the signature is checked **before** any side effect.
- The direct URL is disabled and traffic only arrives through a gateway that authenticates (`ingress = "internal-and-cloud-load-balancing"`, private endpoint, `aws_lambda_permission` scoped to the API Gateway ARN).

**Minimal test**: `rg -n 'authorization_type|allUsers|authLevel|auth_settings|subscription_required|ingress'` and, for every anonymous entry point found, open the handler and record whether it authenticates. Anonymity plus a side effect (write, send, spend) is a finding; anonymity on a health check is not. Invoking a live endpoint **REQUIRES AUTHORIZATION**.\
**Traceability**: `CWE-306` · `CWE-284` · `CWE-668` · `A01:2025` · `A02:2025` · `NIST 800-53 AC` · `CCM IAM` · `CIS v8.1 Control 4` · `MCSB v2 NS`\
**Tooling**: `checkov -d . --framework terraform` has rules for Lambda URL auth and for Cloud Run `allUsers`, and none for "the code behind it does not authenticate either" — which is the half that turns a hardening note into a finding. Cross-reference with WEB-05 (function-level authorization) and, if the endpoint returns data about people, with PRV-10.

### INF-22 Keys and secret stores: policy, rotation and the key's blast radius

**Where to look**
- AWS: `aws_kms_key_policy` with `Principal = "*"` or with the account `root` and no `kms:ViaService`/`kms:EncryptionContext` condition; `enable_key_rotation` absent or `false`; `deletion_window_in_days` at the minimum; `aws_secretsmanager_secret` with no `rotation_rules`; SSM parameters of type `String` holding credentials.
- Azure: `azurerm_key_vault` with `purge_protection_enabled = false`, `enable_rbac_authorization = false` plus legacy `access_policy` blocks granting `Get,List,Create,Delete,Purge` to an application, and network `default_action = "Allow"`; `azurerm_key_vault_key` with no `rotation_policy` and no `expiration_date`.
- GCP: `google_kms_crypto_key` with no `rotation_period`; `google_kms_crypto_key_iam_member` granting `roles/cloudkms.cryptoKeyEncrypterDecrypter` to `allAuthenticatedUsers` or to the very service account that holds the data; `google_secret_manager_secret_iam_member` with a broad member.
- Cross-cutting: the customer-managed key living in the same account/subscription/project as the data it protects, administered by the same identity that reads it.

**Vulnerable pattern**
```hcl
resource "aws_kms_key" "data" {
  enable_key_rotation = false            # the key never changes
}
resource "aws_kms_key_policy" "data" {
  policy = jsonencode({ Statement = [{
    Effect    = "Allow",
    Principal = { AWS = "arn:aws:iam::111122223333:root" },
    Action    = "kms:*", Resource = "*"  # every principal in the account can decrypt
  }] })
}
```
**What rules it out (false positive)**
- Delegating to the account `root` principal is the documented way to hand key authorization to IAM: it is a finding only when **no** IAM policy narrows who may use the key, or when the account is shared across environments (INF-17 tells you which case you are in).
- Rotation is driven outside the IaC by an auditable job **with evidence of the last rotation**; intent is not evidence.
- The provider rotates that key type automatically and the client does not require a customer-managed key: the finding then becomes the missing separation of duties, at lower severity.

**Minimal test**: for each key and each secret, answer three questions in writing — who can use it, who can administer it, when was it last rotated. If the first two answers name the same identity, the key is not a control. `rg -n 'enable_key_rotation|rotation_period|rotation_policy|purge_protection_enabled|deletion_window_in_days'` and list the key resources that do **not** appear. **Never authenticate with a secret you found** (INF-18, SUP-16).\
**Traceability**: `CWE-522` · `CWE-321` · `CWE-324` · `CWE-732` · `A02:2025` · `A04:2025` · `NIST 800-53 SC` · `CCM CEK` · `CIS v8.1 Control 3` · `MCSB v2 DP` · `ATT&CK T1552`\
**Tooling**: `checkov` covers rotation and purge protection as individual rules and misses the one that decides the outcome, the policy's blast radius; read the policy by hand. Argument to carry into the report, against INF-03: encryption at rest with a key everyone in the account can use passes every `encrypted = true` rule in every scanner and protects against exactly one threat, physical theft of the disk.

### INF-23 Backups, snapshots and audit trails the workload identity can delete

**Where to look**
- AWS: no `aws_s3_bucket_object_lock_configuration` on log and backup buckets, no `aws_backup_vault_lock_configuration`, versioning disabled, `aws_db_instance` with `backup_retention_period` at the minimum and `skip_final_snapshot = true`; IAM policies granting `s3:DeleteObject`, `backup:DeleteRecoveryPoint` or `rds:DeleteDBSnapshot` to the application role.
- Azure: `azurerm_storage_account` with no `delete_retention_policy` and no immutability policy; recovery services vaults with soft delete off; no `azurerm_management_lock` on production resource groups.
- GCP: buckets with no `retention_policy` (bucket lock) and no versioning; `google_sql_database_instance` with no `backup_configuration` or without point-in-time recovery.
- And the question that decides all of it in the three providers: **is the principal that writes the data the same one that can delete the backup and the log?**

**Vulnerable pattern**
```hcl
resource "aws_s3_bucket" "audit" {}   # destination for logs and backups
# no versioning, no object lock, and the application role holds s3:* on this bucket
```
**What rules it out (false positive)**
- Backups are written into a cross-account or cross-tenant vault the workload identity cannot reach, with separate credentials: that is the control, and immutability on top is depth rather than the finding.
- The retained data has a legally bounded life and immutability would collide with erasure obligations: say so, cross-reference PRV-04, and do not resolve the tension yourself.
- It is a non-production environment with synthetic data — confirm it, do not infer it from the resource name.

**Minimal test**: for every store holding data or logs, write down the answer to "which identity can delete this, and does deleting it leave a trace". Cross-reference the IaC IAM policies (INF-01, INF-19) against the backup and log destinations; the intersection is the finding. It is documentary: **delete nothing to demonstrate it**, and do not exercise restore procedures.\
**Traceability**: `CWE-732` · `CWE-693` · `CWE-778` · `A02:2025` · `A09:2025` · `NIST 800-53 CP` · `NIST 800-53 AU` · `CCM BCR` · `CIS v8.1 Control 11` · `MCSB v2 BR` · `ATT&CK T1485` · `ATT&CK T1490`\
**Tooling**: audited by absence, like INF-06; no scanner tells you that the same role writes and deletes. Framing for the report: elsewhere in this pack the argument is initial access, here it is impact — an incident with intact immutable backups is an outage, the same incident without them is a total loss. Stop there and do not drift into writing a recovery plan, which is outside the audit.

### INF-24 No organizational guardrail: the repository is the only thing stopping a bad configuration

**Where to look**
- AWS: `aws_organizations_policy` (service control and resource control policies) and their attachments; `aws_config_configuration_recorder` plus `aws_config_rule`; whether `aws_s3_account_public_access_block` exists at account level rather than per bucket.
- Azure: `azurerm_policy_definition`/`azurerm_policy_set_definition` and assignments with `Deny` or `DeployIfNotExists` effects at management-group scope; `azurerm_management_lock`; whether anything at all is assigned above the resource group.
- GCP: `google_org_policy_policy` for constraints such as public access prevention, service-account key creation, external IPs on VMs and public IPs on Cloud SQL; the folder and project hierarchy expressed in code.
- Symptom inside the repo: every false-positive discharge in INF-01, INF-02 and INF-04 leans on "there is a guardrail higher up" and nobody can point at the file where it lives.

**Vulnerable pattern**
```hcl
# Forty modules creating buckets, roles and networks,
# and not one policy that would fail the next module that gets it wrong.
```
**What rules it out (false positive)**
- The guardrails live in a separate platform repository and the auditee shows it to you. Then this is not a finding, and the valuable output is **the written list of which controls you verified there**, because the false-positive discharges in the rest of the pack rest on it.
- It is a sandbox account with no data and no path to production.

**Minimal test**: take the three riskiest findings you already produced and ask, for each one, which technical control would have stopped it before deployment. If the answer is "code review", there is no guardrail. `rg -n 'organizations_policy|policy_definition|policy_assignment|org_policy|config_rule|management_lock'`; an empty result in an infrastructure repository of any size is the finding.\
**Traceability**: `CWE-1188` · `CWE-284` · `A02:2025` · `NIST 800-53 CM` · `CCM GRC` · `CIS v8.1 Control 4` · `MCSB v2 PV`\
**Tooling**: `checkov` and `trivy config` evaluate one resource at a time and are structurally incapable of seeing this, because it is a missing layer rather than a bad attribute. If the client already runs a cloud posture product, ask for its policy assignment list instead of re-deriving it, and cite it as the auditee's own instrument — that is evidence, not our opinion.

### INF-25 Application registration and OAuth client: requested permissions, consent and redirect URIs

**Where to look**
- Entra: `azuread_application` → `required_resource_access` requesting Microsoft Graph **application** roles (`type = "Role"`, tenant-wide, no signed-in user) instead of delegated scopes; admin consent granted in code; `web.redirect_uris` over `http://`, with a wildcard host, or on a domain the auditee does not control; implicit grant enabled; `sign_in_audience` allowing personal or any-tenant accounts on an internal application; `azuread_application_password` living alongside an already-configured federated credential (INF-05).
- Google: OAuth client configuration and consent-screen scopes beyond `openid email profile`, and any restricted or sensitive scope with no feature behind it.
- The consumer side of the token — validating `iss`, `aud` and `tid` — belongs to WEB-01, not here; cross-reference rather than duplicating.

**Vulnerable pattern**
```hcl
resource "azuread_application" "api" {
  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000"           # Microsoft Graph
    resource_access { id = var.directory_readwrite_all, type = "Role" } # tenant-wide, app-only
  }
  web { redirect_uris = ["https://app.example.com/", "http://localhost:3000/"] }
}
```
**What rules it out (false positive)**
- The permission is delegated (`type = "Scope"`), so effective access is bounded by the rights of the signed-in user.
- The application permission is narrowed by a resource-scoped consent or an application access policy limiting it to a defined mailbox or site set: ask for it, because it is not visible in the registration.
- The `localhost` redirect URI belongs to a development registration with no production credential attached to it.

**Minimal test**: list every requested permission and answer, for each, which product feature needs it; a permission with no feature is a finding. For redirect URIs, any entry over `http`, with a wildcard, or on a domain the auditee does not control is a token delivery path to a third party. Documentary — **do not run the consent flow**, and reading the tenant's own grant inventory **REQUIRES AUTHORIZATION**.\
**Traceability**: `CWE-266` · `CWE-863` · `CWE-601` · `CWE-1188` · `A01:2025` · `A07:2025` · `NIST 800-53 AC` · `CCM IAM` · `MCSB v2 IM` · `ATT&CK T1528`\
**Tooling**: manual review; no IaC scanner judges whether a directory permission is excessive, because that requires knowing the product. Framing for the report: the application's identity is a first-class asset — a compromised registration holding tenant-wide permissions outlives every patch you apply to the code.

### INF-26 Managed AI service with key authentication, public network and no logging

**Where to look**
- Azure: `azurerm_cognitive_account` / AI Services with `local_auth_enabled = true` (static API key instead of managed identity) and `public_network_access_enabled = true`; no `azurerm_private_endpoint`; no `azurerm_monitor_diagnostic_setting`; no content-filter or guardrail configuration on the deployment; a gateway in front with no token quota or rate limit.
- AWS: Bedrock with no guardrail attached at invocation and model invocation logging disabled; SageMaker endpoints with `enable_network_isolation = false`; no VPC endpoint for the inference service.
- GCP: Vertex AI endpoints serving publicly; no VPC Service Controls perimeter around the project holding training data; the runtime service account holding an admin role on the AI platform.
- Cross-cutting: which identity calls the model, and whether its key lives in an environment variable (SUP-16, AI-11, AI-17).

**Vulnerable pattern**
```hcl
resource "azurerm_cognitive_account" "llm" {
  kind                          = "OpenAI"
  local_auth_enabled            = true   # one static key spends the whole quota
  public_network_access_enabled = true
}                                        # no diagnostic setting: no record of what was asked
```
**What rules it out (false positive)**
- Calls go through a gateway with managed identity, per-consumer quota and request logging, and key authentication is disabled on the resource itself.
- The model runs on first-party infrastructure with no public endpoint; the remaining risk then belongs to PRV-07 and to the `ai-safety` pack.

**Minimal test**: for every AI resource in the IaC answer four yes/no questions in writing — authenticated by key or by identity, reachable from the internet or not, logged or not, quota-bounded or not. Any prompt or response you capture may contain personal data: apply PRV-07 before pasting it into the report.\
**Traceability**: `CWE-306` · `CWE-1327` · `CWE-778` · `A02:2025` · `A09:2025` · `LLM02:2026` · `LLM06:2026` · `NIST 800-53 SC` · `CCM IVS` · `MCSB v2 AI`\
**Tooling**: IaC scanner coverage for AI resources is thin and moves fast; treat any rule as a hint, verify the attribute against the provider documentation, and record the provider version you read (`required_providers`). Do not report on the model's behavior from here — that is AI-01..AI-22, a different pack and a different test.

### PRV-12 Where the personal data physically lands, and where it is replicated

**Where to look**
- The `region`/`location` argument of every resource holding data, and the difference between the product's declared jurisdiction and the actual region of the primary store, the backups, the queues, the search index and the CDN
- Replication and global services: cross-region bucket replication, global tables, multi-region accounts, read replicas in another region, and the third parties from PRV-06 and PRV-07, whose processing region is a configuration setting rather than a property of the product

**Vulnerable pattern**
The product is described as operating in one jurisdiction and the code deploys the database in another; or the primary store is correct and the backups, logs and analytics events replicate to a second region nobody wrote down. The most common variant is the invisible one: the main database is regional and correct while the error tracker, the analytics platform and the model provider are global by default.

**What rules it out (false positive)**
- There is a written statement of where each category of data is stored and processed, it covers backups, logs and third parties, and it matches the code
- The data is not personal — PRV-01 decides that, not intuition

**Minimal test**
For every store in the PRV-01 inventory, write down four values: region of the primary, of the backup, of the replicas, and of the third parties that receive it. The finding is any store where the code disagrees with the declared statement, or where no statement exists. State the technical fact ("backups land in region X") and **do not rule on whether a transfer is lawful**: that depends on contracts and jurisdictions you cannot see — the second hard rule of this role applies in full.

**Traceability**: `CWE-359` · `CWE-200` · ASVS 5.0 V14 · `CCM DSP` · `MCSB v2 DP`
**Tooling**: `rg -n 'region|location\s*=' --glob '*.tf'` produces candidates and nothing else; the interesting part usually lives in a provider console (PRV-06, PRV-07), not in the repository. Declare in the report which third parties you could not check.

### PRV-13 Reading personal data leaves no trace

This procedure **overlaps with infra-cloud**: `INF-06` audits control-plane logging (who changed the infrastructure). This one covers the data plane (who read the record), which is a separate switch, off by default in the three major providers, and one that costs money. Report a single finding with both readings and cross-reference it, never two.

**Where to look**
- Whether data-plane read logging exists at all: object-level read events in the cloud trail, data-access audit logs enabled for `DATA_READ`, storage and database diagnostic settings with the read category turned on
- The application side: whether there is any record of which operator opened which person's record — admin panels, generated back offices, support tooling, direct database access from a bastion, BI tools reading a production replica
- Who can read that log, and whether the log itself now holds the personal data (PRV-09)

**Vulnerable pattern**
Every write is audited and no read is. After an incident nobody can answer the only question that matters to the affected people — whose data was accessed — so the whole population has to be treated as affected and notified as such. The internal variant is more frequent than the external one: a support tool where any agent can open any account, with no reason recorded and no entry written.

**What rules it out (false positive)**
- Read logging is enabled on the stores holding personal data, with retention that outlives a plausible detection window, and it is written where the reader cannot delete it (INF-23)
- Operator access to real data goes through a flow that records who, when and why, and the reviewer of that flow is not the same person who uses it

**Minimal test**
Take one personal field from the PRV-01 inventory and follow every path that reads it: application, admin panel, support tooling, analytics, direct database access. For each path state whether an entry is produced and where it goes. A path with no entry is the finding. Do not read real people's records to test this — the paths are read from the code and the configuration.

**Traceability**: `CWE-778` · `CWE-223` · `CWE-359` · `A09:2025` · ASVS 5.0 V16 · `CCM LOG` · `MCSB v2 LT`
**Tooling**: cross-reference with INF-06 and INF-23. Expect "it was disabled for cost" as the honest answer, because these logs are billed per event: report it as an accepted risk with a named owner and the incident-scoping consequence spelled out, not as an oversight.

---

## 4. Ruido descartado (lo que NO merece procedimiento, y por que)

1. **SC-200 completo** (gestion del entorno de operaciones, respuesta a incidentes, threat hunting con KQL, workbooks, notebooks, automation rules, case management, Security Copilot operativo) — operativa de SOC en vivo: no se lee desde un repositorio.
2. **AWS SCS-C02 Domain 1 completo** (plan de respuesta a incidentes, aislamiento de recursos comprometidos, captura forense, cuentas forenses) y la mitad analitica del **Domain 2** (Athena, Logs Insights, correlacion) — respuesta a incidentes y forense en caliente, fuera del alcance de una auditoria de codigo. Se conserva solo el lado configurable, que ya esta en `INF-06` y en el propuesto `INF-23`.
3. **GCP 4.2 en su parte de deteccion y respuesta** (Cloud IDS, Packet Mirroring, Security Command Center como consola) — misma razon.
4. **Productos de postura como productos**: Defender for Cloud, Secure Score, Security Hub, Security Command Center, Defender EASM, Defender Vulnerability Management, Defender for Servers/Storage/Databases/Containers, Security Exposure Management. Son el instrumento del defensor, no un procedimiento nuestro. Lo unico auditable — "el IaC no habilita ninguna postura ni logging" — ya vive en `INF-06`, y el uso correcto es *pedirle al cliente su salida* como evidencia (asi queda escrito en `INF-24`).
5. **Gestion de endpoints y flota**: Intune, Defender for Endpoint, EDR, reglas de attack surface reduction, Windows LAPS, baselines de cliente y servidor (SC-100, SC-200). No se lee desde el codigo del proyecto auditado.
6. **OT, ICS e IoT industrial** (Defender for IoT en SC-100) — ya declarado fuera de alcance en `traceability.md`; solo se conserva la configuracion de red que los aisla, que cae en `INF-04`/`INF-20`.
7. **Teoria y marcos de encuadre**: modelo de responsabilidad compartida, Zero Trust como concepto, Cloud Adoption Framework, Well-Architected Framework, MCRA, landing zones, las 7 areas del pilar de seguridad de AWS. Son vocabulario para el informe y, como mucho, filas de la matriz de trazabilidad. Un procedimiento de 6 campos sobre "adoptar Zero Trust" seria humo.
8. **Mecanica del examen y de la certificacion** (renovacion, reintentos, scoring, retiro de AZ-500 el 2026-08-31, sandbox) — informacion administrativa de la plataforma.
9. **Titulos de las 63 rutas de aprendizaje de Microsoft Learn del rol security engineer** — son el mapa de competencias que ya se explota como mapa; el contenido de las rutas ni se copia ni se resume (licencia) ni aporta procedimiento.
10. **Computo confidencial, secure boot, vTPM, integrity monitoring, cifrado doble de infraestructura** — endurecimiento de plataforma con casi nula senal en una auditoria de codigo y coste alto de linea en el pack.
11. **Dynamic Data Masking y funciones equivalentes presentadas como control de privacidad** — DDM no es una frontera de seguridad (una consulta autorizada la rodea). Proponer "falta DDM" seria fabricar un hallazgo debil; se descarta explicitamente para que nadie lo reintroduzca.
12. **BCDR, RTO/RPO, planes de recuperacion ante ransomware, restauracion** (SC-100) — fuera de alcance salvo la configuracion de proteccion de respaldos, que es exactamente `INF-23`.
13. **Diagnostico de red en vivo**: Network Watcher, Reachability Analyzer, Inspector Network Reachability, lectura de flow logs para troubleshooting. Requiere acceso a la cuenta; `INF-18` ya pone esa puerta detras de autorizacion escrita.
14. **Ejercicios de DDoS y de saturacion** (Shield, Azure DDoS Protection, Cloud Armor) — nunca se genera carga; solo se audita que la proteccion exista, y eso es una linea, no un procedimiento.
15. **Gestion de parches y de imagenes de VM** (EC2 Image Builder, Azure Machine Configuration, patch management de VM) — operacion de flota; el equivalente auditable en repositorio (fijar la imagen base por digest) ya es `INF-07`.
16. **Analisis de coste y recursos sin usar** (AWS Task 6.4, Trusted Advisor, Cost Explorer) — FinOps; la unica mitad relevante, reducir superficie de ataque, duplica el inventario que ya se hace.
17. **Federacion e identidad de directorio a nivel de tenant**: Google Cloud Directory Sync, super administrador, politica de contrasenas, 2SV, ciclo de vida de usuarios, B2B, identidad descentralizada, estaciones de trabajo de acceso privilegiado. Es administracion de tenant, no configuracion del proyecto auditado. Se conserva solo lo que vive en el codigo del proyecto: la identidad de la aplicacion (`INF-25`) y las identidades de carga (`INF-05`, `INF-19`).
18. **Conditional Access, PIM, access reviews y entitlement management como disciplina** — gobierno de identidad del tenant. Se conserva unicamente su reflejo en IaC: la asignacion permanente en vez de elegible, que entra como una linea de `INF-19`, no como procedimiento propio.

---

## 5. Advertencias para quien integre esto

- **No integrar los `MCSB v2 *` sin anadir antes la fila en `references/traceability.md`.** La licencia del benchmark no esta confirmada como abierta (el repo fuente es privado); citar identificadores de dominio es defendible, copiar descripciones no. Si hay duda, se quitan y no pasa nada: el resto de identificadores de cada borrador ya sostiene la trazabilidad.
- **Ningun borrador reproduce redaccion ajena.** Los nombres de recurso (`azurerm_cognitive_account`, `aws_kms_key_policy`, `roles/iam.serviceAccountUser`) son simbolos de API publica, no texto de curso.
- **Verificar los CWE nuevos antes de publicar**: `CWE-266`, `CWE-321`, `CWE-324`, `CWE-601`, `CWE-693`, `CWE-223` no aparecen hoy en el corpus. La politica de `traceability.md` es no inventar identificadores; quien integre debe confirmarlos en cwe.mitre.org y, si alguno no encaja, bajar a la categoria o quitarlo.
- **Tamano.** Diez procedimientos nuevos sobre 122 (+8%) para cuatro curriculos de nube completos. Los borradores anaden ~200 lineas a `infra-cloud.md` y ~60 a `privacy-abuse.md`; ambos packs tendran que actualizar su indice de carga selectiva y su linea de coste en la cabecera.
- **Nada de esto se escribio en el repo.** Este archivo es el entregable completo.
