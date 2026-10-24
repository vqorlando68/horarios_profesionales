# Diagrama y Flujo de Información: PKGLN_TIEMPOS_ATENCION

## Método: p_consultar_tiempos

### 1. Descripción en Lenguaje Natural
Consulta la parametrización de tiempos de atención (duración en minutos para atención virtual y domiciliaria) configurados para un profesional según el tipo de aseguramiento:
- Valida la presencia del payload JSON y del identificador del profesional (`id_usuario`).
- Delega en el caso de negocio la consulta relacional con los tipos de aseguramiento registrados (Voluntario, Obligatorio), identificando las duraciones asignadas y los tipos pendientes por configurar.
- Retorna el listado consolidado en formato JSON estructurado con el estado de activación y configuración de cada tipo de aseguramiento.
- En caso de presentarse una excepción imprevista, captura el código y mensaje de error, persiste el incidente forense en la bitácora técnica y retorna la respuesta estructurada de error.

### 2. Decisiones y Bifurcaciones Lógicas
- **Paso 01 [Validación de Entrada]**: Si el payload de entrada es nulo o no contiene el identificador del usuario; Salida inmediata con código -20001 por datos obligatorios faltantes
- **Paso 02 [Consulta de Duraciones por Aseguramiento]**: Consulta la configuración de tiempos de atención para citas virtuales y domiciliarias cruzando con los tipos de aseguramiento activos; `pkgcn_tiempos_atencion.p_consultar_tiempos_json`
- **Paso 03 [Control Forense de Excepciones]**: Ante cualquier error inesperado en la base de datos; Almacena el incidente técnico en la bitácora de errores (`uti_ge_excepciones_pkg.p_grabar_log`) y retorna error

