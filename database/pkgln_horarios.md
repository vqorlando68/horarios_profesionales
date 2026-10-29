# Diagrama y Flujo de Información: PKGLN_HORARIOS

## Método: p_listar_profesionales

### 1. Descripción en Lenguaje Natural
Consulta la lista de médicos y profesionales de salud habilitados en el sistema con soporte de filtrado opcional por nombre o correo electrónico:
- Valida la estructura del payload de entrada de manera tolerante a nulos, adoptando valores por defecto si no se especifican filtros.
- Evalúa las reglas de observabilidad en la bitácora de auditoría y apertura la traza técnica de seguimiento si se encuentra activa.
- Delega en la capa de negocio la consulta multi-tabla para extraer los usuarios activos con rol asistencial (`id_rol = 4`), concatenando nombres y apellidos y resolviendo la URL de la fotografía de perfil.
- Cierra la traza técnica con estado exitoso y retorna el arreglo estructurado con la información de los profesionales.
- Ante cualquier fallo imprevisto, captura la excepción, revierte operaciones, marca la traza en estado de error y persiste el volcado forense antes de responder.

### 2. Decisiones y Bifurcaciones Lógicas
- **Paso 01 [Evaluación de Trazabilidad]**: Si el servicio tiene telemetría activa en las reglas de auditoría; Registra el inicio de traza y vuelve al flujo principal (`uti_manejo_trazas_pkg.f_debe_trazar`)
- **Paso 02 [Apertura de Traza Técnica]**: Si la telemetría se encuentra habilitada; Apertura el registro de seguimiento en la bitácora de auditoría y vuelve al flujo principal (`uti_manejo_trazas_pkg.p_iniciar_traza`)
- **Paso 03 [Consulta Multi-Tabla de Médicos]**: Extrae los profesionales activos con rol asistencial resolviendo nombres completos y enlaces de fotografía; `PKGCN_HORARIOS.p_consultar_profesionales_json`
- **Paso 04 [Telemetría Exitosa]**: Si la traza se encuentra activa; Registra el cierre exitoso de la ejecución en la auditoría y vuelve al flujo principal (`uti_manejo_trazas_pkg.p_finalizar_traza`)
- **Paso 05 [Control Forense de Excepciones]**: Ante cualquier fallo imprevisto; Registra el estado de error en telemetría (`uti_manejo_trazas_pkg.p_finalizar_traza_error`), persiste el volcado forense en la bitácora de incidentes (`uti_ge_excepciones_pkg.p_grabar_log`) y retorna error

### 3. Mapa de Objetos Invocados y Llamados
| Orden | Nombre Exacto del Objeto Invocado | Capa / Familia | Tipo | Propósito de la Invocación | Condición / Momento |
| :---: | :--- | :--- | :--- | :--- | :--- |
| 1 | `uti_manejo_trazas_pkg.f_debe_trazar` | `uti_` | Función | Comprobar si el método tiene telemetría configurada | Al inicio de la ejecución |
| 2 | `uti_manejo_trazas_pkg.p_iniciar_traza` | `uti_` | Procedimiento | Registrar apertura en tkr_traza_ejecucion | Bifurcación: Si debe_trazar = TRUE (vuelve al flujo) |
| 3 | `PKGCN_HORARIOS.p_consultar_profesionales_json` | `pkgcn_` | Procedimiento | Ejecutar consulta multi-tabla con sintaxis tradicional y generar JSON | En flujo principal |
| 4 | `pkgcn_profesionales.f_url_foto_profesional` | `pkgcn_` | Función | Resolver URL de la imagen del profesional | Invocado internamente por consulta SQL |
| 5 | `uti_manejo_trazas_pkg.p_finalizar_traza` | `uti_` | Procedimiento | Registrar fin exitoso de la telemetría | Al completar la consulta sin fallos |
| 6 | `uti_manejo_trazas_pkg.p_finalizar_traza_error` | `uti_` | Procedimiento | Registrar fin con estado ERROR en telemetría | Bloque WHEN OTHERS ante fallos |
| 7 | `uti_ge_excepciones_pkg.p_grabar_log` | `uti_` | Procedimiento | Persistir registro técnico del error en tkr_errores | Bloque WHEN OTHERS ante fallos |

```json
// JSON ENTRADA
{
  "filtro": "carlos",
  "id_usuario_ejecutor": 105
}
```

```json
// JSON SALIDA
{
  "codigo": 0,
  "mensaje": "Profesionales consultados exitosamente",
  "profesionales": [
    {
      "id_usuario": 47,
      "nombre_completo": "Carlos Andrés Mendoza",
      "correo": "cmendoza@teker.com",
      "url_foto": "/uploads/fotos/47.jpg",
      "id_estado": 1
    }
  ]
}
```

---

## Método: p_guardar_horarios

