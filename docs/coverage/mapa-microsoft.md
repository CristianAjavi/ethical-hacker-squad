# Mapa de currículo — Microsoft Learn y certificaciones de nube

Cartógrafo de currículo, área "Microsoft Learn y certificaciones de nube".
Fecha de extracción: 2026-08-11. Todas las páginas listadas fueron abiertas realmente (WebFetch / extracción local de PDF).

> **AVISO DE USO — LEER ANTES DE MOVER NADA A `ethical-hacker-squad`**
> Este archivo es un extracto de trabajo INTERNO. Contiene la redacción literal de objetivos de examen
> que son propiedad de Microsoft / AWS / Google. **NO puede copiarse al repo MIT.**
> Al repo solo puede viajar: (a) nombres de tema y de dominio, (b) códigos de examen y de objetivo,
> (c) la ESTRUCTURA del temario como hecho, (d) procedimientos redactados de cero por nosotros.
> Ver la sección "Licencias verificadas" al final.

---

## 0. Índice de fuentes abiertas

| # | Fuente | URL | Fecha del temario |
|---|--------|-----|-------------------|
| A | SC-200 Security Operations Analyst — study guide | https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/sc-200 | Skills measured as of **July 28, 2026** |
| B | AZ-500 Azure Security Technologies — study guide | https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/az-500 | Skills measured as of **January 22, 2026** — **el examen se retira el 31-ago-2026** |
| C | SC-500 Implementing End-to-End Security Controls for Cloud and AI Workloads — study guide | https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/sc-500 | Publicado 2026-04-26, actualizado 2026-07-31 (sucesor de facto de AZ-500) |
| D | SC-100 Cybersecurity Architect — study guide | https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/sc-100 | Skills measured as of **July 28, 2026** |
| E | Microsoft Cloud Security Benchmark v2 (preview) — dominios de control | https://learn.microsoft.com/en-us/security/benchmark/azure/overview | ms.date 2026-01-15, act. 2026-05-01 |
| F | Microsoft Learn — catálogo de learning paths, rol `security-engineer` | https://learn.microsoft.com/api/catalog/?locale=en-us&type=learningPaths&role=security-engineer | consultado 2026-08-11 (63 rutas) |
| G | Microsoft Learn — catálogo de certificaciones, rol `security-engineer` | https://learn.microsoft.com/api/catalog/?locale=en-us&type=certifications&role=security-engineer | consultado 2026-08-11 (6 certs) |
| H | Certificación Azure Security Engineer Associate (aviso de retiro) | https://learn.microsoft.com/en-us/credentials/certifications/azure-security-engineer/ | act. 2026-03-16 |
| I | AWS Certified Security – Specialty (SCS-C02) Exam Guide (PDF) | https://d1.awsstatic.com/training-and-certification/docs-security-spec/AWS-Certified-Security-Specialty_Exam-Guide_C02.pdf | Version 1.0 SCS-C02 |
| J | Google Cloud Professional Cloud Security Engineer — Certification exam guide (PDF) | https://cloud.google.com/learn/certification/guides/cloud-security-engineer → https://services.google.com/fh/files/misc/professional_cloud_security_engineer_exam_guide_english.pdf | sin número de versión en el PDF |
| K | AWS Well-Architected — Security Pillar (áreas de buenas prácticas) | https://docs.aws.amazon.com/wellarchitected/latest/framework/sec-bp.html y .../security-pillar/welcome.html | whitepaper 2024-11-06 |
| L | Microsoft Learn Terms of Use | https://learn.microsoft.com/en-us/legal/termsofuse | 2025-05-12 |
| M | LICENSE de MicrosoftDocs/azure-docs (CC BY 4.0) | https://raw.githubusercontent.com/MicrosoftDocs/azure-docs/main/LICENSE | — |
| N | AWS Site Terms (licencia de contenido) | https://aws.amazon.com/terms/ | — |
| O | Google site policies (licencia de contenido) | https://cloud.google.com/site-policies → https://developers.google.com/terms/site-policies | — |

Extractos crudos de los PDF (texto plano, uso interno):
`/private/tmp/.../scratchpad/curriculum/aws-raw.txt` (28.146 car.) y `gcp-raw.txt` (8.125 car.).

---

## A. SC-200 — Microsoft Security Operations Analyst
URL: https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/sc-200
Skills measured as of July 28, 2026. Nivel: Associate (intermediate).

**Skills at a glance**
- Manage a security operations environment (40–45%)
- Respond to security incidents (35–40%)
- Perform threat hunting (20–25%)

**Manage a security operations environment (40–45%)** — grupos funcionales:
- Configure automation for Microsoft Defender XDR and Microsoft Sentinel (notificaciones de incidentes; tuning/supresión/correlación de alertas; funciones avanzadas de Defender for Endpoint; reglas ASR; investigación y respuesta automatizadas; automatic attack disruption; grupos de dispositivos, permisos y niveles de automatización; automation rules; playbooks)
- Configure the Microsoft Sentinel SIEM and platform (roles de Sentinel; retención de datos en tiers Analytics / Data lake / XDR; workbooks; SOC optimization)
- Ingest data into the Microsoft Sentinel SIEM and platform (data connectors; Windows Security Events vía AMA y data collection rules; Windows Event Forwarding; Syslog/CEF vía AMA; Azure Policy + diagnostic settings; threat indicators; custom log tables)
- Configure detections (custom detection rules con Advanced Hunting; analytics rules — scheduled, NRT, threat intelligence, machine learning; cobertura de vectores con la matriz MITRE ATT&CK; anomalies)

**Respond to security incidents (35–40%)** — grupos funcionales:
- Respond to alerts and incidents in Microsoft Defender XDR (Defender for Office 365; entidades comprometidas identificadas por Purview; Defender for Cloud workload protections; Defender for Cloud Apps; identidades comprometidas en Entra ID; Defender for Identity; incidentes de Sentinel; investigación con IA agéntica / Security Copilot embebido; ataques multi-etapa, multi-dominio y movimiento lateral; case management)
- Respond to alerts and incidents in Microsoft Defender for Endpoint (device timelines; live response y paquetes de investigación; evidence & entity investigation; attack disruption)
- Investigate Microsoft 365 activities to identify threats (Purview Audit; Content search en Purview eDiscovery; Microsoft Graph activity logs)

**Perform threat hunting (20–25%)** — grupos funcionales:
- Detect threats by using Microsoft Defender XDR (elección de tabla KQL; KQL; Advanced Hunting queries; threat analytics; hunting graphs incl. blast radius; relaciones entre entidades con Sentinel Graph)
- Detect threats by using the Microsoft Sentinel platform (hunting queries; KQL jobs en Data lake; Summary rule tables; Notebooks incl. conexión al Sentinel MCP Server)

**Lectura de alcance:** SC-200 es mayoritariamente SOC en vivo (SIEM/XDR/IR). Ver sección "Separación de alcance".

---

## B. AZ-500 — Microsoft Azure Security Technologies  *(se retira 2026-08-31)*
URL: https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/az-500
Skills measured as of January 22, 2026. Aviso literal en la página: el examen y la certificación se retiran el **31 de agosto de 2026**.
Certificación asociada: https://learn.microsoft.com/en-us/credentials/certifications/azure-security-engineer/ (mismo aviso; **no nombra sucesor en esa página**).

