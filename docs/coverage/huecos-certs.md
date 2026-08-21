# Análisis de cobertura — Certificaciones ofensivas y marco de competencias NICE

**Área:** Objetivos de certificaciones ofensivas y marco de competencias (PEN-200/OSCP, PenTest+ PT0-003, eCPPT, PNPT, NICE SP 800-181r1).
**Fecha:** 2026-08-11. **Modo:** solo lectura sobre el repo. Entregable exclusivo a scratchpad.
**Corpus medido:** 122 procedimientos (WEB-01..22, MOB-01..15, INF-01..18, SUP-01..20, AI-01..22, PRV-01..11, REM-01..07, VER-01..07) + `traceability.md`.

Criterio de cobertura aplicado: un tema está **cubierto** solo si un agente siguiendo el/los procedimientos citados **encontraría** el fallo. "El pack menciona X" no es cobertura.

---

## 1. Cubierto (tema del temario → procedimiento que ya lo caza)

| Tema del temario profesional | Procedimiento(s) |
|---|---|
| SQL Injection (PEN-200 / eCPPT 15% / PenTest+ web attacks) | WEB-07 |
| Command Injection (PEN-200 Common Web Attacks) | WEB-08 |
| Directory Traversal + File Upload (PEN-200) | WEB-12 |
| XSS (PEN-200 Intro Web Apps) | WEB-13, WEB-14 |
| Web Application Enumeration / methodology | WEB-05 |
| Initial Access: username enumeration + ausencia de rate limiting/lockout (eCPPT 15%) | WEB-03, WEB-18, PRV-10 |
| Reconnaissance activo/live (OffSec, PenTest+ 21%, eCPPT 10%) | INF-18 (REQUIRES AUTHORIZATION) |
| Vulnerability Scanning teoría + Nessus/Nmap | INF-18 + web-api §0 + VER-06 |
| Vulnerability discovery / result analysis (PenTest+ 17%) | SUP-13..15, web-api §0, VER-06 |
| Attacks & exploits: web (PenTest+ 35%) | WEB pack |
| Attacks & exploits: cloud | INF pack |
| Attacks & exploits: AI attacks | AI-01..22 (corpus va por delante: OWASP LLM/Agentic 2026) |
| Attacks & exploits: authentication (detección) | WEB-01, WEB-02, WEB-03 |
| Post-exploitation → subtema "Documentation" | VER-05, VER-07 (honestidad del informe) |
| NICE PD-WRL-007 Vulnerability Analysis: pentest autorizado / toolkits / controles coste-efectivos | núcleo del escuadrón + SUP-14 (KEV/EPSS) + REM pack |
| NICE DD-WRL-005 Software Security Assessment: code review / vuln de parches / EOL | corpus completo + SUP-02, SUP-13, SUP-14 |
| NICE OG-WRL-017 C-SCRM: validar artefactos genuinos/inalterados / C-SCRM en SDLC | SUP-11, SUP-12, SUP-20 |
| NICE OG-WRL-008 Privacy Compliance (parte técnica) | PRV-01..11 |
| NICE DD-WRL-007 Systems Testing & Evaluation | VER pack + REM-05 |
| NICE DD-WRL-003 Secure Software Development | REM pack + SSDF citado en SUP |
| NICE NF-COM-002 AI Security (parte de seguridad: poisoning, agentic, prompt injection) | AI pack |
| NICE NF-COM-008 DevSecOps (seguridad de pipeline) | INF-13..16, SUP-09..12 |
| NICE NF-COM-006 Cryptography (implementación) | WEB-19, INF-03, MOB-11 |
| NICE NF-COM-011 Supply Chain Security | SUP pack |
| NICE NF-COM-004 Cloud Security | INF pack |
| NICE NF-COM-001 Access Controls | WEB-04/05/06, INF-01/11, AI-05 |
| NICE OG-WRL-012 Security Control Assessment (verificar postura/config mgmt, defensivo) | VER pack + INF pack |

---