### 1. Descripción en Lenguaje Natural
Configura la disponibilidad semanal de atención de un profesional de salud, soportando múltiples rangos de horas por día, vigencias por fecha y sincronización automática de ausencias por festivos no laborables:
- Valida la integridad del payload JSON y los turnos recibidos en memoria (días canónicos, orden de horas y coherencia de vigencias).
- Si incluye turnos en domingo, valida que el médico cuente con autorización activa para trabajar festivos.
- Efectúa validación cruzada en memoria entre rangos recibidos para evitar solapamientos internos dentro de la misma vigencia y convenio.
- Valida el arreglo opcional de días festivos no laborables contra el calendario oficial nacional, impidiendo domingos (que se configuran en la grilla semanal).
- Ejecuta el borrado previo controlado: reemplazo total histórico o limpieza quirúrgica de la vigencia origen modificada para prevenir falsos cruces.
- Valida unicidad de Horario Base (solo un horario sin fecha fin) y no traslape contra turnos previos en base de datos.
- Desestructura el JSON e inserta masivamente los nuevos horarios en la tabla relacional.
- Por cada festivo no laborable, comprueba no duplicidad y genera automáticamente la ausencia correspondiente de un día.
- Confirma atómicamente toda la operación (horarios y ausencias) con commit unificado o revierte y genera log forense ante anomalías.

### 2. Decisiones y Bifurcaciones Lógicas
- **Paso 01 [Validación de Entrada]**: Si el payload viene nulo o no contiene el identificador del usuario; Salida inmediata con código -20001 por datos obligatorios ausentes
- **Paso 02 [Validación Estructural de Turnos]**: Si algún turno contiene un día no canónico, horas invertidas o fechas mal estructuradas; Salida inmediata con código -20002 o -20003 por formato horario inválido
- **Paso 03 [Regla de Turnos en Domingo - Bifurcación]**: Si el turno corresponde al día domingo y el usuario no labora en festivos; Salida inmediata con código -20010 por restricción dominical (`pkgca_tkr_usuarios.f_trabaja_festivos`)
- **Paso 04 [Validación de Solapamiento en Memoria]**: Si existen dos rangos con cruce de horas para el mismo día y mismo convenio dentro del período de vigencia; Salida inmediata con código -20008 por traslape interno de turnos
- **Paso 05 [Validación de Festivos No Laborables]**: Si alguna fecha festiva es domingo o no se encuentra registrada en el calendario oficial nacional; Salida inmediata con código -20012 o -20013 por fecha festiva inválida (`pkgca_tkr_festivos.f_es_festivo`)
- **Paso 06 [Limpieza Total Histórica - Bifurcación]**: Si se solicita reemplazo integral de la programación del médico; Elimina todos los horarios históricos del profesional y vuelve al flujo principal (`pkgca_tkr_horarios_profesional.p_borrar_x_profesional`)
- **Paso 07 [Limpieza de Vigencia Modificada - Bifurcación]**: Si se está editando una vigencia previa o se indicó reemplazo de vigencia; Elimina los horarios previos de dicha vigencia y vuelve al flujo principal (`pkgca_tkr_horarios_profesional.p_borrar_x_rango_fechas`)
- **Paso 08 [Unicidad de Horario Base]**: Si se intenta registrar un horario sin fecha final cuando ya existe otro horario base registrado para el profesional; Salida inmediata con código -20011 por existencia de horario base (`pkgca_tkr_horarios_profesional.f_existe_horario_base`)
- **Paso 09 [Validación de Traslapes en Base de Datos]**: Si el horario con fecha final colisiona con turnos registrados previamente para ese profesional y convenio; Salida inmediata con código -20009 por conflicto de horarios en base de datos (`PKGCN_HORARIOS.f_existe_traslape_horario`)
- **Paso 10 [Persistencia Relacional de Turnos]**: Desestructura el arreglo mediante extracción relacional e inserta los nuevos turnos en el sistema; `PKGCN_HORARIOS.p_guardar_horarios_profesional`
- **Paso 11 [Generación de Ausencias por Festivo - Bifurcación]**: Si la fecha festiva no se encuentra previamente cubierta en el calendario del profesional; Inserta la ausencia automática de un día y vuelve al flujo principal (`PKGTKR_AUSENCIAS_PROFESIONAL_DAO.p_insertar`)
- **Paso 12 [Sincronización de Slots de Agenda]**: Sincroniza los slots disponibles y ocupados del horario frente a las citas en `tkr_citas` (`id_estado_cita IN (2, 3)`); `p_sincornizar_agenda`
- **Paso 13 [Confirmación Transaccional Atómica]**: Confirma todos los cambios en la base de datos de manera atómica y controlada; `p_do_commit`
- **Paso 14 [Control Forense de Excepciones]**: Ante cualquier error inesperado; Revierte la transacción, registra el volcado del fallo en la bitácora de errores (`uti_ge_excepciones_pkg.p_grabar_log`) y retorna error

