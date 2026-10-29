# ¿Cómo funciona la sincronización de agendas y disponibilidad en CORE TEKER? {#core-teker-explainer}

El motor de disponibilidad de **CORE TEKER** mantiene sincronizados los horarios de los profesionales con las citas activas en menos de 20 segundos mediante vectores binarios de 288 posiciones (`tkr_disponibilidad_bitmap`).

- La grabación de horarios sincroniza inmediatamente desde `f_fecha_actual` hacia adelante.[](source:pkgln_hor)
- Los cambios en `tkr_citas` se encolan en `tkr_refrescar_agenda` y son procesados cada 20 segundos por `JOB_TKR_REFRESCAR_AGENDA`.[](source:job_sql)
- El directorio cruza los horarios vigentes con `bitmap_ocupado` para mostrar únicamente turnos libres.[](source:pkgln_dir)

@answer scope="CORE TEKER · Oracle PL/SQL 5 Capas · Vector 288 bits (bloques de 5 min)"
@meta locale=es
@source pkgln_hor title="PKGLN_HORARIOS (Orquestador de Horarios)" path=database/pkgln_horarios.pkb lines=1536:1571
@source pkgcn_hor title="PKGCN_HORARIOS (Consulta Citas y MERGE Bitmap)" path=database/pkgcn_horarios.pkb lines=416:439
@source job_sql title="JOB_TKR_REFRESCAR_AGENDA (Scheduler 20s)" path=database/job_refrescar_agenda.sql lines=21:44
@source pkgln_dir title="DAO Cola tkr_refrescar_agenda" path=database/pkgtkr_refrescar_agenda_dao.pkb lines=35:60

## ¿Cuál es el flujo completo desde la cola hasta el bitmap? {#flujo-cola}

@workflow id=flujo-refresco title="Flujo de Refresco de Agenda"
| lane disp | Disparador |
| lane orq | Orquestación |
| lane bd | Persistencia |
| job | Job 20s | messagebus | disp |
| act | p_actualizar_agenda | backend | orq |
| sinc | p_sincronizar_agenda | backend | orq |
| merge | MERGE Bitmap 288 | database | bd |
| del | p_eliminar Cola | security | bd |
| job > act | dispara | emphasis |
| act > sinc | fecha | emphasis |
| sinc > merge | bits | emphasis |
| merge > del | codigo=0 | emphasis |

@steps id=pasos-refresco
| s1 | Job 20s | Ejecuta `PKGLN_HORARIOS.p_actualizar_agenda` cada 20 segundos sin bloquear transacciones. | flujo-refresco | job |
| s2 | p_actualizar_agenda | Lee los registros pendientes en `tkr_refrescar_agenda` mediante su DAO. | flujo-refresco | act |
| s3 | p_sincronizar_agenda | Cruza horarios vigentes (`POR_DIA`, `PERSONALIZADO`, `BASE`) con citas en estado 2 y 3. | flujo-refresco | sinc |
| s4 | MERGE Bitmap 288 | Actualiza `bitmap_ocupado`, `bitmap_disponible` y `slots_disponibles`. | flujo-refresco | merge |
| s5 | p_eliminar Cola | Si `codigo = 0`, borra el registro de la cola y ejecuta `COMMIT`. | flujo-refresco | del |

## ¿Cómo impacta el filtro por fecha única frente al rango completo? {#rendimiento-chart}

```mermaid title="Tiempo estimado de sincronización en BD (ms) — Ilustrativo"
xychart-beta
  x-axis ["Consulta Citas", "Cálculo 288 Bits", "MERGE Bitmap", "Total Ejecución"]
  y-axis "ms" 0 --> 180
  bar "Rango 60 días" [25, 65, 80, 170]
  bar "Fecha única (Cola 20s)" [5, 3, 6, 14]
```

| Estrategia | Días procesados | Tiempo medio | Uso recomendado |
| --- | --- | --- | --- |
| Rango completo (`60 días`) | 60 días | 170 ms {caution:Mayor carga} | Al crear o modificar horarios del profesional |
| Fecha única (`tkr_refrescar_agenda`) | 1 día | 14 ms {good:Ultrarrápido} | En `JOB_TKR_REFRESCAR_AGENDA` cada 20 segundos |

## ¿Cómo se distribuyen los 12 turnos del 2026-10-30 (Caso Cita 737)? {#distribucion-turnos}

```mermaid title="Distribución de turnos jornada 08:00 a 12:00 (2026-10-30)"
pie
  "Turnos Disponibles (20 min)" : 11
  "Turno Ocupado Cita 737 (10:00-10:20)" : 1
```

@facts
| Profesional | Carolina Avila (`id_usuario = 6`) |
| Fecha evaluada | `2026-10-30` (`08:00` a `12:00`, 12 turnos de 20 min) |
| Cita activa | `tkr_citas.id = 737` (`10:00` a `10:20`, `id_estado_cita = 2`) |
| Bits marcados en `bitmap_ocupado` | Posiciones `121` a `124` (`1111`) |

## ¿Qué consulta garantiza encontrar las citas ocupadas del profesional? {#codigo-consulta}

@code source=pkgcn_hor language=sql