**Skills at a glance**
- Secure identity and access (15–20%)
- Secure networking (20–25%)
- Secure compute, storage, and databases (20–25%)
- Secure Azure using Microsoft Defender for Cloud and Microsoft Sentinel (30–35%)

**Secure identity and access (15–20%)**
- Manage security controls for identity and access: asignaciones de roles integrados de Azure; roles personalizados (Azure y Entra); Privileged Identity Management para recursos de Azure; MFA para acceso a recursos de Azure; Conditional Access para recursos de nube.
- Manage Microsoft Entra application access and managed identities: acceso a enterprise applications incl. OAuth permission grants; app registrations; permission scopes de app registration; consentimiento de permisos; service principals; managed identities.

**Secure networking (20–25%)**
- Plan and implement security for virtual networks: NSG y ASG; Azure Virtual Network Manager; user-defined routes; peering y VPN gateway; Virtual WAN y secured virtual hub; VPN point-to-site y site-to-site; cifrado sobre ExpressRoute; firewall settings en recursos; Network Watcher.
- Plan and implement security for private access to Azure resources: Service Endpoints; Private Endpoints; Private Link services; integración de red para App Service y Functions; App Service Environment (ASE); Azure SQL Managed Instance.
- Plan and implement security for public access to Azure resources: TLS en App Service y API Management; Azure Firewall + Firewall Manager + firewall policies; Application Gateway; Front Door + CDN; Web Application Firewall; Azure DDoS Protection Standard.

**Secure compute, storage, and databases (20–25%)**
- Plan and implement advanced security for compute: acceso remoto a VM (Azure Bastion, JIT VM access); aislamiento de red de AKS; seguridad y monitoreo de AKS; autenticación de AKS; monitoreo de ACI y Container Apps; acceso a Azure Container Registry; cifrado de disco (ADE, encryption at host, confidential disk encryption); configuraciones de seguridad de API Management.
- Plan and implement security for storage: control de acceso de storage accounts; access keys; métodos de acceso a Azure Files y a Blob Storage; protección frente a amenazas de datos (soft delete, backups, versioning, immutable storage); BYOK; double encryption a nivel de infraestructura de Storage.
- Plan and implement security for Azure SQL Database y SQL Managed Instance: autenticación con Entra; database auditing; dynamic masking; Transparent Data Encryption (TDE); Always Encrypted.

**Secure Azure using Microsoft Defender for Cloud and Microsoft Sentinel (30–35%)**
- Implement and manage enforcement of cloud governance policies: Azure Policy (policies e initiatives); Key Vault network settings; acceso a Key Vault (vault access policies y Azure RBAC); certificados/secretos/claves; key rotation; backup y recuperación de certificados/secretos/claves; controles de seguridad para proteger backups; controles de seguridad de asset management.
- Manage security posture by using Microsoft Defender for Cloud: Secure Score e Inventory; cumplimiento contra marcos de seguridad; compliance standards; custom standards; conexión de entornos híbridos y multinube (AWS y GCP); Defender External Attack Surface Management (EASM).
- Configure and manage threat protection by using Defender for Cloud: cloud workload protection plans; Defender for Servers / Databases / Storage; agentless scanning de VM; Defender Vulnerability Management para VM de Azure; Defender for Cloud DevOps Security con GitHub, Azure DevOps y GitLab.
- Configure and manage security monitoring and automation solutions: alertas de Defender for Cloud; workflow automation; data collection rules (DCR) en Azure Monitor; data connectors, analytics rules y automation en Sentinel.

---

## C. SC-500 — Implementing End-to-End Security Controls for Cloud and AI Workloads  *(sucesor)*
URL: https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/sc-500
Certificación: **Microsoft Certified: Cloud and AI Security Engineer Associate**
(`certification.cloud-and-ai-security-engineer-associate`, confirmada en el catálogo, fuente G).
La página SC-500 **no dice literalmente "reemplaza a AZ-500"**; la sucesión se infiere de tres hechos verificados:
AZ-500 se retira el 31-ago-2026 (fuente B/H), SC-500 aparece con fecha 2026-04-26 y la misma familia de temario,
y su bloque "Find a video" todavía apunta a `?terms=AZ-500`. **Marcado como inferencia, no como hecho publicado.**

**Skills at a glance**
- Manage identity, access, and governance (20–25%)
- Secure storage, databases, and networking (25–30%)
- Secure compute (20–25%)
- Manage and monitor security posture (20–25%)

**Manage identity, access, and governance (20–25%)**
- Secure access to resources by using Microsoft Entra ID: PIM; conditional access policies; métodos de autenticación incl. MFA y passwordless; identidad para aplicaciones (enterprise applications y app registrations); OAuth permission grants y consent settings; managed identities.
- Secure secrets and keys by using Azure Key Vault: despliegue de Key Vault; settings; acceso; firewall settings; claves/secretos/certificados; **escaneo de secretos con Defender CSPM**; Defender for Key Vault.
- Implement governance to enforce security and regulatory compliance: Azure Policy con definiciones **built-in y custom**; cumplimiento regulatorio con Defender for Cloud; security standards y recommendations en Defender for Cloud; **resource locks**; roles integrados y personalizados (Azure y Entra); **evaluar y remediar asignaciones sobre-privilegiadas vía Azure RBAC**; controles de seguridad de backup con Azure Backup; **controles de seguridad implementados con infraestructura como código**.

**Secure storage, databases, and networking (25–30%)**
- Implement security for storage accounts: seguridad de cuentas de almacenamiento; Azure Storage firewall rules; Defender for Storage; acceso a storage incl. access policies.
- Implement security for databases: configuraciones de seguridad a nivel de plataforma en Azure SQL; auditing en Azure SQL Database y Managed Instance; Defender for Databases.
- Implement security for Azure network services: NSG y ASG; políticas de acceso de red con Azure Virtual Network Manager; seguridad de Azure Virtual WAN; VPN; **Microsoft Entra Private Access**; private endpoints hacia PaaS; Private Link services; Azure Firewall; **evaluación de reglas efectivas con Network Watcher diagnostics**.

**Secure compute (20–25%)**
- **Implement security for AI** (bloque nuevo, sin equivalente en AZ-500): sobreexposición de datos en SharePoint; riesgos de Microsoft Copilot y apps de IA con **Purview Data Security Posture Management (DSPM)**; protección en tiempo real para agentes de Copilot Studio; **conditional access para Microsoft Entra Agent ID**; **análisis de blast radius de riesgos de Entra Agent ID con Defender XDR**; gestión de acceso de Entra Agent ID; **AI Gateway en Azure API Management para Microsoft Foundry**; Defender for AI Service en Cloud Workload Protection; **guardrails de seguridad de agentes en Foundry**; dashboard de seguridad de Data & AI en Defender for Cloud; gestión de agentes en el centro de administración de Microsoft 365.
- Implement security for servers and virtual machines: cifrado de disco; Azure Bastion; JIT VM access; extensión de controles a servidores híbridos y multinube con Azure Arc; onboarding a Defender for Servers; vulnerability scanning y EDR; agentless scanning; **secure boot, vTPM, integrity monitoring y security type**; **Azure Machine Configuration** para forzar configuración.
- Implement security for application platform services: **Defender for Containers** (misconfiguraciones y riesgos en runtime); AKS; Azure Container Registry; Container Instances y Container Apps; **Azure Functions incl. autenticación y acceso de red**; **Azure Logic Apps**; App Service; Azure Web Application Firewall; **políticas de protección de APIs de back-end con API Management**.