### 3. Mapa de Objetos Invocados y Llamados
| Orden | Nombre Exacto del Objeto Invocado | Capa / Familia | Tipo | Propósito de la Invocación | Condición / Momento |
| :---: | :--- | :--- | :--- | :--- | :--- |
| 1 | `pkgca_tkr_usuarios.f_trabaja_festivos` | `pkgca_` | Función | Validar si el médico tiene autorización para laborar turnos dominicales | Si se procesa turno de día domingo |
| 2 | `pkgca_tkr_festivos.f_es_festivo` | `pkgca_` | Función | Validar existencia de cada fecha en el calendario nacional oficial | Si incluye festivos no laborables |
| 3 | `pkgca_tkr_horarios_profesional.p_borrar_x_profesional` | `pkgca_` | Procedimiento | Eliminar la totalidad de horarios previos del profesional | Bifurcación: Si reemplazar_todo = 1 (vuelve al flujo) |
| 4 | `pkgca_tkr_horarios_profesional.p_borrar_x_rango_fechas` | `pkgca_` | Procedimiento | Eliminar horarios previos de una vigencia específica modificada | Bifurcación: Si se edita vigencia (vuelve al flujo) |
| 5 | `pkgca_tkr_horarios_profesional.f_existe_horario_base` | `pkgca_` | Función | Verificar que no exista otro horario base sin fecha final | Si el lote contiene fecha_final nula |
| 6 | `PKGCN_HORARIOS.f_existe_traslape_horario` | `pkgcn_` | Función | Detectar colisiones de horas y fechas contra turnos en base de datos | Para turnos con fecha fin en modo incremental |
| 7 | `PKGCN_HORARIOS.p_guardar_horarios_profesional` | `pkgcn_` | Procedimiento | Insertar masivamente turnos usando extracción relacional JSON_TABLE | En flujo principal tras validar traslapes |
| 8 | `pkgca_tkr_ausencias_profesional.f_existe_ausencia` | `pkgca_` | Función | Verificar si la fecha festiva ya está cubierta para no duplicar | Por cada festivo no laborable |
| 9 | `PKGTKR_AUSENCIAS_PROFESIONAL_DAO.p_insertar` | `DAO` | Procedimiento | Persistir ausencia automática de un día por festivo no laborable | Bifurcación: Si festivo no cubierto (vuelve al flujo) |
| 10 | `PKGLN_HORARIOS.p_sincornizar_agenda` | `pkgln_` | Procedimiento | Sincronizar slots y bitmaps cruzando horarios con citas en estados 2 y 3 | Tras guardar o actualizar horarios |
| 11 | `p_do_commit` | `Transaccional` | Procedimiento | Confirmar cambios de forma controlada | Flujo principal al completar operaciones |
| 12 | `uti_ge_excepciones_pkg.p_grabar_log` | `uti_` | Procedimiento | Registrar volcado técnico de excepción en tkr_errores | Bloque WHEN OTHERS ante fallos |

```json
// JSON ENTRADA
{
  "id_usuario": 47,
  "reemplazar_todo": 0,
  "reemplazar_vigencia": 1,
  "fecha_inicial_origen": "2026-12-01",
  "fecha_final_origen": "2026-12-31",
  "horarios": [
    {
      "dia_semana": "LU",
      "hora_desde": "08:00",
      "hora_hasta": "12:00",
      "fecha_inicial": "2026-12-01",
      "fecha_final": "2026-12-31",
      "id_convenio": null
    }
  ],
  "festivos_no_laborables": [
    {
      "fecha": "2026-12-08",
      "nombre": "Inmaculada Concepción"
    }
  ]
}
```

```json
// JSON SALIDA
{
  "codigo": 0,
  "mensaje": "Horarios y ausencias guardados exitosamente",
  "id_usuario": 47,
  "ausencias_creadas": 1,
  "ausencias_existentes": 0
}
```

---

## Método: p_consultar_agenda

### 1. Descripción en Lenguaje Natural
Consulta la ficha técnica y la agenda completa de un profesional específico:
- Valida la presencia obligatoria del identificador del profesional (`id_usuario`).
- Evalúa y registra telemetría técnica si la traza se encuentra activa.
- Delega en el caso de negocio la extracción multi-tabla que consolida los datos personales del profesional, su foto de perfil, la colección cronológica de turnos activos y el listado histórico de ausencias programadas.
- Cierra la traza con éxito y retorna la estructura consolidada en formato JSON.

### 2. Decisiones y Bifurcaciones Lógicas
- **Paso 01 [Validación de Entrada]**: Si el payload es nulo o no contiene el identificador del usuario; Salida inmediata con código -20001 por datos obligatorios faltantes
- **Paso 02 [Evaluación de Trazabilidad]**: Si el servicio tiene telemetría activa en las reglas de auditoría; Registra el inicio de traza y vuelve al flujo principal (`uti_manejo_trazas_pkg.f_debe_trazar`)
- **Paso 03 [Apertura de Traza Técnica]**: Si la telemetría se encuentra habilitada; Apertura el registro de seguimiento en la bitácora de auditoría y vuelve al flujo principal (`uti_manejo_trazas_pkg.p_iniciar_traza`)
- **Paso 04 [Consulta Integral de Agenda]**: Extrae de forma consolidada la ficha del profesional, los turnos semanales vigentes y el listado de ausencias; `PKGCN_HORARIOS.p_consultar_agenda_profesional_json`
- **Paso 05 [Telemetría Exitosa]**: Si la traza se encuentra activa; Registra el cierre exitoso de la ejecución en la auditoría y vuelve al flujo principal (`uti_manejo_trazas_pkg.p_finalizar_traza`)
- **Paso 06 [Control Forense de Excepciones]**: Ante excepciones no controladas; Registra el error en telemetría (`uti_manejo_trazas_pkg.p_finalizar_traza_error`), persiste el registro forense en la bitácora de incidentes (`uti_ge_excepciones_pkg.p_grabar_log`) y retorna error

