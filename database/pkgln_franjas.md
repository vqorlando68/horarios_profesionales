# Diagrama y Flujo de Información: PKGLN_FRANJAS

## Método: p_consultar_franjas

### 1. Descripción en Lenguaje Natural
Permite consultar el listado integral de franjas de atención configuradas para un profesional médico:
- Valida la obligatoriedad del payload de entrada y la presencia del identificador del profesional (`id_usuario`).
- Delega en el caso de negocio la consulta multi-tabla entre turnos y convenios activos, ordenando los registros cronológicamente de Lunes a Domingo y por hora inicial.
- Retorna el arreglo formateado con el identificador de la franja, día de la semana, rango de horas, fechas de vigencia (YYYY-MM-DD), aseguramiento (Voluntario/Obligatorio), datos del convenio asociado y modalidad de atención (Virtual, Domiciliaria o ambas).
- Registra cualquier fallo inesperado en la bitácora forense de errores antes de responder al cliente.

### 2. Decisiones y Bifurcaciones Lógicas
- **Paso 01 [Validación de Entrada]**: Si el payload de entrada es nulo o no contiene el identificador del profesional; Salida inmediata con código -20001 por parámetro obligatorio faltante
- **Paso 02 [Consulta de Franjas y Convenios]**: Consulta la lista completa de turnos activos del profesional formateados en estructura jerárquica con detalles de aseguramiento, convenio y modalidad; `pkgcn_franjas.p_consultar_franjas_json`
- **Paso 03 [Control Forense de Excepciones]**: Si ocurre cualquier error imprevisto en la ejecución; Registra la traza forense del fallo en la bitácora de errores (`uti_ge_excepciones_pkg.p_grabar_log`) y retorna error