**Manage and monitor security posture (20–25%)**
- Manage security posture by using Defender for Cloud: riesgos con Defender CSPM; cumplimiento contra marcos; workload protection plans; conexión de híbrido y multinube (AWS, GCP); Defender Vulnerability Management para VM; **descubrimiento de activos no protegidos con Defender EASM**.
- Implement activity and event collection in Microsoft Sentinel: workspaces; roles; content hub solutions; data connectors; syslog y CEF; Windows Security events con DCR y WEF; custom log tables; automation rules y playbooks; retención; consulta de Purview Audit en Defender XDR.
- Implement Microsoft Security Copilot: workspaces; permisos y roles; plugins; agentes de Microsoft y de Security Store.

---

## D. SC-100 — Microsoft Cybersecurity Architect
URL: https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/sc-100
Skills measured as of July 28, 2026. Nivel: Expert.

**Skills at a glance**
- Design solutions that align with security best practices and priorities (20–25%)
- Design security operations, identity, and compliance capabilities (25–30%)
- Design security solutions for infrastructure (25–30%)
- Design security solutions for applications and data (20–25%)

**Design solutions that align with security best practices and priorities (20–25%)**
- Design a resiliency strategy for ransomware and other attacks based on Microsoft Security Best Practices: estrategia alineada a resiliencia del negocio con priorización de amenazas a activos críticos; BCDR con backup y restore seguros en híbrido y multinube; mitigación de ransomware priorizando BCDR y acceso privilegiado; evaluación de soluciones de actualizaciones de seguridad.
- Design solutions that align with MCRA and MCSB: capacidades y controles; protección frente a ataques internos, externos y **de cadena de suministro**; **diseño de soluciones de IA alineadas al MCSB**; Zero Trust adoption framework.
- Design solutions that align with CAF y Azure Well-Architected Framework: estrategia de adopción segura de IA; estrategia de seguridad y gobierno según CAF y WAF; Azure landing zones; **proceso DevSecOps alineado a CAF**.

**Design security operations, identity, and compliance capabilities (25–30%)**
- Design solutions for security operations: detección y respuesta con XDR y SIEM; **logging y auditoría centralizados incl. Purview Audit**; monitoreo híbrido y multinube; SOAR; flujos de trabajo de IR, threat hunting e incident management; **cobertura de detección con matrices MITRE ATT&CK — Enterprise, Mobile e ICS**.
- Design solutions for identity and access management: **identidades de agentes con Microsoft Entra Agent ID y conditional access**; acceso a SaaS/PaaS/IaaS/híbrido/multinube con controles de identidad, red y aplicación; Entra ID en híbrido y multinube; identidades externas B2B e **identidad descentralizada**; **estrategia moderna de autenticación y autorización: Conditional Access, continuous access evaluation, risk scoring y protected actions**; validación de alineación de CA con Zero Trust; **endurecimiento de AD DS**; **gestión de secretos, claves y certificados**.
- Design solutions for securing privileged access: **enterprise access model** para asignar y delegar roles privilegiados; gobierno de Entra ID con PIM, entitlement management y access reviews; gobierno de AD DS y resiliencia frente a ataques comunes; administración segura de tenants de nube; **cloud infrastructure entitlement management (CIEM)**; solución de access review; **estaciones de trabajo seguras para acceso privilegiado (PAW) incl. acceso remoto**.
- Design solutions for regulatory compliance: **traducir requisitos de cumplimiento a controles de seguridad**; Purview; **Azure Policy para requisitos de seguridad y cumplimiento**; validación de alineación con estándares y benchmarks vía Defender for Cloud.

**Design security solutions for infrastructure (25–30%)**
- Design solutions for security posture management in hybrid and multicloud environments: Defender for Cloud + MCSB; Microsoft Secure Score; CSPM integrado en híbrido y multinube; cloud workload protection; **Azure Arc**; **Defender EASM**; **Microsoft Security Exposure Management: attack paths, attack surface reduction, security insights e initiatives**.
- Specify requirements for securing server and client endpoints: requisitos para servidores multi-plataforma y multi-SO; dispositivos móviles y clientes (endpoint protection, hardening, configuración); **IoT y sistemas embebidos**; **OT e ICS con Defender for IoT**; **security baselines** para endpoints de servidor y cliente; **Windows LAPS**.
- Specify requirements for securing SaaS, PaaS, and IaaS services: **security baselines para SaaS/PaaS/IaaS**; cargas IoT; **cargas web**; **contenedores**; **orquestación de contenedores**; **seguridad de Azure AI services**.
- Evaluate solutions for network security and Security Service Edge (SSE): diseños de red alineados a requisitos y buenas prácticas; **Microsoft Entra Internet Access como secure web gateway**; Entra Internet Access para servicios de Microsoft incl. configuraciones cross-tenant; **Microsoft Entra Private Access**.

**Design security solutions for applications and data (20–25%)**
- Evaluate solutions for securing Microsoft 365: postura de cargas de productividad y colaboración con métricas incl. Secure Score; Defender for Office 365 y Defender for Cloud Apps; Microsoft Intune; **protección de datos en M365 con Purview**; **controles de seguridad y cumplimiento de datos en Microsoft Copilot for Microsoft 365**.
- Design solutions for securing applications: **evaluar la postura de seguridad de portafolios de aplicaciones existentes**; **threat modeling de aplicaciones críticas de negocio**; **estrategia de seguridad de aplicaciones de ciclo de vida completo**; **estándares y prácticas para asegurar el proceso de desarrollo**; mapeo de tecnologías a requisitos de seguridad de aplicación; **workload identities** para autenticar y acceder a recursos de Azure; **API management y seguridad de APIs**; Azure WAF.
- Design solutions for securing an organization's data: **descubrimiento y clasificación de datos**; priorización de amenazas a datos; **cifrado en reposo y en tránsito incl. Key Vault e infrastructure encryption**; **seguridad de datos usados en cargas de IA**; datos en Azure SQL, Synapse Analytics y Cosmos DB; datos en Azure Storage; Defender for Storage y Defender for Databases.

---

## E. Microsoft Cloud Security Benchmark v2 (preview) — catálogo de dominios de control
URL: https://learn.microsoft.com/en-us/security/benchmark/azure/overview
Es el catálogo de controles que SC-100, SC-500 y AZ-500 citan como referencia normativa.
v2 supersede a v1; incluye >420 definiciones built-in de Azure Policy.

| ID | Dominio |
|----|---------|
| NS | Network Security |
| IM | Identity Management |
| PA | Privileged Access |
| DP | Data Protection |
| AM | Asset Management |
| LT | Logging and Threat Detection |
| IR | Incident Response |
| PV | Posture and Vulnerability Management |
| ES | Endpoint Security |
| BR | Backup and Recovery |
| DS | DevOps Security |
| **AI** | **Artificial Intelligence Security** (dominio nuevo en v2: AI platform security, AI application security, AI security monitoring — 7 recomendaciones) |

**Estructura de cada control** (muy relevante como plantilla de procedimiento, y muy cercana a nuestros 6 campos):
`ID` (p.ej. NS-2, DP-1, AI-1) · `Azure Policy` (definición built-in que lo mide) · `Security principle` (qué y por qué, agnóstico de tecnología) · `Risk to mitigate` · `MITRE ATT&CK` (TTPs) · `Implementation guidance` (sub-secciones numeradas NS-1.1, NS-1.2…) · `Implementation example` · `Criticality level` (Must have / Should have / Nice to have) · `Control Mapping` a NIST SP 800-53 Rev.5, PCI-DSS v4, CIS Controls v8.1, NIST CSF v2.0, ISO/IEC 27001:2022 y SOC 2.