### 3. Mapa de Objetos Invocados y Llamados
| Orden | Nombre Exacto del Objeto Invocado | Capa / Familia | Tipo | Propósito de la Invocación | Condición / Momento |
| :---: | :--- | :--- | :--- | :--- | :--- |
| 1 | `uti_manejo_trazas_pkg.f_debe_trazar` | `uti_` | Función | Verificar configuración de telemetría activa | Al inicio del procedimiento |
| 2 | `uti_manejo_trazas_pkg.p_iniciar_traza` | `uti_` | Procedimiento | Registrar apertura de traza técnica en tkr_traza_ejecucion | Bifurcación: Si telemetría activa (vuelve al flujo) |
| 3 | `PKGCN_HORARIOS.p_consultar_agenda_profesional_json` | `pkgcn_` | Procedimiento | Realizar consulta multi-tabla y consolidar JSON de agenda | En flujo principal |
| 4 | `pkgcn_profesionales.f_url_foto_profesional` | `pkgcn_` | Función | Resolver URL de fotografía del profesional | Invocado dentro de consulta SQL |
| 5 | `uti_manejo_trazas_pkg.p_finalizar_traza` | `uti_` | Procedimiento | Cerrar traza técnica con estado exitoso | Al completar la consulta sin fallos |
| 6 | `uti_manejo_trazas_pkg.p_finalizar_traza_error` | `uti_` | Procedimiento | Registrar estado ERROR en telemetría técnica | Bloque WHEN OTHERS ante fallos |
| 7 | `uti_ge_excepciones_pkg.p_grabar_log` | `uti_` | Procedimiento | Persistir registro técnico del error en tkr_errores | Bloque WHEN OTHERS ante fallos |

```json
// JSON ENTRADA
{
  "id_usuario": 47
}
```

```json
// JSON SALIDA
{
  "codigo": 0,
  "mensaje": "Agenda consultada exitosamente",
  "profesional": {
    "id_usuario": 47,
    "nombre_completo": "Carlos Andrés Mendoza",
    "correo": "cmendoza@teker.com",
    "url_foto": "/uploads/fotos/47.jpg"
  },
  "horarios": [],
  "ausencias": []
}
```

---

## Método: p_registrar_ausencia

### 1. Descripción en Lenguaje Natural
Registra un período programado en el que el profesional no prestará atención médica (permisos, incapacidades, vacaciones):
- Valida la presencia de `id_usuario`, `fecha_inicial` y `fecha_final`.
- Valida la coherencia de fechas asegurando que la fecha inicial no sea posterior a la fecha final.
- Si la telemetría está habilitada, inicia el registro de trazabilidad técnica.
- Delega la inserción relacional directa en el DAO estándar de persistencia de ausencias.
- Confirma la transacción en la base de datos de manera atómica con commit controlado, finaliza la traza y retorna el identificador de la ausencia registrada.

### 2. Decisiones y Bifurcaciones Lógicas
- **Paso 01 [Validación de Entrada]**: Si el payload es nulo, no contiene el usuario o faltan las fechas; Salida inmediata con código -20001 o -20002 por parámetros incompletos
- **Paso 02 [Validación de Coherencia de Fechas]**: Si el formato de fechas es inválido o la fecha de inicio es superior a la fecha final; Salida inmediata con código -20003 o -20004 por intervalo cronológico inválido
- **Paso 03 [Evaluación de Trazabilidad]**: Si el método tiene habilitada la telemetría; Apertura la traza técnica de seguimiento y vuelve al flujo principal (`uti_manejo_trazas_pkg.p_iniciar_traza`)
- **Paso 04 [Persistencia de la Ausencia]**: Registra el período de ausencia programada en la tabla relacional de ausencias; `PKGTKR_AUSENCIAS_PROFESIONAL_DAO.p_insertar`
- **Paso 05 [Confirmación Transaccional]**: Confirma todos los cambios en la base de datos de manera atómica y controlada; `p_do_commit`
- **Paso 06 [Telemetría Exitosa]**: Registra el cierre exitoso de la transacción en la auditoría y vuelve al flujo principal (`uti_manejo_trazas_pkg.p_finalizar_traza`)
- **Paso 07 [Control Forense de Excepciones]**: Ante fallos imprevistos; Revierte los cambios, registra el error en telemetría (`uti_manejo_trazas_pkg.p_finalizar_traza_error`), guarda el registro forense (`uti_ge_excepciones_pkg.p_grabar_log`) y retorna error