### 3. Mapa de Objetos Invocados y Llamados
| Orden | Nombre Exacto del Objeto Invocado | Capa / Familia | Tipo | Propósito de la Invocación | Condición / Momento |
| :---: | :--- | :--- | :--- | :--- | :--- |
| 1 | `pkgcn_franjas.p_consultar_franjas_json` | `pkgcn_` | Procedimiento | Ejecutar consulta multi-tabla con convenios y generar JSON de salida | En flujo principal tras validar entrada |
| 2 | `uti_ge_excepciones_pkg.p_grabar_log` | `uti_` | Procedimiento | Registrar información forense del incidente en la bitácora de errores | Bloque WHEN OTHERS ante fallos |

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
  "mensaje": "Franjas de atención consultadas exitosamente",
  "franjas": [
    {
      "id": 101,
      "dia_semana": "LU",
      "hora_desde": "08:00",
      "hora_hasta": "12:00",
      "fecha_inicial": "2026-01-01",
      "fecha_final": "2026-12-31",
      "id_tipo_aseguramiento": 1,
      "tipo_atencion": "V",
      "tipo_aseguramiento": "Voluntario",
      "id_convenio": null,
      "nombre_convenio": null,
      "modalidad": "V",
      "activo": 1
    }
  ]
}
```

---

## Método: p_guardar_franjas

### 1. Descripción en Lenguaje Natural
Gestiona el registro, edición y sincronización transaccional de franjas de atención por profesional:
- Valida la integridad del payload JSON, estructura de turnos, coherencia cronológica de horas (`hora_desde < hora_hasta`), días canónicos (`LU`..`DO`) y tipos de aseguramiento válidos.
- Comprueba si el médico tiene habilitado laborar domingos en caso de incluir franjas en dicho día, impidiendo la asignación si no cuenta con la autorización respectiva.
- Realiza una validación cruzada en memoria dentro del arreglo recibido para asegurar que no existan horas solapadas en el mismo día y convenio.
- Controla el borrado previo según la modalidad solicitada: reemplazo total de la configuración histórica del médico o depuración quirúrgica de la vigencia origen seleccionada para evitar auto-traslapes durante modificaciones.
- Aplica las reglas de negocio de base de datos: garantiza que solo exista una única Franja Base (sin fecha final) y verifica que las franjas con fecha fin no se traslapen con registros previamente guardados.
- Desestructura el JSON e inserta masivamente los nuevos registros relacionales en el sistema.
- Confirma atómicamente la transacción con commit controlado o efectúa rollback con registro forense en caso de fallo.

### 2. Decisiones y Bifurcaciones Lógicas
- **Paso 01 [Validación de Entrada]**: Si el payload de entrada es nulo o no especifica el identificador del usuario; Salida inmediata con código -20001 por datos obligatorios ausentes
- **Paso 02 [Validación Estructural de Franjas]**: Si algún elemento del arreglo no cumple con el día canónico, formato de fechas, coherencia cronológica de horas o tipo de aseguramiento válido; Salida inmediata con código -20002 o -20003 por formato horario inválido
- **Paso 03 [Regla de Turnos en Domingo - Bifurcación]**: Si la franja corresponde al día domingo y el profesional no labora en festivos; Salida inmediata con código -20010 por restricción dominical (`pkgca_tkr_usuarios.f_trabaja_festivos`)
- **Paso 04 [Validación de Solapamiento en Memoria]**: Si dos franjas del mismo día y convenio presentan traslape de horarios dentro del mismo intervalo de fechas; Salida inmediata con código -20008 por cruce de franjas
- **Paso 05 [Limpieza de Vigencia Histórica Total - Bifurcación]**: Si se seleccionó la modalidad de reemplazo integral; Elimina todas las franjas previas del profesional y vuelve al flujo principal (`pkgca_tkr_franjas_profesional.p_borrar_x_profesional`)
- **Paso 06 [Limpieza de Vigencia Específica - Bifurcación]**: Si se está editando una vigencia previa o sustituyendo un rango de fechas; Elimina las franjas previas acotadas a dicho período y vuelve al flujo principal (`pkgca_tkr_franjas_profesional.p_borrar_x_rango_fechas`)
- **Paso 07 [Unicidad de Franja Base]**: Si se intenta registrar una nueva franja sin fecha final cuando el profesional ya posee una franja base registrada; Salida inmediata con código -20011 por existencia previa de franja base (`pkgca_tkr_franjas_profesional.f_existe_franja_base`)
- **Paso 08 [Validación de No Traslape en Base de Datos]**: Si alguna de las franjas con fecha límite colisiona con turnos previamente almacenados para ese rango de fechas; Salida inmediata con código -20009 por conflicto de horario en base de datos (`pkgcn_franjas.f_existe_traslape_franja`)
- **Paso 09 [Persistencia Relacional Masiva]**: Descompone el arreglo estructurado mediante tabla relacional e inserta los nuevos turnos en el sistema; `pkgcn_franjas.p_guardar_franjas_profesional`
- **Paso 10 [Confirmación Transaccional]**: Confirma todos los cambios en la base de datos de manera atómica y controlada; `p_do_commit`
- **Paso 11 [Control Forense de Excepciones]**: Ante excepciones imprevistas; Revierte los cambios efectuados, registra el volcado del fallo en la bitácora de errores (`uti_ge_excepciones_pkg.p_grabar_log`) y retorna error

### 3. Mapa de Objetos Invocados y Llamados
| Orden | Nombre Exacto del Objeto Invocado | Capa / Familia | Tipo | Propósito de la Invocación | Condición / Momento |
| :---: | :--- | :--- | :--- | :--- | :--- |
| 1 | `pkgca_tkr_usuarios.f_trabaja_festivos` | `pkgca_` | Función | Validar si el médico tiene autorización para laborar turnos dominicales | Si se procesa franja de día domingo |
| 2 | `pkgca_tkr_franjas_profesional.p_borrar_x_profesional` | `pkgca_` | Procedimiento | Eliminar la totalidad de franjas del profesional | Bifurcación: Si reemplazar_todo = 1 (vuelve al flujo) |
| 3 | `pkgca_tkr_franjas_profesional.p_borrar_x_rango_fechas` | `pkgca_` | Procedimiento | Eliminar franjas de una vigencia específica para edición controlada | Bifurcación: Si se edita vigencia (vuelve al flujo) |
| 4 | `pkgca_tkr_franjas_profesional.f_existe_franja_base` | `pkgca_` | Función | Comprobar si ya existe una franja base abierta sin fecha fin | Previo a insertar franja sin fecha final |
| 5 | `pkgcn_franjas.f_existe_traslape_franja` | `pkgcn_` | Función | Detectar cruces de horario y fechas contra turnos en base de datos | Para franjas personalizadas con fecha fin |
| 6 | `pkgcn_franjas.p_guardar_franjas_profesional` | `pkgcn_` | Procedimiento | Insertar masivamente turnos usando extracción relacional JSON_TABLE | En flujo principal si no hubo traslapes |
| 7 | `p_do_commit` | `Transaccional` | Procedimiento | Confirmar cambios de forma controlada | Flujo principal al completar operaciones |
| 8 | `uti_ge_excepciones_pkg.p_grabar_log` | `uti_` | Procedimiento | Registrar volcado técnico de excepción en tkr_errores | Bloque WHEN OTHERS ante fallos |

```json
// JSON ENTRADA
{
  "id_usuario": 47,
  "reemplazar_todo": 0,
  "reemplazar_vigencia": 1,
  "fecha_inicial_origen": "2026-01-01",
  "fecha_final_origen": "2026-12-31",
  "franjas": [
    {
      "dia_semana": "LU",
      "hora_desde": "08:00",
      "hora_hasta": "12:00",
      "fecha_inicial": "2026-01-01",
      "fecha_final": "2026-12-31",
      "id_tipo_aseguramiento": 1,
      "tipo_atencion": "V",
      "modalidad": "V",
      "id_convenio": null
    }
  ]
}
```

```json
// JSON SALIDA
{
  "codigo": 0,
  "mensaje": "Franjas de atención guardadas exitosamente"
}
```

---

## Método: p_eliminar_franjas_vigencia

### 1. Descripción en Lenguaje Natural
Permite eliminar de forma permanente todas las franjas de atención pertenecientes a una vigencia específica de un profesional:
- Valida los parámetros requeridos (`id_usuario` y `fecha_inicial`).
- Invoca la capa de acceso a datos para suprimir físicamente los turnos correspondientes al rango de vigencia seleccionado.
- Confirma atómicamente la transacción con commit controlado y retorna la respuesta de éxito o registra el incidente en caso de anomalía.

### 2. Decisiones y Bifurcaciones Lógicas
- **Paso 01 [Validación de Entrada]**: Si el payload viene nulo o faltan el identificador del profesional o la fecha de inicio; Salida inmediata con código -20001 por parámetros incompletos
- **Paso 02 [Eliminación de Franjas por Vigencia]**: Elimina todos los registros de franjas del profesional delimitados por la vigencia especificada; `pkgca_tkr_franjas_profesional.p_borrar_x_rango_fechas`
- **Paso 03 [Confirmación Transaccional]**: Confirma todos los cambios en la base de datos de manera atómica y controlada; `p_do_commit`
- **Paso 04 [Control Forense de Excepciones]**: Si ocurre cualquier error no controlado; Revierte la transacción, almacena el registro forense en la bitácora de incidentes (`uti_ge_excepciones_pkg.p_grabar_log`) y retorna error

### 3. Mapa de Objetos Invocados y Llamados
| Orden | Nombre Exacto del Objeto Invocado | Capa / Familia | Tipo | Propósito de la Invocación | Condición / Momento |
| :---: | :--- | :--- | :--- | :--- | :--- |
| 1 | `pkgca_tkr_franjas_profesional.p_borrar_x_rango_fechas` | `pkgca_` | Procedimiento | Eliminar físicamente los registros del rango de vigencia indicado | Tras validar parámetros obligatorios |
| 2 | `p_do_commit` | `Transaccional` | Procedimiento | Confirmar cambios de forma controlada | Al culminar la eliminación física |
| 3 | `uti_ge_excepciones_pkg.p_grabar_log` | `uti_` | Procedimiento | Persistir registro técnico del error en tkr_errores | Bloque WHEN OTHERS ante fallos |

```json
// JSON ENTRADA
{
  "id_usuario": 47,
  "fecha_inicial": "2026-01-01",
  "fecha_final": "2026-12-31"
}
```

```json
// JSON SALIDA
{
  "codigo": 0,
  "mensaje": "Vigencia de franjas eliminada exitosamente"
}
```