---

## F. Microsoft Learn — rutas de aprendizaje del rol `security-engineer` (63 learning paths)
URL: https://learn.microsoft.com/api/catalog/?locale=en-us&type=learningPaths&role=security-engineer
Se citan título y `uid` (identificadores, hechos). Agrupación por tema hecha por nosotros.

**Identidad y acceso**
- Manage identity and access in Microsoft Entra ID — `learn.security.manage-identity-and-access`
- Secure access to resources by using Microsoft Entra — `learn.wwl.secure-access-resources-entra`
- Protect identity and access in Azure — `learn.wwl.secure-identity-access`
- Implement an identity management solution using Microsoft Entra ID — `learn.wwl.implement-identity-management-solution`
- Implement an authentication and access management solution — `learn.wwl.implement-authentication-access-management-solution`
- Implement access management for apps — `learn.wwl.implement-access-management-for-apps`
- Plan and implement an identity governance strategy — `learn.wwl.plan-implement-identity-governance-strategy`
- Active Directory Domain Services — `learn.wwl.active-directory-domain-services`
- Learn how Microsoft supports using multifactor authentication as part of a cybersecurity solution — `learn-m365.cybersecurity-multifactor-authentication`

**Postura de configuración de nube y gobierno**
- Manage security posture by using Microsoft Defender for Cloud — `learn.wwl.manage-security-posture-defender-cloud`
- Strengthen security posture using Microsoft Defender for Cloud and Microsoft Sentinel — `learn.wwl.secure-azure-using-microsoft-defender-cloud-sentinel`
- Secure Azure services and workloads with Microsoft Defender for Cloud regulatory compliance controls — `learn.wwl.secure-azure-services-workloads-defender-cloud`
- Enforce security governance and regulatory compliance — `learn.wwl.security-governance-compliance`
- Implement resource management security in Azure — `learn.security.implement-resource-mgmt-security`
- Perform basic Azure Management Tasks (Security and Monitoring) — `learn.wwl.perform-basic-azure-management-tasks`

**Cifrado y gestión de claves / secretos**
- Secure Azure Key Vault with defense in depth for the cloud and AI workloads — `learn.wwl.configure-key-vault-security`

**Seguridad de red**
- Protect network infrastructure in Azure — `learn.wwl.secure-networking`
- Implement network security controls in Azure — `learn.wwl.implement-network-security-controls-azure`
- Manage Network Access for AI workloads — `learn.wwl.manage-network-access-ai-workloads`

**Cómputo, almacenamiento, datos, plataformas de aplicación**
- Implement security for servers and virtual machines — `learn.wwl.server-vm-security`
- Protect compute, storage, and databases — `learn.wwl.secure-compute-storage-databases`
- Implement security for Azure Storage for the cloud and AI security engineer — `learn.wwl.implement-azure-storage-security`
- Implement security for Azure SQL databases — `learn.wwl.implement-azure-sql-database-security`
- Secure Azure application platform services for the cloud and AI security engineer — `learn.wwl.secure-application-platform-services`
- Windows Server file servers and storage management — `learn.wwl.windows-server-file-servers-storage-management`
- Windows Server Hyper-V and Virtualization — `learn.wwl.windows-server-hyper-v-virtualization`
- Windows Server high availability — `learn.wwl.windows-server-high-availability`

**Gobierno de datos / clasificación**
- Learn how Microsoft supports data discovery, classification, and protection as part of a cybersecurity solution — `learn-m365.cybersecurity-data`
- MS-101 Manage content search and investigations in Microsoft 365 — `learn.wwl.manage-content-search-investigations-microsoft-365`
- AI workload governance and DLP — `learn.wwl.ai-workloads-governance`

**Seguridad de IA / agentes** (bloque que el mercado ya considera currículo estándar)
- Implement security for AI — `learn.wwl.implement-ai-security`
- AI security fundamentals — `learn.ai-security-fundamentals`
- Secure AI identity infrastructure with Microsoft Entra — `learn.wwl.entra-ai-secure-workloads`
- Manage Authentication, Authorization, and RBAC for AI workloads on Azure — `learn.manage-iam-for-ai-workloads-on-azure`
- Monitor AI workloads on Azure — `learn.monitor-ai-workloads-on-azure`
- Protect Microsoft Foundry solutions by using Microsoft Defender for Cloud — `learn.wwl.defender-for-cloud-ai-foundry-protect`
- AI Center of Excellence — `learn.ai-center-excellence`

**DevSecOps / cadena de suministro / SDL**
- Implement security through a pipeline using Azure DevOps — `learn.wwl.implement-security-through-pipeline-using-devops`
- AZ-400: Implement security and validate code bases for compliance — `learn.wwl.az-400-implement-security-validate-code-basescompliance`
- AZ-400: Design and implement a dependency management strategy — `learn.wwl.az-400-design-implement-dependency-management-strategy`
- AZ-400: Implement a secure continuous deployment using Azure Pipelines — `learn.wwl.az-400-implement-secure-continuous-deployment`
- AZ-400: Implement CI with Azure Pipelines and GitHub Actions — `learn.wwl.az-400-implement-ci-azure-pipelines-github-actions`
- AZ-400: Manage infrastructure as code using Azure and DSC — `learn.wwl.az-400-manage-infrastructure-as-code-using-azure`
- AZ-400: Design and implement a release strategy — `learn.wwl.az-400-design-implement-release-strategy`
- AZ-400: Development for Enterprise DevOps — `learn.wwl.az-400-work-git-for-enterprise-devops`
- AZ-400: Implement continuous feedback — `learn.wwl.az-400-implement-continuous-feedback`
- Develop a security and compliance plan — `learn.az-400-develop-security-compliance-plan`
- Learn how Microsoft supports secure software development as part of a cybersecurity solution — `learn-m365.cybersecurity-secure-software`
- Design and Implement Platform Engineering — `learn.wwl.designing-implementing-platform-engineering`
- DevOps foundations: The core principles and practices — `learn.wwl.devops-foundations-core-principles-practices`
- Introduce DevOps Dojo: Create efficiencies that support your business — `learn.wwl.devops-dojo-white-belt-foundation`

**Modelado de amenazas**
- Threat Modeling Security Fundamentals — `learn.security.tm-threat-modeling-fundamentals`

**Arquitectura (SC-100)**
- Design solutions that align with security best practices and priorities — `learn.wwl.sc-100-design-solutions-best-practices-priorities`
- Design security operations, identity, and compliance capabilities — `learn.wwl.sc-100-design-operations-identity-compliance-capabilities`
- Design security solutions for infrastructure — `learn.wwl.sc-100-design-security-solutions-infrastructure`
- Design security solutions for applications and data — `learn.wwl.sc-100-design-security-solutions-applications-data`