### 3. Mapa de Objetos Invocados y Llamados
| Orden | Nombre Exacto del Objeto Invocado | Capa / Familia | Tipo | Propósito de la Invocación | Condición / Momento |
| :---: | :--- | :--- | :--- | :--- | :--- |
| 1 | `uti_manejo_trazas_pkg.f_debe_trazar` | `uti_` | Función | Determinar si el método debe trazar ejecución | Al inicio del procedimiento |
| 2 | `uti_manejo_trazas_pkg.p_iniciar_traza` | `uti_` | Procedimiento | Apertura registro de telemetría | Bifurcación: Si f_debe_trazar = TRUE (vuelve al flujo) |
| 3 | `PKGTKR_AUSENCIAS_PROFESIONAL_DAO.p_insertar` | `DAO` | Procedimiento | Insertar registro de ausencia en tkr_ausencias_profesional | Tras validaciones de parámetros y fechas |
| 4 | `p_do_commit` | `Transaccional` | Procedimiento | Confirmar cambios de forma controlada | Flujo principal tras insertar ausencia |
| 5 | `uti_manejo_trazas_pkg.p_finalizar_traza` | `uti_` | Procedimiento | Cerrar traza técnica exitosa | Antes de responder al cliente |
| 6 | `uti_manejo_trazas_pkg.p_finalizar_traza_error` | `uti_` | Procedimiento | Cerrar traza con estado de error | Bloque WHEN OTHERS ante fallos |
| 7 | `uti_ge_excepciones_pkg.p_grabar_log` | `uti_` | Procedimiento | Registrar información forense en tkr_errores | Bloque WHEN OTHERS ante fallos |

```json
// JSON ENTRADA
{
  "id_usuario": 47,
  "fecha_inicial": "2026-12-24",
  "fecha_final": "2026-12-31",
  "motivo": "Vacaciones de fin de año"
}
```

```json
// JSON SALIDA
{
  "codigo": 0,
  "mensaje": "Ausencia registrada exitosamente",
  "id": 501
}
```

---

## Método: p_consultar_ausencias

### 1. Descripción en Lenguaje Natural
Consulta el catálogo de ausencias registradas pudiendo aplicar filtros opcionales por profesional o intervalo de fechas:
- Extrae los parámetros de filtro del JSON de entrada.
- Delega en el caso de negocio multi-tabla la ejecución de la consulta que recupera las ausencias enriquecidas relacionalmente con nombres completos del profesional y URL de su foto.
- Retorna el listado consolidado en formato JSON estructurado.

### 2. Decisiones y Bifurcaciones Lógicas
- **Paso 01 [Consulta Multi-Tabla de Ausencias]**: Extrae los períodos de ausencia filtrados por profesional y rango enriquecidos con datos del usuario; `PKGCN_HORARIOS.p_consultar_ausencias_json`
- **Paso 02 [Control Forense de Excepciones]**: Ante fallos en la consulta; Registra el incidente técnico en la bitácora de errores (`uti_ge_excepciones_pkg.p_grabar_log`) y retorna error

### 3. Mapa de Objetos Invocados y Llamados
| Orden | Nombre Exacto del Objeto Invocado | Capa / Familia | Tipo | Propósito de la Invocación | Condición / Momento |
| :---: | :--- | :--- | :--- | :--- | :--- |
| 1 | `PKGCN_HORARIOS.p_consultar_ausencias_json` | `pkgcn_` | Procedimiento | Realizar consulta relacional multi-tabla y generar estructura JSON | En flujo principal |
| 2 | `pkgcn_profesionales.f_url_foto_profesional` | `pkgcn_` | Función | Resolver URL de la imagen del profesional | Invocado internamente por consulta SQL |
| 3 | `uti_ge_excepciones_pkg.p_grabar_log` | `uti_` | Procedimiento | Persistir registro técnico del error en tkr_errores | Bloque WHEN OTHERS ante fallos |

```json
// JSON ENTRADA
{
  "id_usuario": 47,
  "fecha_desde": "2026-01-01",
  "fecha_hasta": "2026-12-31"
}
```

```json
// JSON SALIDA
{
  "codigo": 0,
  "mensaje": "Ausencias consultadas exitosamente",
  "ausencias": [
    {
      "id": 501,
      "id_usuario": 47,
      "nombre_completo": "Carlos Andrés Mendoza",
      "fecha_inicial": "2026-12-24",
      "fecha_final": "2026-12-31",
      "motivo": "Vacaciones de fin de año"
    }
  ]
}
```

---

## Método: p_eliminar_ausencia

### 1. Descripción en Lenguaje Natural
Elimina un registro de ausencia previamente configurado a partir de su clave primaria (`id`):
- Valida la presencia del identificador obligatorio.
- Verifica en la capa de persistencia DAO que el registro exista antes de intentar su borrado.
- Delega en el DAO la supresión física del registro.
- Confirma atómicamente la transacción con commit gobernado y emite respuesta de confirmación.