### 3. Mapa de Objetos Invocados y Llamados
| Orden | Nombre Exacto del Objeto Invocado | Capa / Familia | Tipo | Propósito de la Invocación | Condición / Momento |
| :---: | :--- | :--- | :--- | :--- | :--- |
| 1 | `pkgcn_tiempos_atencion.p_consultar_tiempos_json` | `pkgcn_` | Procedimiento | Realizar consulta relacional multi-tabla y generar estructura JSON | En flujo principal tras validar entrada |
| 2 | `uti_ge_excepciones_pkg.p_grabar_log` | `uti_` | Procedimiento | Registrar información forense de la anomalía en tkr_errores | Bloque WHEN OTHERS ante fallos |

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
  "mensaje": "Tiempos de atención consultados exitosamente",
  "tiempos": [
    {
      "id": 1,
      "id_usuario": 47,
      "id_tipo_aseguramiento": 1,
      "tipo_aseguramiento": "Voluntario",
      "duracion": 20,
      "duracion_domiciliaria": 45,
      "configurado": 1,
      "activo": 1
    },
    {
      "id": null,
      "id_usuario": 47,
      "id_tipo_aseguramiento": 2,
      "tipo_aseguramiento": "Obligatorio",
      "duracion": null,
      "duracion_domiciliaria": null,
      "configurado": 0,
      "activo": 1
    }
  ]
}
```

---

## Método: p_guardar_tiempos

### 1. Descripción en Lenguaje Natural
Gestiona el registro y sincronización atómica de los tiempos de atención por profesional para una o múltiples modalidades y tipos de aseguramiento:
- Valida la integridad de los parámetros requeridos (`id_usuario` y arreglo `tiempos`).
- Valida que al menos uno de los elementos del arreglo posea una duración válida (entero positivo mayor a cero) para cita virtual o atención domiciliaria.
- Invoca la lógica de negocio multi-tabla para desestructurar el arreglo JSON y aplicar la persistencia atómica mediante operación MERGE.
- Confirma la transacción en la base de datos de manera definitiva o ejecuta rollback con registro forense en caso de fallo.

### 2. Decisiones y Bifurcaciones Lógicas
- **Paso 01 [Validación de Entrada]**: Si el payload de entrada es nulo o no contiene el identificador del usuario; Salida inmediata con código -20001 por datos obligatorios ausentes
- **Paso 02 [Validación Estructural de Tiempos]**: Si la colección de tiempos no contiene elementos o carece del tipo de aseguramiento; Salida inmediata con código -20002 o -20003 por formato de tiempo inválido
- **Paso 03 [Validación de Duraciones]**: Si la duración virtual o domiciliaria especificada no es un número entero mayor a 0; Salida inmediata con código -20004 o -20005 por duración numérica inválida
- **Paso 04 [Persistencia Relacional de Tiempos]**: Inserta o actualiza mediante combinación atómica los tiempos de atención configurados para el profesional; `pkgcn_tiempos_atencion.p_guardar_tiempos_profesional`
- **Paso 05 [Transacción Exitosa y Cierre]**: Confirma todos los cambios en la base de datos de manera atómica y controlada; `COMMIT`
- **Paso 06 [Control Forense de Excepciones]**: En caso de fallo durante la operación; Revierte los cambios aplicados, registra la traza forense del error (`uti_ge_excepciones_pkg.p_grabar_log`) y retorna error

### 3. Mapa de Objetos Invocados y Llamados
| Orden | Nombre Exacto del Objeto Invocado | Capa / Familia | Tipo | Propósito de la Invocación | Condición / Momento |
| :---: | :--- | :--- | :--- | :--- | :--- |
| 1 | `pkgcn_tiempos_atencion.p_guardar_tiempos_profesional` | `pkgcn_` | Procedimiento | Procesar JSON_TABLE y realizar MERGE relacional en tkr_tiempos_atencion | Tras validar estructura y duraciones |
| 2 | `COMMIT` | `Transaccional` | Sentencia SQL | Confirmar atómicamente las operaciones en la base de datos | Al finalizar la persistencia sin errores |
| 3 | `uti_ge_excepciones_pkg.p_grabar_log` | `uti_` | Procedimiento | Registrar información forense del incidente en tkr_errores | Bloque WHEN OTHERS ante fallos |

```json
// JSON ENTRADA
{
  "id_usuario": 47,
  "tiempos": [
    {
      "id_tipo_aseguramiento": 1,
      "duracion": 20,
      "duracion_domiciliaria": 45
    }
  ]
}
```

```json
// JSON SALIDA
{
  "codigo": 0,
  "mensaje": "Tiempos de atención guardados exitosamente."
}
```

---

## Método: p_eliminar_tiempo

### 1. Descripción en Lenguaje Natural
Elimina la parametrización de duración asignada a un profesional para un tipo de aseguramiento específico:
- Valida la presencia de los parámetros obligatorios `id_usuario` e `id_tipo_aseguramiento`.
- Invoca la capa de negocio para suprimir físicamente el registro asociado en la tabla de configuración.
- Aplica la confirmación atómica de la transacción y emite mensaje de confirmación al usuario.

### 2. Decisiones y Bifurcaciones Lógicas
- **Paso 01 [Validación de Entrada]**: Si el payload es nulo o no especifica el identificador del usuario o del tipo de aseguramiento; Salida inmediata con código -20001 o -20002 por parámetros faltantes
- **Paso 02 [Eliminación de Configuración]**: Suprime la parametrización de duración del profesional para el tipo de aseguramiento solicitado; `pkgcn_tiempos_atencion.p_eliminar_tiempo_profesional`
- **Paso 03 [Transacción Exitosa y Cierre]**: Confirma todos los cambios en la base de datos de manera atómica y controlada; `COMMIT`
- **Paso 04 [Control Forense de Excepciones]**: Ante excepciones imprevistas; Revierte la transacción, registra el incidente en la bitácora de errores (`uti_ge_excepciones_pkg.p_grabar_log`) y retorna error

### 3. Mapa de Objetos Invocados y Llamados
| Orden | Nombre Exacto del Objeto Invocado | Capa / Familia | Tipo | Propósito de la Invocación | Condición / Momento |
| :---: | :--- | :--- | :--- | :--- | :--- |
| 1 | `pkgcn_tiempos_atencion.p_eliminar_tiempo_profesional` | `pkgcn_` | Procedimiento | Eliminar el registro en tkr_tiempos_atencion para el médico y aseguramiento | Al superar validaciones iniciales |
| 2 | `COMMIT` | `Transaccional` | Sentencia SQL | Confirmar de manera definitiva la supresión del registro | Al completarse el borrado exitoso |
| 3 | `uti_ge_excepciones_pkg.p_grabar_log` | `uti_` | Procedimiento | Persistir registro técnico del error en tkr_errores | Bloque WHEN OTHERS ante fallos |

```json
// JSON ENTRADA
{
  "id_usuario": 47,
  "id_tipo_aseguramiento": 2
}
```

```json
// JSON SALIDA
{
  "codigo": 0,
  "mensaje": "Tiempo de atención eliminado exitosamente."
}
```