**Endpoint / SOC / Copilot (fuera de nuestro alcance de auditoría de código, se listan por completitud)**
- Enhance endpoint security with Microsoft Intune and Microsoft Security Copilot — `learn.wwl.enhance-endpoint-security-microsoft-intune-copilot`
- Deploy and operate Microsoft Security Copilot — `learn.wwl.deploy-operate-security-copilot`
- Enhance security operations by using Microsoft Security Copilot — `learn.wwl.security-copilot-and-ai`
- Implement activity and event collection in Microsoft Sentinel — `learn.wwl.implement-activity-event-collection-sentinel`
- Monitor hybrid virtual machines, containers, and network resources — `learn.monitor-hybrid-virtual-machines-containers-network`
- Extend endpoint capabilities using Microsoft Intune Suite — `learn.wwl.extend-intune-suite`
- Protect devices using Microsoft Intune — `learn.wwl.protect-devices-intune`

## G. Certificaciones del rol `security-engineer` en el catálogo (6)
URL: https://learn.microsoft.com/api/catalog/?locale=en-us&type=certifications&role=security-engineer
- Microsoft Certified: Identity and Access Administrator Associate — `certification.identity-and-access-administrator`
- Microsoft Certified: Windows Server Hybrid Administrator Associate — `certification.windows-server-hybrid-administrator` (exámenes AZ-800, AZ-801)
- **Microsoft Certified: Cloud and AI Security Engineer Associate** — `certification.cloud-and-ai-security-engineer-associate` (SC-500)
- Microsoft Certified: Azure Security Engineer Associate — `certification.azure-security-engineer` (AZ-500, se retira 31-ago-2026)
- Microsoft Certified: Cybersecurity Architect Expert — `certification.cybersecurity-architect-expert` (SC-100)
- Microsoft Certified: Security, Compliance, and Identity Fundamentals — `certification.security-compliance-and-identity-fundamentals` (SC-900)

---

## I. AWS Certified Security – Specialty (SCS-C02)
URL del PDF: https://d1.awsstatic.com/training-and-certification/docs-security-spec/AWS-Certified-Security-Specialty_Exam-Guide_C02.pdf
Version 1.0 SCS-C02. 50 preguntas puntuadas + 15 no puntuadas; aprobación 750/1000.

**Dominios y pesos**
| Dominio | % |
|---|---|
| Domain 1: Threat Detection and Incident Response | 14% |
| Domain 2: Security Logging and Monitoring | 18% |
| Domain 3: Infrastructure Security | 20% |
| Domain 4: Identity and Access Management | 16% |
| Domain 5: Data Protection | 18% |
| Domain 6: Management and Security Governance | 14% |

**Domain 1 — Threat Detection and Incident Response**
- Task 1.1 Design and implement an incident response plan (buenas prácticas AWS de IR; incidentes de nube; roles y responsabilidades; **AWS Security Finding Format (ASFF)**; invalidación/rotación de credenciales ante compromiso con IAM y Secrets Manager; aislamiento de recursos; playbooks y runbooks; despliegue de Security Hub, Macie, GuardDuty, Inspector, AWS Config, Detective, IAM Access Analyzer; integraciones con EventBridge y ASFF).
- Task 1.2 Detect security threats and anomalies by using AWS services (servicios gestionados de detección; técnicas de anomalía y correlación entre servicios; visualizaciones; centralización de findings; consultas de validación con Athena; metric filters y dashboards con CloudWatch).
- Task 1.3 Respond to compromised resources and workloads (AWS Security Incident Response Guide; mecanismos de aislamiento; análisis de causa raíz; captura de datos; automatización de remediación con Lambda, Step Functions, EventBridge, Systems Manager runbooks, Security Hub, AWS Config; **captura forense: snapshots de EBS, memory dump**; consulta de logs en S3 con Athena; **preservación de artefactos forenses con S3 Object Lock, cuentas forenses aisladas, S3 Lifecycle y replicación**).

**Domain 2 — Security Logging and Monitoring**
- Task 2.1 Design and implement monitoring and alerting to address security events (CloudWatch, EventBridge; automatización de alertas con Lambda, SNS, Security Hub; GuardDuty y Systems Manager para métricas y líneas base; **análisis de arquitecturas para identificar requisitos y fuentes de datos de monitoreo**; **custom insights en Security Hub**; definición de métricas y umbrales).
- Task 2.2 Troubleshoot security monitoring and alerting (por qué un evento no dio visibilidad ni alerta: funcionalidad, permisos y configuración; aplicación custom que no reporta estadísticas; alineación de servicios de logging/monitoring con requisitos).
- Task 2.3 Design and implement a logging solution (**VPC Flow Logs, DNS logs, CloudTrail, CloudWatch Logs**; atributos: log levels, tipo, verbosidad; **destinos y ciclo de vida de logs incl. periodo de retención**).
- Task 2.4 Troubleshoot logging solutions (log level, tipo, verbosidad, cadencia, oportunidad, **inmutabilidad**; **permisos de acceso necesarios para el logging**; misconfiguración: permisos read/write, políticas de bucket S3, acceso público, integridad; causa de logs faltantes).
- Task 2.5 Design a log analysis solution (Athena, CloudWatch Logs filter; CloudWatch Logs Insights, CloudTrail Insights, Security Hub insights; **formato y componentes de los logs de CloudTrail**; patrones que indican anomalías y amenazas conocidas; **normalizar, parsear y correlacionar logs**).

**Domain 3 — Infrastructure Security**
- Task 3.1 Design and implement security controls for edge services (AWS WAF, load balancers, Route 53, CloudFront, Shield; **OWASP Top 10 y DDoS**; arquitectura web por capas; estrategias de edge por caso de uso —sitio público, app serverless, backend móvil—; **defensa en capas combinando servicios de edge**; **restricciones por geografía, geolocalización y rate limit**; logs, métricas y monitoreo de edge).
- Task 3.2 Design and implement network security controls (**security groups, network ACLs, AWS Network Firewall**; conectividad inter-VPC con Transit Gateway y VPC endpoints; telemetría: Traffic Mirroring y VPC Flow Logs; VPN; Direct Connect; **segmentación de red: subredes públicas/privadas, VPCs sensibles, conectividad on-premises**; **mantener el tráfico fuera de internet público**; **MACsec**; **identificar y eliminar accesos de red innecesarios**; AWS Firewall Manager).
- Task 3.3 Design and implement security controls for compute workloads (aprovisionamiento y mantenimiento de EC2: parcheo, inspección, snapshots, AMIs, EC2 Image Builder; **IAM instance roles y service roles**; escaneo de vulnerabilidades con Inspector y ECR; **host-based security: firewalls de host, hardening**; **creación de AMIs endurecidas**; parcheo de flota; hallazgos de Inspector; **pasar secretos y credenciales de forma segura a cargas de cómputo**).
- Task 3.4 Troubleshoot network security (**VPC Reachability Analyzer**, Inspector Network Reachability; TCP/IP, UDP vs TCP, puertos, modelo OSI; lectura de Route 53 logs, AWS WAF logs y VPC Flow Logs; captura de muestras con Traffic Mirroring).

**Domain 4 — Identity and Access Management**
- Task 4.1 Design, implement, and troubleshoot authentication for AWS resources (federación, identity providers, IAM Identity Center, Cognito; **credenciales de largo plazo vs temporales**; troubleshooting con CloudTrail, IAM Access Advisor y IAM policy simulator; MFA; **cuándo usar AWS STS**).
- Task 4.2 Design, implement, and troubleshoot authorization for AWS resources (**tipos de política IAM: managed, inline, identity-based, resource-based, session control**; **componentes e impacto de una política: Principal, Action, Resource, Condition**; **ABAC y RBAC**; **interpretar el efecto de una política IAM**; **principio de mínimo privilegio**; **separación de funciones**; análisis de errores de acceso/autorización; **investigar permisos, autorizaciones o privilegios no intencionados otorgados a un recurso, servicio o entidad**).