### 2. Decisiones y Bifurcaciones Lógicas
- **Paso 01 [Validación de Entrada]**: Si el payload es nulo o carece del identificador de la ausencia; Salida inmediata con código -20001 por parámetro ausente
- **Paso 02 [Existencia de Ausencia]**: Si el registro de ausencia no existe en la base de datos; Salida inmediata con código -20002 por ausencia no encontrada (`PKGTKR_AUSENCIAS_PROFESIONAL_DAO.f_existe`)
- **Paso 03 [Eliminación en Persistencia]**: Suprime físicamente el registro de ausencia correspondiente a la clave primaria; `PKGTKR_AUSENCIAS_PROFESIONAL_DAO.p_eliminar`
- **Paso 04 [Confirmación Transaccional]**: Confirma todos los cambios en la base de datos de manera atómica y controlada; `p_do_commit`
- **Paso 05 [Control Forense de Excepciones]**: Si ocurre un fallo en el borrado; Revierte la transacción, almacena la traza del error (`uti_ge_excepciones_pkg.p_grabar_log`) y retorna error

### 3. Mapa de Objetos Invocados y Llamados
| Orden | Nombre Exacto del Objeto Invocado | Capa / Familia | Tipo | Propósito de la Invocación | Condición / Momento |
| :---: | :--- | :--- | :--- | :--- | :--- |
| 1 | `PKGTKR_AUSENCIAS_PROFESIONAL_DAO.f_existe` | `DAO` | Función | Comprobar existencia del registro por clave primaria | Previo a invocar eliminación |
| 2 | `PKGTKR_AUSENCIAS_PROFESIONAL_DAO.p_eliminar` | `DAO` | Procedimiento | Suprimir físicamente la ausencia en tkr_ausencias_profesional | Si el registro existe |
| 3 | `p_do_commit` | `Transaccional` | Procedimiento | Confirmar cambios de forma controlada | Al culminar la eliminación física |
| 4 | `uti_ge_excepciones_pkg.p_grabar_log` | `uti_` | Procedimiento | Registrar información forense del incidente en tkr_errores | Bloque WHEN OTHERS ante fallos |

```json
// JSON ENTRADA
{
  "id": 501
}
```

```json
// JSON SALIDA
{
  "codigo": 0,
  "mensaje": "Ausencia eliminada exitosamente"
}
```

---

## Método: p_eliminar_horarios_vigencia

### 1. Descripción en Lenguaje Natural
Elimina todos los horarios de un profesional asociados a un rango de vigencia de fechas específico, advirtiendo al usuario si existen ausencias registradas dentro de dicho período:
- Valida la presencia obligatoria de `id_usuario` y `fecha_inicial`.
- Suprime físicamente de la tabla de horarios todos los turnos que coincidan con la vigencia especificada.
- Consulta en la tabla de ausencias si existen períodos no laborables registrados dentro del intervalo borrado.
- Si existen ausencias, añade un mensaje de advertencia e informa la cantidad de ausencias para que el usuario determine si amerita gestionarlas manualmente.
- Confirma atómicamente la transacción con commit controlado y retorna la respuesta estructurada.

### 2. Decisiones y Bifurcaciones Lógicas
- **Paso 01 [Validación de Entrada]**: Si el payload es nulo o faltan el usuario y la fecha inicial; Salida inmediata con código -20001 por parámetros requeridos incompletos
- **Paso 02 [Eliminación Mono-Tabla de Turnos]**: Suprime todos los turnos del profesional correspondientes al rango de vigencia indicado; `pkgca_tkr_horarios_profesional.p_borrar_x_rango_fechas`
- **Paso 03 [Verificación de Ausencias en el Período - Bifurcación]**: Si existen ausencias registradas dentro de la vigencia eliminada; Asigna indicador de advertencia al mensaje informativo y vuelve al flujo principal (`pkgca_tkr_ausencias_profesional.f_contar_ausencias_rango`)
- **Paso 04 [Confirmación Transaccional]**: Confirma todos los cambios en la base de datos de manera atómica y controlada; `p_do_commit`
- **Paso 05 [Control Forense de Excepciones]**: Ante fallos no controlados; Revierte las operaciones, registra el incidente forense en la bitácora de errores (`uti_ge_excepciones_pkg.p_grabar_log`) y retorna error

### 3. Mapa de Objetos Invocados y Llamados
| Orden | Nombre Exacto del Objeto Invocado | Capa / Familia | Tipo | Propósito de la Invocación | Condición / Momento |
| :---: | :--- | :--- | :--- | :--- | :--- |
| 1 | `pkgca_tkr_horarios_profesional.p_borrar_x_rango_fechas` | `pkgca_` | Procedimiento | Eliminar los turnos del rango de fechas en tkr_horarios_profesional | Tras validar parámetros obligatorios |
| 2 | `pkgca_tkr_ausencias_profesional.f_contar_ausencias_rango` | `pkgca_` | Función | Contar ausencias registradas en el período eliminado | Bifurcación: Si existen ausencias (vuelve al flujo) |
| 3 | `p_do_commit` | `Transaccional` | Procedimiento | Confirmar cambios de forma controlada | Al culminar las operaciones en base de datos |
| 4 | `uti_ge_excepciones_pkg.p_grabar_log` | `uti_` | Procedimiento | Persistir registro técnico del error en tkr_errores | Bloque WHEN OTHERS ante fallos |