## 2. Huecos

### ALTA

**H1 — File inclusion y carga dinámica de código/módulos (LFI/RFI/dynamic require/import)**
Hoy un agente con WEB-12 detecta LECTURA por traversal y con WEB-09 detecta SSTI/eval, pero nadie busca `include()`/`require()`/`importlib.import_module`/`Class.forName` con dato del request. Se pierde una clase entera de RCE (CWE-98/CWE-829) que PEN-200, PenTest+ y eCPPT tratan como tema propio ("File Inclusion Vulnerabilities" es una viñeta distinta de traversal y de upload). → Propuesta **WEB-23**.

**H2 — Escalada de privilegios local por misconfiguración en imágenes y código de aprovisionamiento**
El pack infra cubre root-en-contenedor (INF-07/09/10) y RBAC k8s (INF-11), pero no SUID/SGID, world-writable, `sudoers` NOPASSWD/wildcard, cron/systemd timer con target escribible, ni unquoted service path / ACL débil de servicio en Windows. El escuadrón que audita Dockerfiles, Ansible, Chef, DSC y cloud-init deja pasar la condición de escalada local que OffSec (Windows + Linux Privilege Escalation) y PenTest+ (host-based attacks) tratan como núcleo. La parte estática es plenamente detectable en código. → Propuesta **INF-19**.

### MEDIA

**H3 — Redacción de informe: estructura profesional y portabilidad de evidencia**
VER-05/VER-07 cubren la HONESTIDAD del informe (cuatro estados, lo no verificado), pero no la ESTRUCTURA profesional: resumen ejecutivo, detalle técnico reproducible por hallazgo, portabilidad de notas y capturas, calificación de riesgo consistente. PNPT le asigna ~29% del tiempo de examen y PenTest+ lo mete en Engagement management (13%). No se propone procedimiento de 6 campos porque no es un "patrón vulnerable"; encaja como procedimiento de proceso estilo VER o como capa de orquestación del SKILL.

**H4 — Modelado de amenazas estructurado / revisión de diseño inseguro (A06:2025)**
La matriz de trazabilidad deja A06:2025 sin procedimiento propio ("leader — design review across packs"). No hay método estructurado de threat modeling (límites de confianza, DFD, árboles de ataque) que NICE DD-WRL-005 ("conduct threat modeling / develop threat models") y DD-WRL-001 (Cybersecurity Architecture) exigen. El escuadrón razona bottom-up (encuentra fallos) pero no top-down (evalúa el diseño). Metodología/leader; no se fuerza al formato de 6 campos.

**H5 — Detección de misconfiguración de infraestructura de identidad (AD/Entra)**
El temario mantiene explícitamente "SPN kerberoasteable con cifrado débil es hallazgo auditable" como IN-SCOPE. Hoy no hay procedimiento de identidad/directorio: INF-11 es RBAC de Kubernetes, no AD/Entra. Condiciones detectables: SPN kerberoasteable con etype débil, delegación no restringida (unconstrained), cuentas AS-REP roasteables (sin preauth), GPO con ACL débil, sprawl de grupos privilegiados. La superficie on-prem es live (authorization-gated), pero Entra ID vía Terraform `azuread_*` es estática y auditable. No se draftea: la mayor parte del hallazgo requiere host vivo y no es la superficie primaria del escuadrón.

**H6 — Alcance del engagement / reglas de compromiso / evidencia de autorización previa**
REM-06 y el "REQUIRES AUTHORIZATION" pervasivo cubren el límite reactivo, pero no hay procedimiento que formalice ANTES de empezar: alcance escrito, ventana, contacto, activos incluidos/excluidos, framing NIST SP 800-115. PenTest+ Engagement management (13%) lo pone primero, y PEN-200/PNPT lo colocan como Módulo 4 antes de todo módulo técnico. Metodología/orquestación.