**Domain 5 — Data Protection**
- Task 5.1 Confidencialidad e integridad de datos **en tránsito** (TLS; IPsec/VPN; acceso remoto seguro con SSH y RDP sobre Systems Manager Session Manager; **cómo funcionan los certificados TLS con CloudFront y load balancers**; **exigir cifrado al conectarse a RDS, Redshift, CloudFront, S3, DynamoDB, load balancers, EFS y API Gateway**; **exigir TLS en llamadas a la API de AWS**; VIFs privadas y públicas).
- Task 5.2 Confidencialidad e integridad de datos **en reposo** (**selección de técnica: client-side, server-side, simétrica, asimétrica**; **integridad: hashing y firmas digitales**; resource policies de DynamoDB, S3 y KMS; **políticas de recurso que restringen acceso a usuarios autorizados: bucket policies, DynamoDB policies**; **prevención de acceso público no autorizado: S3 Block Public Access, snapshots y AMIs públicas**; activación de cifrado en reposo en S3, RDS, DynamoDB, SQS, EBS, EFS; **inmutabilidad: S3 Object Lock, KMS key policies, S3 Glacier Vault Lock, AWS Backup Vault Lock**; CloudHSM para bases de datos relacionales).
- Task 5.3 Ciclo de vida de datos en reposo (lifecycle policies; estándares de retención; S3 Lifecycle, Object Lock, Glacier Vault Lock; ciclo de vida automático para S3, snapshots de EBS y RDS, AMIs, imágenes de contenedor, CloudWatch log groups, Amazon DLM; **calendarios y retención de AWS Backup**).
- Task 5.4 Protección de credenciales, secretos y material criptográfico (**Secrets Manager**; **Systems Manager Parameter Store**; claves simétricas y asimétricas en KMS; **rotación de secretos de cargas de trabajo: credenciales de BD, API keys, IAM access keys, claves gestionadas por el cliente en KMS**; **KMS key policies que limitan el uso de la clave**; importación y eliminación de material de clave provisto por el cliente).

**Domain 6 — Management and Security Governance**
- Task 6.1 Estrategia para desplegar y gestionar cuentas centralmente (**estrategias multi-cuenta**; administración delegada; **guardrails definidos por política**; **buenas prácticas de la cuenta root**; cross-account roles; AWS Organizations; **AWS Control Tower**; **SCPs como solución técnica para imponer una política**; agregación centralizada de findings con administración delegada y AWS Config aggregators; **asegurar las credenciales del usuario root**).
- Task 6.2 Despliegue seguro y consistente de recursos (**IaC: hardening de plantillas CloudFormation y drift detection**; **buenas prácticas de tagging**; gestión, despliegue y versionado centralizados; visibilidad y control de la infraestructura; **AWS Service Catalog** para portafolios de servicios aprobados; agrupación de recursos; Firewall Manager para imponer políticas; **compartición segura entre cuentas con AWS RAM**).
- Task 6.3 Evaluar el cumplimiento de los recursos AWS (**clasificación de datos con servicios AWS**; **evaluar/auditar configuraciones con AWS Config**; identificar datos sensibles con Macie; **crear reglas de AWS Config para detectar recursos no conformes**; recolección y organización de evidencia con Security Hub y AWS Audit Manager).
- Task 6.4 Identificar brechas mediante revisiones arquitectónicas y análisis de costo (**costo y uso de AWS para identificar anomalías**; **estrategias para reducir superficie de ataque**; **AWS Well-Architected Framework**; anomalías por utilización y tendencias; **recursos sin usar vía Trusted Advisor y Cost Explorer**; **AWS Well-Architected Tool para identificar brechas de seguridad**).

**Fuera de alcance declarado por el propio examen** (útil como contraste): DevOps/SysOps, programación en un lenguaje específico, cumplimiento regulatorio, ciclo de vida de desarrollo de software, control de privacidad de datos, diseño de topologías de red, residencia de datos (p.ej. GDPR), arquitectura general del despliegue en nube. Servicios fuera de alcance: servicios de desarrollo de aplicaciones, IoT, ML, media, migración y transferencia.

## K. AWS Well-Architected — Security Pillar (áreas de buenas prácticas)
URLs: https://docs.aws.amazon.com/wellarchitected/latest/framework/sec-bp.html · https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/welcome.html (whitepaper 2024-11-06)
Áreas: Security foundations · Identity and access management · Detection · Infrastructure protection · Data protection · Incident response · **Application security**.
No se pudo extraer el listado numerado SEC 1..SEC n desde estas dos páginas (son índices); ver `no_verificado`.

---

## J. Google Cloud — Professional Cloud Security Engineer (exam guide)
URL: https://cloud.google.com/learn/certification/guides/cloud-security-engineer (redirige a https://services.google.com/fh/files/misc/professional_cloud_security_engineer_exam_guide_english.pdf)
El PDF no muestra número de versión ni fecha.

**Section 1: Configuring access (~25%)**
- 1.1 Managing Cloud Identity: Google Cloud Directory Sync y SSO con IdP de terceros; **cuenta de super administrador**; automatización del ciclo de vida de usuarios; administración programática de cuentas y grupos; **Workforce Identity Federation**.
- 1.2 Managing service accounts: **asegurar y proteger service accounts, incluidas las por defecto**; cuándo se requiere una service account; crear/deshabilitar/autorizar; **asegurar, auditar y mitigar el uso de service account keys**; **credenciales de corta duración**; **Workload Identity Federation**; **service account impersonation**.
- 1.3 Managing authentication: política de contraseñas y de sesión; **SAML y OAuth**; verificación en 2 pasos.
- 1.4 Managing and implementing authorization controls: **roles privilegiados y separación de funciones con roles y permisos IAM**; **permisos IAM y ACL**; **IAM conditions e IAM deny policies**; **control de acceso en organización, carpeta, proyecto y recurso con mínimo privilegio**; **Access Context Manager**; **Policy Intelligence**; permisos vía grupos; **Privileged Access Manager**.
- 1.5 Defining the resource hierarchy: carpetas y proyectos a escala; **organization policies pre-construidas o personalizadas**; **jerarquía de recursos para control de acceso y herencia de permisos**.

**Section 2: Securing communications and establishing boundary protection (~22%)**
- 2.1 Designing and configuring perimeter security: **Cloud NGFW rules y policies, Identity-Aware Proxy (IAP), load balancers, Certificate Authority Service**; **inspección de capa de aplicación (L7) en Cloud NGFW**; direccionamiento IP privado vs público; **WAF (Google Cloud Armor)**; **Secure Web Proxy**; **configuración de seguridad de Cloud DNS**; **monitoreo y restricción continuos de las APIs configuradas**.
- 2.2 Configuring boundary segmentation: **propiedades de seguridad de VPC, VPC peering, Shared VPC y firewall rules**; **aislamiento de red y encapsulación de datos para aplicaciones n-tier**; **VPC Service Controls**.
- 2.3 Establishing private connectivity: conectividad privada entre VPCs y proyectos (Shared VPC, peering, Private Google Access para hosts on-premises); **conectividad privada y cifrado entre centros de datos y VPC (HA VPN, Cloud Interconnect)**; **conectividad privada entre VPC y APIs de Google (Private Google Access, restricted Google access, Private Service Connect)**; **Cloud NAT para tráfico saliente**.