```json
// JSON ENTRADA
{
  "id_usuario": 47,
  "fecha_inicial": "2026-12-01",
  "fecha_final": "2026-12-31"
}
```

```json
// JSON SALIDA
{
  "codigo": 0,
  "mensaje": "Horarios de la vigencia eliminados exitosamente. Existen 2 ausencia(s) registradas en este periodo; verifique si requiere eliminarlas.",
  "id_usuario": 47,
  "tiene_ausencias": 1,
  "cantidad_ausencias": 2
}
```

---

## Método: p_actualizar_trabaja_festivos

### 1. Descripción en Lenguaje Natural
Actualiza la configuración de trabajo en días festivos y domingos para un usuario médico, ofreciendo la opción de eliminar de forma automática los horarios configurados para el día domingo:
- Valida los parámetros obligatorios `id_usuario` y el indicador `trabaja_festivos` (restringido a `'S'` o `'N'`).
- Actualiza la columna correspondiente en la tabla de usuarios.
- Si el usuario pasa a no trabajar festivos (`'N'`) y se solicita expresamente el borrado de domingos (`borrar_domingos = 1`), elimina atómicamente todos los turnos del día domingo (`dia_semana = 'DO'`).
- Confirma atómicamente los cambios mediante commit controlado y retorna la respuesta de éxito.

### 2. Decisiones y Bifurcaciones Lógicas
- **Paso 01 [Validación de Entrada]**: Si el payload es nulo, no especifica el usuario o el valor no es 'S' ni 'N'; Salida inmediata con código -20001 o -20009 por formato de indicador inválido
- **Paso 02 [Actualización de Indicador en Usuario]**: Actualiza la bandera de trabajo en festivos del usuario en la tabla de cuentas; `pkgca_tkr_usuarios.p_actualizar_trabaja_festivos`
- **Paso 03 [Eliminación de Turnos Dominicales - Bifurcación]**: Si el profesional desactiva festivos y se instruye borrar domingos; Suprime los turnos registrados para el día domingo y vuelve al flujo principal (`pkgca_tkr_horarios_profesional.p_borrar_x_dia_semana`)
- **Paso 04 [Confirmación Transaccional]**: Confirma todos los cambios en la base de datos de manera atómica y controlada; `p_do_commit`
- **Paso 05 [Control Forense de Excepciones]**: Ante errores en la actualización; Revierte los cambios, almacena el incidente en la bitácora forense (`uti_ge_excepciones_pkg.p_grabar_log`) y retorna error

### 3. Mapa de Objetos Invocados y Llamados
| Orden | Nombre Exacto del Objeto Invocado | Capa / Familia | Tipo | Propósito de la Invocación | Condición / Momento |
| :---: | :--- | :--- | :--- | :--- | :--- |
| 1 | `pkgca_tkr_usuarios.p_actualizar_trabaja_festivos` | `pkgca_` | Procedimiento | Actualizar columna trabaja_festivos en tkr_usuarios | Tras validar entrada |
| 2 | `pkgca_tkr_horarios_profesional.p_borrar_x_dia_semana` | `pkgca_` | Procedimiento | Suprimir turnos de domingo en tkr_horarios_profesional | Bifurcación: Si trabaja_festivos='N' y borrar_domingos=1 (vuelve al flujo) |
| 3 | `p_do_commit` | `Transaccional` | Procedimiento | Confirmar cambios de forma controlada | Al finalizar las actualizaciones |
| 4 | `uti_ge_excepciones_pkg.p_grabar_log` | `uti_` | Procedimiento | Registrar información forense en tkr_errores | Bloque WHEN OTHERS ante fallos |

```json
// JSON ENTRADA
{
  "id_usuario": 47,
  "trabaja_festivos": "N",
  "borrar_domingos": 1
}
```

```json
// JSON SALIDA
{
  "codigo": 0,
  "mensaje": "Configuración de festivos actualizada exitosamente. Se eliminaron los turnos del día domingo."
}
```

---

## Método: p_sincornizar_agenda

### 1. Descripción en Lenguaje Natural
Sincroniza los slots y bitmaps de disponibilidad horaria de un profesional en `tkr_disponibilidad_bitmap` al momento de grabar o actualizar un horario:
- Valida los parámetros de entrada (`id_usuario` o `id_profesional` obligatorio, `fecha` para un día específico o `fecha_inicial` y `fecha_final` opcionales en formato `YYYY-MM-DD`), tomando como inicio mínimo `TRUNC(f_fecha_actual)` (hora de Bogotá, Colombia).
- Verifica y apertura telemetría institucional si se encuentra activa.
- Delega a `PKGCN_HORARIOS.p_sincronizar_agenda_slots` el cálculo día por día de los slots disponibles según los horarios vigentes (`POR_DIA` > `PERSONALIZADO` > `BASE`), marcando como ocupados los intervalos en los que existan registros en `tkr_citas` entre `fecha_inicio_cita` y `fecha_final_cita` con `id_estado_cita IN (2, 3)`.
- Confirma atómicamente los cambios mediante `p_do_commit`, cierra telemetría y retorna el resumen de días sincronizados y citas ocupadas.