**H7 — Criptografía a nivel de protocolo (cipher suites TLS, padding oracles, DH/certificado)**
Ya declarado en la matriz ("WSTG-CRYP-* beyond WEB-19"). WEB-19 cubre implementación (ECB, hash débil, CBC-sin-MAC, verify=False) pero no la postura de protocolo, que es test remoto (REQUIRES AUTHORIZATION, testssl.sh-style). Prioridad baja para procedimiento nuevo por ser remoto.

### BAJA

**H8 — Endurecimiento de autenticación de servicios de acceso remoto no-web (SSH/RDP/VPN/DB)**
WEB-03/WEB-18 cubren auth web. Para SSH/RDP/VPN/DB la exposición de puerto está en INF-04/INF-18, pero el endurecimiento de la autenticación del servicio (sshd_config `PasswordAuthentication`, RDP NLA, MFA de VPN, lockout) no tiene procedimiento. Solapa parcialmente con la propuesta INF-19 vía config en repo.

**H9 — OT/ICS/SCADA (código y config, impacto de seguridad física)**
La matriz declara ICS explícitamente fuera de alcance. NICE DD-WRL-009 / NF-COM-010 y PenTest+ lo incluyen. Si el escuadrón toca HMIs, handlers Modbus/MQTT o config de PLC, no hay procedimiento ni evaluación del "operational and safety impact" que pide PD-WRL-007. Se respeta la declaración de out-of-scope; se registra como hueco conocido y declarado.

**H10 — Higiene de cadena de suministro del propio tooling/PoC del auditor**
OffSec "Locating Public Exploits" subraya analizar el exploit ANTES de ejecutarlo. El escuadrón corre un toolset fijo y vetado, pero no hay regla explícita de vetar un PoC o binario descargado para verificar un hallazgo (no `curl|bash`, leer antes de correr) como extensión de AI-22. Frecuencia baja.

---

## 3. Procedimientos propuestos (borrador, 6 campos, estilo del corpus)

Ver objeto estructurado. Resumen: **WEB-23** (file inclusion / carga dinámica) y **INF-19** (escalada local por misconfig en imágenes/aprovisionamiento).

---

## 4. Ruido descartado (NO merece procedimiento)

- Introduction to Cybersecurity (CIA triad, principios, leyes/marcos, actores de amenaza) — teoría introductoria junior.
- Post-exploitation y lateral movement (PenTest+ 14%, AD lateral, DCSync, pass-the-hash) — ofensivo/destructivo, ya fuera de alcance; solo se conserva la detección de la condición (kerberoast → H5).
- AV/EDR evasion, tunneling/DPI bypass, egress bypass (PEN-200 M13/M17/M18, PNPT) — evasión de controles.
- Exploit development / memory corruption / buffer overflow (PEN-200 M12, eCPPT 5%) — weaponización.
- Client-side attacks / phishing / macros de Office (PEN-200 M10) — ingeniería social armada.
- Password hash dumping/cracking, pass/relay-the-hash (PEN-200 M14, eCPPT) — post-explotación de credenciales.
- Cyber Resiliency NF-COM-007 (anticipar/resistir/recuperar/adaptar) — resiliencia/BC-DR defensiva.
- Technology Program Auditing OG-WRL-016 (auditoría de programa, lenguaje contractual, import/export) — GRC/gestión.
- Privacy Compliance OG-WRL-008 governance/policy/incident-response — GRC; el pack PRV explícitamente no dictamina cumplimiento legal.
- AI bias/fairness, explainability, ML model evaluation, non-explainable risk (NF-COM-002) — responsible-AI/calidad de modelo, no seguridad ofensiva.
- Cybersecurity Architecture DD-WRL-001, Systems Security Analysis IO-WRL-006, Asset Management NF-COM-003 — arquitectura/ops/inventario de gestión; la parte técnica ya está en los packs.
- Collaboration/communication + legal/ethical compliance (PenTest+ engagement) — competencias de proceso.
- Passive OSINT footprinting (subdominios, datos de empleados) — recon externo remoto; los secretos filtrados ya están en SUP-16/17/18.