**Section 3: Ensuring data protection (~23%)**
- 3.1 Protecting sensitive data and preventing data loss: **Sensitive Data Protection (SDP): descubrimiento y redacción de PII, seudonimización y cifrado que preserva formato**; **restricción de acceso a servicios de datos (BigQuery, Cloud Storage, Cloud SQL)**; **Secret Manager**; **proteger y gestionar los metadatos de instancias de cómputo**.
- 3.2 Managing encryption at rest, in transit, and in use: **cifrado por defecto de Google, CMEK y Cloud External Key Manager (EKM)**; **claves por software vs hardware**; **creación y gestión de claves CMEK/EKM: rotación, revocación, importación**; aplicación de métodos de cifrado por caso de uso; **object lifecycle policies de Cloud Storage**; **Confidential Computing**.
- 3.3 **Securing AI workloads**: **controles de seguridad y privacidad para sistemas de IA/ML frente a explotación no intencionada de datos o modelos**; **requisitos de seguridad para modelos de entrenamiento alojados en IaaS y en PaaS**; **controles de seguridad para Gemini Enterprise Agent Platform**.

**Section 4: Managing operations (~19%)**
- 4.1 Automating infrastructure and application security: **automatización del escaneo de CVEs en un pipeline CI/CD**; **Binary Authorization para GKE y Cloud Run**; **automatización de creación de imágenes de VM y contenedor: hardening, mantenimiento, gestión de parches de VM**; **gestión de política y detección de drift a escala: CSPM, custom organization policies y custom modules de Security Health Analytics**.
- 4.2 Configuring logging, monitoring, and detection: Cloud NGFW logs, VPC flow logs, Packet Mirroring, Cloud IDS, Log Analytics; **estrategia de logging**; respuesta y remediación de incidentes; **acceso seguro a los logs**; exportación a sistemas externos; **Cloud Audit Logs y data access logs**; **log sinks y aggregated sinks**; **Security Command Center**.

**Section 5: Supporting compliance requirements (~11%)**
- 5.1 Adhering to regulatory and industry standards requirements for the cloud: necesidades técnicas de cómputo, datos, red y almacenamiento; **modelo de responsabilidad compartida**; **Assured Workloads, organization policies, Access Transparency, Access Approval, regionalización de datos y servicios**; **determinar el entorno en alcance regulatorio**; **mapear requisitos de cumplimiento a servicios y controles: segmentación de red y acceso, cobertura de audit logs**.

---

## Separación de alcance para una auditoría autorizada de código/configuración

**APLICABLE** (auditable leyendo repositorio, IaC, manifiestos, políticas y configuración exportada):
- Identidad y acceso: modelos de rol y permiso, mínimo privilegio, roles custom, políticas identity-based vs resource-based, condiciones, deny policies, ABAC/RBAC, separación de funciones, consent de OAuth y permission scopes de app registrations, service principals, managed identities / workload identity federation / service account impersonation, credenciales de corta duración, service account keys, cuenta root/super admin, PIM/PAM, access reviews, CIEM.
- Postura de configuración de nube: Azure Policy (built-in y custom), organization policies de GCP, SCPs y guardrails de AWS Organizations/Control Tower, resource locks, drift detection de IaC, hardening de plantillas CloudFormation/Bicep/Terraform, security baselines, benchmarks (MCSB v2, Well-Architected), tagging, Service Catalog, RAM/cross-account sharing.
- Cifrado y gestión de claves: cifrado en reposo y en tránsito, TLS obligatorio, CMEK/BYOK/EKM/CloudHSM, key policies, rotación, importación/eliminación de material de clave, doble cifrado, TDE, Always Encrypted, dynamic masking, confidential computing, integridad (hashing/firmas), inmutabilidad (Object Lock, Vault Lock, immutable storage, soft delete, versioning), secretos (Key Vault, Secrets Manager, Parameter Store, Secret Manager) y **escaneo de secretos**.
- Seguridad de red: NSG/ASG/security groups/network ACLs, firewalls gestionados (Azure Firewall, Network Firewall, Cloud NGFW), WAF, DDoS, private endpoints / Private Link / VPC Service Controls / Private Service Connect / service endpoints, UDR y rutas, peering, VPN e interconexión, exposición pública (S3 Block Public Access, snapshots/AMIs públicas, storage público), egress (Cloud NAT), reglas efectivas y alcanzabilidad, IAP / Entra Private Access / secure web gateway, DNS.
- Gobierno de datos: descubrimiento y clasificación (Purview, Macie, Sensitive Data Protection), DLP, redacción/seudonimización de PII, políticas de retención y ciclo de vida, residencia y regionalización, restricción de acceso a servicios de datos, traducción de requisitos regulatorios a controles, mapeo a NIST 800-53 / PCI-DSS v4 / CIS v8.1 / NIST CSF 2.0 / ISO 27001:2022 / SOC 2.
- Aplicación y plataforma: WAF, API management y protección de APIs de back-end, App Service / Functions / Logic Apps / Container Apps, contenedores y orquestación (AKS, GKE, ECR/ACR, Binary Authorization), imágenes endurecidas, paso seguro de secretos a cómputo, threat modeling, SDL y DevSecOps, gestión de dependencias, escaneo de CVE en CI/CD.
- Seguridad de IA (bloque emergente ya curricularizado por los tres proveedores): identidades de agente (Entra Agent ID) y conditional access sobre ellas, blast radius de agentes, guardrails de agente, AI gateway delante del modelo, DSPM para Copilot/apps de IA, sobreexposición de datos a asistentes, gobierno y DLP de cargas de IA, seguridad de datos de entrenamiento e inferencia, dominio AI del MCSB v2.
- Logging **como configuración auditable**: existencia y cobertura de audit logs, data access logs, flow logs, diagnostic settings/DCR, destinos, retención, permisos de escritura/lectura de los buckets de log, inmutabilidad e integridad del log. (El *contenido* del log y su análisis en vivo, no.)

**NO APLICABLE** a una auditoría de código/configuración (se documenta y se descarta explícitamente):
- Operación de SIEM/SOC en vivo: SC-200 casi completo (triage, incidentes, hunting con KQL, workbooks, notebooks, tuning de alertas, case management, Security Copilot operativo), AWS Domain 1 y gran parte de Domain 2, GCP 4.2 en su parte de respuesta.
- Respuesta a incidentes y forense: aislamiento de recursos comprometidos, memory dumps, snapshots forenses, cadena de custodia, playbooks/runbooks de IR, root cause analysis post-brecha.
- Gestión de endpoints y dispositivos: Intune, Defender for Endpoint, EDR, ASR rules, gestión de flota, LAPS.
- BCDR y continuidad: estrategia de backup/restore, DR, recuperación ante ransomware (salvo la *configuración* de protección de backups, que sí es auditable).
- OT/ICS/IoT industrial (Defender for IoT), salvo la configuración de red que los aísla.
- Certificación y examen en sí: renovación, políticas de reintento, sandbox — irrelevante.

**FUERA DE ALCANCE POR SER OFENSIVO/DESTRUCTIVO** — ningún currículo de esta área lo enseña, pero se deja constancia: no se incorpora nada de evasión de EDR/XDR, desactivación de logging para ocultar rastro, técnicas de destrucción de evidencia, ni explotación de las TTPs de MITRE ATT&CK referenciadas por MCSB v2 más allá de comprobar que existe el control que las mitiga.