### 2. Decisiones y Bifurcaciones Lógicas
- **Decisión 1 [Validación de Entrada]**: Si el payload es nulo o carece de `id_usuario`; Salida inmediata con código -20001 por parámetros obligatorios ausentes
- **Decisión 2 [Validación de Formato de Fechas]**: Si `fecha_inicial` o `fecha_final` no cumplen el formato `YYYY-MM-DD`; Salida inmediata con código -20005 por formato de fecha inválido
- **Decisión 3 [Evaluación de Trazabilidad]**: Si `uti_manejo_trazas_pkg.f_debe_trazar` retorna TRUE; Inicia traza en `tkr_traza_ejecucion` y vuelve al flujo principal (`uti_manejo_trazas_pkg.p_iniciar_traza`)
- **Paso 4 [Sincronización de Slots y Citas Ocupadas]**: Cruza horarios vigentes con `tkr_citas` (`id_estado_cita IN (2, 3)` entre `fecha_inicio_cita` y `fecha_final_cita`) y actualiza `tkr_disponibilidad_bitmap`; `PKGCN_HORARIOS.p_sincronizar_agenda_slots`
- **Paso 5 [Confirmación Transaccional]**: Confirma los cambios de manera controlada; `p_do_commit`
- **Decisión 6 [Cierre de Telemetría]**: Si la traza está activa; Registra fin exitoso de la ejecución y vuelve al flujo principal (`uti_manejo_trazas_pkg.p_finalizar_traza`)

### 3. Mapa de Objetos Invocados y Llamados
| Orden | Nombre Exacto del Objeto Invocado | Capa / Familia | Tipo | Propósito de la Invocación | Condición / Momento |
| :---: | :--- | :--- | :--- | :--- | :--- |
| 1 | `uti_manejo_trazas_pkg.f_debe_trazar` | `uti_` | Función | Verificar si la telemetría está activa para el método | Al inicio del proceso |
| 2 | `uti_manejo_trazas_pkg.p_iniciar_traza` | `uti_` | Procedimiento | Apertura de registro en tkr_traza_ejecucion | Si f_debe_trazar = TRUE |
| 3 | `pkgtkr_parametros_dao.f_existe` | `DAO` | Función | Consultar en `tkr_parametros` (`id = 8`) la cantidad de días a sincronizar (`valor_parametro`, o 60 por defecto) | Cuando no se informa `fecha_final` (horario base) |
| 4 | `pkgca_tkr_usuarios.f_trabaja_festivos` | `pkgca_` | Función | Consultar indicador trabaja_festivos del profesional | Previo a evaluar días del rango |
| 5 | `pkgca_tkr_tiempos_atencion.f_obtener_duracion_cita` | `pkgca_` | Función | Obtener duración en minutos de la cita del profesional | Previo a calcular slots |
| 6 | `PKGCN_HORARIOS.f_consultar_citas_ocupadas` | `pkgcn_` | Función | Consultar citas ocupadas en tkr_citas (estados 2, 3) | Previo a recorrer fechas |
| 7 | `pkgca_tkr_festivos.f_es_festivo` | `pkgca_` | Función | Validar si la fecha es festivo nacional | Por cada día del rango |
| 8 | `pkgca_tkr_ausencias_profesional.f_existe_ausencia` | `pkgca_` | Función | Validar si el profesional tiene ausencia en la fecha | Por cada día del rango |
| 9 | `pkgca_tkr_horarios_profesional.f_consultar_vigentes_fecha` | `pkgca_` | Función | Obtener turnos vigentes del profesional para la fecha | Si no tiene ausencia en el día |
| 10 | `PKGCN_HORARIOS.p_sincronizar_agenda_slots` | `pkgcn_` | Procedimiento | Persistir en un único MERGE los bitmaps y slots del día | Por cada día sincronizado |
| 11 | `p_do_commit` | `Transaccional` | Procedimiento | Confirmar cambios de forma controlada | Éxito sin excepciones |
| 12 | `uti_manejo_trazas_pkg.p_finalizar_traza` | `uti_` | Procedimiento | Cerrar telemetría con estado exitoso | Antes de retornar |
| 13 | `uti_manejo_trazas_pkg.p_finalizar_traza_error` | `uti_` | Procedimiento | Cerrar telemetría con estado ERROR | Bloque WHEN OTHERS |
| 14 | `uti_ge_excepciones_pkg.p_grabar_log` | `uti_` | Procedimiento | Persistir registro forense en tkr_errores | Bloque WHEN OTHERS |

```json
// JSON ENTRADA
{
  "id_usuario": 47,
  "fecha_inicial": "2026-12-01",
  "fecha_final": "2026-12-31"
}
```

```json
// JSON SALIDA
{
  "codigo": 0,
  "mensaje": "Agenda y slots sincronizados exitosamente.",
  "id_usuario": 47,
  "dias_sincronizados": 31,
  "citas_ocupadas": 8
}
```
