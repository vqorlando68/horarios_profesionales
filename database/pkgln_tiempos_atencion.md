# PKGLN_TIEMPOS_ATENCION

Orquestador transaccional de dominio para la configuración, consulta y eliminación de tiempos de atención (duración en minutos) por profesional y tipo de aseguramiento.

## Métodos

### 1. `p_consultar_tiempos`
- **Propósito**: Consulta la lista de tipos de aseguramiento con la duración en minutos configurada para un profesional (o NULL si no está configurada).
- **Entrada JSON**:
  ```json
  {
    "id_usuario": 47
  }
  ```
- **Salida JSON**:
  ```json
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
        "configurado": 1,
        "activo": 1
      },
      {
        "id": null,
        "id_usuario": 47,
        "id_tipo_aseguramiento": 2,
        "tipo_aseguramiento": "Obligatorio",
        "duracion": null,
        "configurado": 0,
        "activo": 1
      }
    ]
  }
  ```
- **Dependencias**:
  - `pkgcn_tiempos_atencion.p_consultar_tiempos_json`
  - `uti_ge_excepciones_pkg.p_grabar_log`

### 2. `p_guardar_tiempos`
- **Propósito**: Valida e inserta/actualiza (Merge) los tiempos de atención de un profesional. No es obligatorio configurar ambos tipos; se pueden guardar individualmente o en lote.
- **Entrada JSON**:
  ```json
  {
    "id_usuario": 47,
    "tiempos": [
      { "id_tipo_aseguramiento": 1, "duracion": 20 }
    ]
  }
  ```
- **Reglas de Negocio**:
  - `id_usuario` es obligatorio.
  - El arreglo `tiempos` procesa los elementos con `duracion > 0`.
  - Transacción atómica: `COMMIT` si todo es exitoso, `ROLLBACK` y registro en log ante error.
- **Dependencias**:
  - `pkgcn_tiempos_atencion.p_guardar_tiempos_profesional`
  - `uti_ge_excepciones_pkg.p_grabar_log`

### 3. `p_eliminar_tiempo`
- **Propósito**: Elimina la configuración de tiempo de atención de un profesional para un tipo de aseguramiento específico.
- **Entrada JSON**:
  ```json
  {
    "id_usuario": 47,
    "id_tipo_aseguramiento": 2
  }
  ```
- **Salida JSON**:
  ```json
  {
    "codigo": 0,
    "mensaje": "Tiempo de atención eliminado exitosamente."
  }
  ```
- **Dependencias**:
  - `pkgcn_tiempos_atencion.p_eliminar_tiempo_profesional`
  - `uti_ge_excepciones_pkg.p_grabar_log`