---

## Licencias verificadas

| Fuente | Licencia verificada | Se puede citar | NO se puede |
|---|---|---|---|
| Study guides de certificación de Microsoft (SC-200, AZ-500, SC-500, SC-100) | Provienen del repo **privado** `MicrosoftDocs/learn-certs-pr` (visible en `original_content_git_url` de cada página). **No hay licencia abierta declarada.** Aplican los Microsoft Learn Terms of Use (https://learn.microsoft.com/en-us/legal/termsofuse), verificados: "the Services are for your personal and non-commercial use… You may not modify, copy, distribute… or create derivative works from… any information… obtained from the Services… without prior written consent from Microsoft"; y para Documents: uso informativo y no comercial, "no modifications of any Documents are made". | Códigos de examen (SC-200, AZ-500, SC-500, SC-100, SC-900, AZ-800/801), nombres de dominio y sus pesos porcentuales, nombres de grupo funcional, fechas "skills measured as of", el hecho del retiro de AZ-500 y sus URLs. | Copiar los bullets de objetivos textualmente al repo MIT; publicar el temario como documento; presentarlo como material de estudio; cualquier uso comercial del texto. |
| Documentación de producto de Microsoft en repos públicos `MicrosoftDocs` (p.ej. `azure-docs`) | **CC BY 4.0 verificada** en https://raw.githubusercontent.com/MicrosoftDocs/azure-docs/main/LICENSE ("Creative Commons Attribution 4.0 International Public License"). Permite obras derivadas **con atribución**. Nota: CC BY 4.0 y MIT son compatibles en un mismo repo solo si el texto CC BY queda atribuido y marcado como tal. | Se puede reutilizar y adaptar texto de la documentación de producto **si se atribuye a Microsoft con enlace a la fuente y se indica que fue modificado**. | Reutilizarlo sin atribución, o dejarlo cubierto silenciosamente por el MIT del repo. |
| Microsoft Cloud Security Benchmark v2 (learn.microsoft.com/security/benchmark/azure/…) | **NO confirmada como CC BY 4.0.** `original_content_git_url` apunta a `MicrosoftDocs/security-benchmark-docs-pr`, repo **privado**; no pude abrir un LICENSE. Se trata bajo los mismos Learn ToU que las study guides. | IDs de dominio y control (NS, IM, PA, DP, AM, LT, IR, PV, ES, BR, DS, AI; NS-1, DP-1, AI-1…), nombres de dominio, la lista de estándares a los que mapea, y el hecho de que cada control tiene los campos ID / Azure Policy / Security principle / Risk to mitigate / MITRE ATT&CK / Implementation guidance / Implementation example / Criticality level / Control Mapping. | Copiar las descripciones de dominio ni el texto de los controles. |
| Catálogo de Microsoft Learn (API `learn.microsoft.com/api/catalog/`) | Mismos Learn ToU. Títulos y `uid` son identificadores fácticos. | Títulos de learning path, `uid`, títulos de certificación y `uid`, conteos. | Copiar descripciones o el contenido de los módulos. |
| AWS Certified Security – Specialty (SCS-C02) Exam Guide, PDF en `d1.awsstatic.com` | **Propietaria.** AWS Site Terms verificados (https://aws.amazon.com/terms/): licencia limitada "to access and make personal use of the AWS Site and not to download (other than page caching) or modify it"; el contenido "may not be reproduced, duplicated, copied, sold, resold, visited, or otherwise exploited for any commercial purpose". El PDF **no está** en `docs.aws.amazon.com`, así que **no** le aplica la excepción abierta. | Código del examen (SCS-C02), nombres de los 6 dominios con sus pesos, numeración de task statements (1.1 … 6.4) y los nombres de servicio AWS (marcas/hechos). | Reproducir los bullets "Knowledge of" / "Skills in", ni el apéndice de servicios in/out of scope como texto. |
| Documentación en `docs.aws.amazon.com` (incl. Well-Architected Security Pillar) | **CC-BY-SA-4.0 verificada vía AWS Site Terms**: "documentation (e.g., user guides, developer guides, other publications) is licensed under CC-BY-SA-4.0, while any code therein is licensed under MIT-0". | Se puede adaptar el texto **solo si la obra derivada se relicencia bajo CC-BY-SA-4.0** con atribución. | **Incorporarlo tal cual a un repo MIT**: CC-BY-SA es copyleft fuerte y contaminaría la licencia. Regla operativa: de AWS docs tomar solo hechos y nombres, nunca redacción. |
| Google Cloud PCSE exam guide (PDF en `services.google.com`) y páginas de cloud.google.com | Política de contenido de Google verificada (https://developers.google.com/terms/site-policies, destino del redirect de https://cloud.google.com/site-policies): "Except as otherwise noted, the content of this page is licensed under the Creative Commons Attribution 4.0 License" y "Code samples are licensed under the Apache 2.0 License". **Pero** el aviso dice "of this page" y el PDF **no lleva aviso CC BY**, por lo que cae en "except as otherwise noted" → **no asumir CC BY para el PDF**. Excluidos siempre: marcas y brand features. | Nombres de sección con sus pesos (~25%, ~22%, ~23%, ~19%, ~11%), numeración 1.1…5.1, y los nombres de producto de Google Cloud. | Reproducir los bullets "Considerations include" como texto; usar marcas o logos de Google. |

**Regla operativa única para el repo MIT `ethical-hacker-squad`:** de estas fuentes solo entran (1) códigos e identificadores, (2) nombres de dominio/tema, (3) el hecho estructural de qué competencias exige el mercado. Todo procedimiento nuevo se redacta desde cero con nuestros 6 campos y cita la fuente como *referencia externa por URL*, nunca como texto embebido.

---

## No verificado

1. **AWS Security Fundamentals** (curso digital gratuito): abrí https://aws.amazon.com/training/digital/aws-security-fundamentals/ pero la página solo expone el tile del curso ("2 hours", botón "Start learning"). El temario por módulos vive detrás del login de AWS Skill Builder. **No reconstruido de memoria.**
2. **Listado numerado SEC 1..SEC n del AWS Well-Architected Security Pillar**: las dos páginas abiertas (`framework/sec-bp.html` y `security-pillar/welcome.html`) son índices; solo confirmé las 7 áreas de buenas prácticas. Las preguntas numeradas no fueron extraídas.
3. **Que SC-500 reemplace oficialmente a AZ-500**: la página de SC-500 no lo declara y la de AZ-500 tampoco nombra sucesor. Es una **inferencia** sólida (retiro 31-ago-2026 + cert nueva del mismo rol + temario solapado) pero no un hecho publicado que yo haya leído.
4. **Fecha/versión del exam guide de Google PCSE**: el PDF no la incluye.
5. **Google Cloud Security Foundations / rutas de Google Cloud Skills Boost**: no abiertas (presupuesto).
6. **AWS Certified Security – Specialty en su posible versión SCS-C03**: solo verifiqué el PDF "Version 1.0 SCS-C02"; no comprobé si existe una revisión posterior.
7. **Licencia del repo `MicrosoftDocs/learn-certs-pr` y `security-benchmark-docs-pr`**: son repos privados; no pude abrir un LICENSE. Tratados como propietarios (postura conservadora).
