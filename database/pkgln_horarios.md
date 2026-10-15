# Flujo Funcional, Decisiones y Grafo de Dependencias: `PKGLN_HORARIOS`

Este documento describe en lenguaje natural la lógica de negocio, las bifurcaciones de decisión y la secuencia exacta de objetos invocados para cada método del paquete `PKGLN_HORARIOS`. Ha sido estructurado para ser procesado por una herramienta de visualización gráfica de flujos y grafos de dependencias.

---

## 1. Método: `p_listar_profesionales`

### 1.1 Descripción Funcional en Lenguaje Natural
El método recibe un payload opcional en formato JSON (`p_json_entrada`) que puede contener un texto de filtro por nombre o correo electrónico. Valida si la telemetría se encuentra activa en `tkr_traza_config` y, de ser así, apertura una traza técnica. Posteriormente, delega en la capa de negocio `PKGCN_HORARIOS` la consulta de todos los usuarios registrados en `tkr_usuarios` que posean el rol de médico/profesional (`id_rol = 4` en `tkr_roles_usuario`), se encuentren en estado activo (`id_estado_usuario = 1`), concatenando sus nombres y apellidos completos y resolviendo la URL de su fotografía mediante `pkgcn_profesionales.f_url_foto_profesional`. Finalmente, cierra la traza y retorna el JSON consolidado en `p_json_salida`.

### 1.2 Decisiones y Bifurcaciones Lógicas
1. **Extracción y Validación de Entrada:** Si `p_json_entrada` es no nulo, extrae de forma segura `filtro`, `id_usuario_ejecutor`, `codigo_traza` e `ip_origen`. Si el JSON es nulo o inválido, asume valores por defecto sin abortar la consulta general.
2. **Evaluación de Telemetría:** Evalúa `uti_manejo_trazas_pkg.f_debe_trazar`. Si retorna `TRUE`, abre traza con `uti_manejo_trazas_pkg.p_iniciar_traza`. Si es `FALSE`, continúa la ejecución omitiendo el registro de telemetría.
3. **Control de Excepciones:** Ante cualquier fallo inesperado (`WHEN OTHERS`), ejecuta `ROLLBACK`, finaliza la traza en estado de error con `uti_manejo_trazas_pkg.p_finalizar_traza_error`, persiste el volcado forense en `tkr_errores` con `uti_ge_excepciones_pkg.p_grabar_log` y propaga al cliente el error `-20000` con el identificador del incidente.

### 1.3 Secuencia de Llamados y Objetos Invocados

| Orden | Objeto Invocado (Nombre Exacto) | Capa / Familia | Propósito / Condición de Invocación |
| :---: | :--- | :--- | :--- |
| 1 | `uti_manejo_trazas_pkg.f_debe_trazar` | Utilitarios (`uti_`) | Consulta en `tkr_traza_config` si el método debe trazar |
| 2 | `uti_manejo_trazas_pkg.p_iniciar_traza` | Utilitarios (`uti_`) | Apertura el registro de traza en `tkr_traza_ejecucion` si traza activa |
| 3 | `PKGCN_HORARIOS.p_consultar_profesionales_json` | Casos de Negocio (`pkgcn_`) | Ejecuta la consulta multi-tabla con sintaxis tradicional y genera el JSON |
| 4 | `pkgcn_profesionales.f_url_foto_profesional` | Casos de Negocio (`pkgcn_`) | Invocado dentro de la consulta SQL para resolver la foto del médico |
| 5 | `uti_manejo_trazas_pkg.p_finalizar_traza` | Utilitarios (`uti_`) | Cierra la traza con status exitoso |
| 6 | `uti_manejo_trazas_pkg.p_finalizar_traza_error` | Utilitarios (`uti_`) | Cierra la traza con status ERROR en WHEN OTHERS |
| 7 | `uti_ge_excepciones_pkg.p_grabar_log` | Utilitarios (`uti_`) | Persistencia forense en `tkr_errores` en WHEN OTHERS |

---

## 2. Método: `p_guardar_horarios`

### 2.1 Descripción Funcional en Lenguaje Natural
Permite al profesional de salud o al administrador configurar su disponibilidad semanal de atención, soportando la configuración de **múltiples rangos de horas para el mismo día de la semana** (por ejemplo: Lunes de 08:00 a 12:00 y de 14:00 a 18:00) y **asociando un rango de vigencia por fechas**:
- **`fecha_inicial`**: Fecha a partir de la cual entra en vigencia el horario (obligatoria).
- **`fecha_final`**: Fecha de finalización del horario (opcional). Si está informada, el horario aplica exclusivamente entre `fecha_inicial` y `fecha_final`. Si es `NULL`, aplica de forma indefinida a partir de `fecha_inicial`.

Soporta dos modalidades de reemplazo controlado:
1. **Reemplazo Completo (`reemplazar_todo = 1`)**: Elimina todos los horarios históricos del profesional mediante `pkgca_tkr_horarios_profesional.p_borrar_x_profesional`.
2. **Edición o Reemplazo de Vigencia Específica (`reemplazar_todo = 0` con `fecha_inicial_origen` o `reemplazar_vigencia = 1`)**: Si se está modificando una vigencia previamente grabada, invoca `pkgca_tkr_horarios_profesional.p_borrar_x_rango_fechas` para limpiar los horarios previos de dicha vigencia antes de validar contra las demás vigencias de la base de datos e insertar los nuevos turnos. Esto evita falsos positivos por auto-traslape cuando un médico ajusta horarios de un período existente.

Recibe el payload JSON con el ID del profesional, las directivas de reemplazo y el arreglo de rangos horarios. Valida la obligatoriedad del profesional, la validez canónica de los días (`LU`, `MA`, `MI`, `JU`, `VI`, `SA`, `DO`), la coherencia horaria (`hora_desde < hora_hasta`), la coherencia de fechas (`fecha_inicial <= fecha_final`), la restricción de domingos (`trabaja_festivos`) y la ausencia de solapamientos tanto en memoria como contra las demás vigencias registradas en BD mediante `PKGCN_HORARIOS.f_existe_traslape_horario`. Finalmente, inserta los nuevos registros con `PKGCN_HORARIOS.p_guardar_horarios_profesional`, confirma la transacción con `p_do_commit` y responde al cliente.

### 2.2 Decisiones y Bifurcaciones Lógicas
1. **Validación de Parámetro Obligatorio:** Si `p_json_entrada` o `id_usuario` son nulos, dispara error de negocio `-20001`.
2. **Evaluación de Telemetría:** Invoca `uti_manejo_trazas_pkg.f_debe_trazar` e inicia traza si aplica.
3. **Validación de Cada Rango Horario (en memoria):**
   * Si `dia_semana` no pertenece a la lista canónica (`LU`, `MA`, `MI`, `JU`, `VI`, `SA`, `DO`), lanza error `-20002`.
   * Si `hora_desde >= hora_hasta`, lanza error `-20003`.
   * Si `dia_semana = 'DO'` y el usuario no trabaja festivos (`pkgca_tkr_usuarios.f_trabaja_festivos = 'N'`), lanza error `-20010`.
   * Si `fecha_inicial` viene nula o vacía, lanza error `-20004`.
   * Si el formato de `fecha_inicial` no es válido (YYYY-MM-DD), lanza error `-20005`.
   * Si `fecha_final` viene informada pero con formato inválido, lanza error `-20006`.
   * Si `fecha_final < fecha_inicial`, lanza error `-20007` (coherencia cronológica de vigencia).
4. **Validación de No Traslape en Memoria:** Compara de forma cruzada cada par de rangos del mismo día de la semana. Si los rangos de vigencia de fechas se intersecan y simultáneamente las horas se intersecan, aborta con error `-20008` impidiendo registros inconsistentes.
5. **Decisión de Borrado Previo Transaccional:**
   * Si `reemplazar_todo = 1`, invoca `pkgca_tkr_horarios_profesional.p_borrar_x_profesional` para eliminar todos los horarios del médico.
   * Si `fecha_inicial_origen` viene informada, invoca `pkgca_tkr_horarios_profesional.p_borrar_x_rango_fechas` para limpiar la vigencia origen modificada.
   * Si `reemplazar_vigencia = 1`, invoca `pkgca_tkr_horarios_profesional.p_borrar_x_rango_fechas` con el rango de fechas del lote.
6. **Validación de Unicidad de Horario Base:** Si se intenta guardar un Horario Base (`fecha_final IS NULL`) en modo incremental (`reemplazar_todo = 0`), invoca `pkgca_tkr_horarios_profesional.f_existe_horario_base`. Si ya existe otro horario base registrado para el profesional, aborta con error de negocio `-20011`, garantizando que cada profesional solo posea un único Horario Base permanente.
7. **Validación contra Base de Datos (en Modo Incremental / Edición):** La validación de traslape contra base de datos aplica **únicamente para Horarios Personalizados** (`fecha_final` informada). Los horarios sin `fecha_final` (Horario Base) **no realizan validaciones de traslape contra los horarios con `fecha_final`** (solo se rigen por la unicidad del punto 6). Cuando se guarda un Horario Personalizado, invoca `PKGCN_HORARIOS.f_existe_traslape_horario` para verificar que no colisione con otros horarios personalizados (`h.fecha_final IS NOT NULL`). De existir conflicto entre horarios personalizados, aborta con `-20009`.
8. **Inserción Relacional:** Si existen elementos en el arreglo, delega la desestructuración con `JSON_TABLE` e inserción masiva a `PKGCN_HORARIOS.p_guardar_horarios_profesional`.
9. **Control Transaccional Atómico:** Ejecuta `p_do_commit('PKGLN_HORARIOS.p_guardar_horarios')`. Si ocurre algún fallo antes de este punto, jamás se realiza commit.
10. **Control de Excepciones:** En `WHEN OTHERS`, ejecuta `ROLLBACK`, registra error en `uti_ge_excepciones_pkg.p_grabar_log` y propaga con `-20000`.

### 2.3 Secuencia de Llamados y Objetos Invocados

| Orden | Objeto Invocado (Nombre Exacto) | Capa / Familia | Propósito / Condición de Invocación |
| :---: | :--- | :--- | :--- |
| 1 | `uti_manejo_trazas_pkg.f_debe_trazar` | Utilitarios (`uti_`) | Evalúa si la telemetría está activa |
| 2 | `uti_manejo_trazas_pkg.p_iniciar_traza` | Utilitarios (`uti_`) | Inicia traza de ejecución |
| 3 | `pkgca_tkr_usuarios.f_trabaja_festivos` | Acceso No-PK Mono-Tabla (`pkgca_`) | Verifica autorización para laborar domingos |
| 4 | `pkgca_tkr_horarios_profesional.p_borrar_x_profesional` | Acceso No-PK Mono-Tabla (`pkgca_`) | Elimina los horarios previos de la tabla si `reemplazar_todo = 1` |
| 5 | `pkgca_tkr_horarios_profesional.p_borrar_x_rango_fechas` | Acceso No-PK Mono-Tabla (`pkgca_`) | Elimina la vigencia anterior si se edita o `reemplazar_vigencia = 1` |
| 6 | `pkgca_tkr_horarios_profesional.f_existe_horario_base` | Acceso No-PK Mono-Tabla (`pkgca_`) | Verifica unicidad de horario base si el lote entrante tiene fecha_final NULL |
| 7 | `PKGCN_HORARIOS.f_existe_traslape_horario` | Casos de Negocio (`pkgcn_`) | Valida traslapes con horarios restantes si `reemplazar_todo = 0` |
| 8 | `PKGCN_HORARIOS.p_guardar_horarios_profesional` | Casos de Negocio (`pkgcn_`) | Desestructura con `JSON_TABLE` e inserta los rangos con fechas en `tkr_horarios_profesional` |
| 9 | `p_do_commit` | Gobierno Transaccional | Confirma de forma atómica la transacción |
| 10 | `uti_manejo_trazas_pkg.p_finalizar_traza` | Utilitarios (`uti_`) | Cierra la traza en status exitoso |
| 11 | `uti_manejo_trazas_pkg.p_finalizar_traza_error` | Utilitarios (`uti_`) | Cierra la traza en status ERROR si ocurre excepción |
| 12 | `uti_ge_excepciones_pkg.p_grabar_log` | Utilitarios (`uti_`) | Registra el error forense en `tkr_errores` |

---

## 3. Método: `p_consultar_agenda`

### 3.1 Descripción Funcional en Lenguaje Natural
Obtiene la ficha y programación integral de un profesional específico. Recibe el identificador del usuario (`id_usuario`), valida su presencia, verifica trazabilidad y solicita a `PKGCN_HORARIOS` la generación de un JSON consolidado que contiene: datos personales del médico (nombres, apellidos, correo y URL de foto resuelta dinámicamente), colección de rangos horarios activos ordenados cronológicamente por día de la semana y hora, y el historial de ausencias programadas en `tkr_ausencias_profesional`.

### 3.2 Decisiones y Bifurcaciones Lógicas
1. **Validación de Identificador:** Si `id_usuario` no está presente, arroja error de negocio `-20001`.
2. **Telemetría:** Comprueba y registra traza mediante `uti_manejo_trazas_pkg`.
3. **Consulta de Negocio:** Llama a `PKGCN_HORARIOS.p_consultar_agenda_profesional_json`.
4. **Excepciones:** `ROLLBACK`, logging en `tkr_errores` y `-20000`.

### 3.3 Secuencia de Llamados y Objetos Invocados

| Orden | Objeto Invocado (Nombre Exacto) | Capa / Familia | Propósito / Condición de Invocación |
| :---: | :--- | :--- | :--- |
| 1 | `uti_manejo_trazas_pkg.f_debe_trazar` | Utilitarios (`uti_`) | Verifica si la telemetría está activa |
| 2 | `uti_manejo_trazas_pkg.p_iniciar_traza` | Utilitarios (`uti_`) | Apertura la traza técnica |
| 3 | `PKGCN_HORARIOS.p_consultar_agenda_profesional_json` | Casos de Negocio (`pkgcn_`) | Extrae y consolida datos del profesional, horarios y ausencias |
| 4 | `pkgcn_profesionales.f_url_foto_profesional` | Casos de Negocio (`pkgcn_`) | Resuelve la URL de la foto del profesional |
| 5 | `uti_manejo_trazas_pkg.p_finalizar_traza` | Utilitarios (`uti_`) | Cierra la traza con éxito |
| 6 | `uti_manejo_trazas_pkg.p_finalizar_traza_error` | Utilitarios (`uti_`) | Cierra la traza con error en WHEN OTHERS |
| 7 | `uti_ge_excepciones_pkg.p_grabar_log` | Utilitarios (`uti_`) | Log forense en `tkr_errores` |

---

## 4. Método: `p_registrar_ausencia`

### 4.1 Descripción Funcional en Lenguaje Natural
Registra un periodo de tiempo en el que un profesional no prestará servicio (vacaciones, incapacidad, permisos o ausencias programadas) en la tabla `TKR_AUSENCIAS_PROFESIONAL`. Recibe el `id_usuario`, `fecha_inicial` y `fecha_final`. Convierte las fechas desde formato ISO, valida que la fecha inicial no sea superior a la final, prepara el registro `%ROWTYPE` y delega la persistencia al DAO oficial `PKGTKR_AUSENCIAS_PROFESIONAL_DAO.p_insertar`. Tras la persistencia exitosa, asegura los cambios mediante `p_do_commit` y responde al cliente.

### 4.2 Decisiones y Bifurcaciones Lógicas
1. **Validación de Identificador:** Valida `id_usuario` no nulo (error `-20001`).
2. **Validación de Fechas Obligatorias:** Valida que vengan ambas fechas (error `-20002`).
3. **Parseo de Formato de Fechas:** Llama a `f_parsear_fecha`. Si no logra interpretar la fecha, arroja error `-20003`.
4. **Coherencia Temporal:** Si `fecha_inicial > fecha_final`, aborta con error `-20004`.
5. **Persistencia Atómica en DAO:** Asigna el registro y ejecuta `PKGTKR_AUSENCIAS_PROFESIONAL_DAO.p_insertar`.
6. **Commit Controlado:** Ejecuta `p_do_commit('PKGLN_HORARIOS.p_registrar_ausencia')`.
7. **Excepciones:** `ROLLBACK`, traza ERROR y `uti_ge_excepciones_pkg.p_grabar_log`.

### 4.3 Secuencia de Llamados y Objetos Invocados

| Orden | Objeto Invocado (Nombre Exacto) | Capa / Familia | Propósito / Condición de Invocación |
| :---: | :--- | :--- | :--- |
| 1 | `uti_manejo_trazas_pkg.f_debe_trazar` | Utilitarios (`uti_`) | Verifica telemetría |
| 2 | `uti_manejo_trazas_pkg.p_iniciar_traza` | Utilitarios (`uti_`) | Inicia traza de ejecución |
| 3 | `PKGTKR_AUSENCIAS_PROFESIONAL_DAO.p_insertar` | Persistencia (`DAO`) | Inserta el registro en `tkr_ausencias_profesional` |
| 4 | `p_do_commit` | Gobierno Transaccional | Confirma la transacción en la base de datos |
| 5 | `uti_manejo_trazas_pkg.p_finalizar_traza` | Utilitarios (`uti_`) | Cierra la traza exitosa |
| 6 | `uti_manejo_trazas_pkg.p_finalizar_traza_error` | Utilitarios (`uti_`) | Cierra la traza en status ERROR |
| 7 | `uti_ge_excepciones_pkg.p_grabar_log` | Utilitarios (`uti_`) | Registra el fallo en `tkr_errores` |

---

## 5. Método: `p_consultar_ausencias`

### 5.1 Descripción Funcional en Lenguaje Natural
Consulta el catálogo de ausencias registradas pudiendo filtrar por profesional o rango de fechas, devolviendo la información relacionalmente enriquecida con los nombres y apellidos del profesional y su fotografía.

### 5.2 Secuencia de Llamados y Objetos Invocados

| Orden | Objeto Invocado (Nombre Exacto) | Capa / Familia | Propósito / Condición de Invocación |
| :---: | :--- | :--- | :--- |
| 1 | `PKGCN_HORARIOS.pr_consultar_ausencias_json` | Casos de Negocio (`pkgcn_`) | Ejecuta la consulta SQL tradicional y genera el JSON de ausencias |
| 2 | `pkgcn_profesionales.f_url_foto_profesional` | Casos de Negocio (`pkgcn_`) | Resuelve la URL de foto de cada profesional |

---

## 6. Método: `p_eliminar_ausencia`

### 6.1 Descripción Funcional en Lenguaje Natural
Elimina un registro de ausencia previamente configurado a partir de su clave primaria (`id`). Valida la existencia previa en el DAO y procede con la eliminación atómica, asegurando la consistencia mediante `p_do_commit`.

### 6.2 Decisiones y Bifurcaciones Lógicas
1. **Validación de Identificador:** Valida `id` obligatorio (error `-20001`).
2. **Existencia Previa:** Invoca `PKGTKR_AUSENCIAS_PROFESIONAL_DAO.f_existe(id)`. Si retorna `FALSE`, lanza error `-20002`.
3. **Eliminación en DAO:** Ejecuta `PKGTKR_AUSENCIAS_PROFESIONAL_DAO.p_eliminar(id)`.
4. **Confirmación Transaccional:** Invoca `p_do_commit('PKGLN_HORARIOS.p_eliminar_ausencia')`.
5. **Excepciones:** `ROLLBACK`, logging en `tkr_errores` y `-20000`.

### 6.3 Secuencia de Llamados y Objetos Invocados

| Orden | Objeto Invocado (Nombre Exacto) | Capa / Familia | Propósito / Condición de Invocación |
| :---: | :--- | :--- | :--- |
| 1 | `PKGTKR_AUSENCIAS_PROFESIONAL_DAO.f_existe` | Persistencia (`DAO`) | Valida que la ausencia exista por PK |
| 2 | `PKGTKR_AUSENCIAS_PROFESIONAL_DAO.p_eliminar` | Persistencia (`DAO`) | Elimina el registro de la tabla |
| 3 | `p_do_commit` | Gobierno Transaccional | Confirma la transacción |
| 4 | `uti_ge_excepciones_pkg.p_grabar_log` | Utilitarios (`uti_`) | Log forense en caso de excepción |

---

## 7. Método: `p_actualizar_trabaja_festivos`

### 7.1 Descripción Funcional en Lenguaje Natural
Actualiza la configuración de trabajo en días festivos y domingos (`trabaja_festivos` con valores `'S'` o `'N'`) para un usuario específico en `tkr_usuarios`. Opcionalmente, si el usuario pasa a `trabaja_festivos = 'N'` y se recibe la instrucción explícita `borrar_domingos = 1`, procede a eliminar de manera atómica todos los horarios previamente configurados para el día Domingo (`dia_semana = 'DO'`) de la tabla `tkr_horarios_profesional`, confirmando todos los cambios bajo una única transacción gobernada por `p_do_commit`.

### 7.2 Decisiones y Bifurcaciones Lógicas
1. **Validación de Identificador:** Valida `id_usuario` no nulo (error `-20001`).
2. **Validación de Valor Booleano/Flag:** Valida que `trabaja_festivos` sea estrictamente `'S'` o `'N'` (error `-20009`).
3. **Actualización de Flag:** Invoca `pkgca_tkr_usuarios.p_actualizar_trabaja_festivos(v_id_usuario, v_trabaja_festivos)` para actualizar la columna en `tkr_usuarios`.
4. **Bifurcación Eliminación de Domingos:**
   - Si `v_trabaja_festivos = 'N'` y `v_borrar_domingos = 1`:
     Invoca `pkgca_tkr_horarios_profesional.p_borrar_x_dia_semana(v_id_usuario, 'DO')`.
5. **Confirmación Transaccional:** Invoca `p_do_commit('PKGLN_HORARIOS.p_actualizar_trabaja_festivos')`.
6. **Respuesta Estructurada:** Genera JSON de confirmación `{ "codigo": 0, "mensaje": "..." }`.
7. **Excepciones:** `ROLLBACK`, logging persistente en `tkr_errores` y relanzamiento controlado `-20000`.

### 7.3 Secuencia de Llamados y Objetos Invocados

| Orden | Objeto Invocado (Nombre Exacto) | Capa / Familia | Propósito / Condición de Invocación |
| :---: | :--- | :--- | :--- |
| 1 | `pkgca_tkr_usuarios.p_actualizar_trabaja_festivos` | Acceso No-PK Mono-Tabla (`pkgca_`) | Actualiza `trabaja_festivos` en `tkr_usuarios` |
| 2 | `pkgca_tkr_horarios_profesional.p_borrar_x_dia_semana` | Acceso No-PK Mono-Tabla (`pkgca_`) | Condicional: Borra turnos de domingo si flag = 'N' y borrar_domingos = 1 |
| 3 | `p_do_commit` | Gobierno Transaccional | Confirma la transacción |
| 4 | `uti_ge_excepciones_pkg.p_grabar_log` | Utilitarios (`uti_`) | Log forense en caso de excepción |

---

## 8. Mapa Global de Dependencias para la Aplicación de Grafos

```mermaid
graph TD
    Client["Frontend / API Gateway"] --> PKGLN["PKGLN_HORARIOS"]
    
    subgraph Orquestador Transaccional
        PKGLN
    end
    
    subgraph Casos de Negocio Multi-Tabla y JSON
        PKGCN_H["PKGCN_HORARIOS"]
        PKGCN_P["pkgcn_profesionales"]
    end
    
    subgraph Acceso No-PK Mono-Tabla
        PKGCA_HP["pkgca_tkr_horarios_profesional"]
        PKGCA_AP["pkgca_tkr_ausencias_profesional"]
        PKGCA_U["pkgca_tkr_usuarios"]
    end
    
    subgraph Persistencia Pura DAO
        DAO_HP["PKGTKR_HORARIOS_PROFESIONAL_DAO"]
        DAO_AP["PKGTKR_AUSENCIAS_PROFESIONAL_DAO"]
    end
    
    subgraph Utilitarios Transversales
        UTI_T["uti_manejo_trazas_pkg"]
        UTI_E["uti_ge_excepciones_pkg"]
        COMMIT["p_do_commit"]
    end
    
    subgraph Tablas Base de Datos
        TKR_HP[("tkr_horarios_profesional")]
        TKR_AP[("tkr_ausencias_profesional")]
        TKR_U[("tkr_usuarios")]
        TKR_RU[("tkr_roles_usuario")]
        TKR_ERR[("tkr_errores")]
        TKR_TRZ[("tkr_traza_ejecucion")]
    end

    %% Invocaciones desde PKGLN
    PKGLN -->|Telemetría| UTI_T
    PKGLN -->|Persistencia Ausencias| DAO_AP
    PKGLN -->|Limpieza Mono-Tabla Horarios| PKGCA_HP
    PKGLN -->|Actualización Festivos| PKGCA_U
    PKGLN -->|Validación Traslape & Agenda| PKGCN_H
    PKGLN -->|Inserción JSON_TABLE con Fechas| PKGCN_H
    PKGLN -->|Confirmación Atómica| COMMIT
    PKGLN -->|Logging Excepciones| UTI_E

    %% Invocaciones desde PKGCN (Multi-Tabla)
    PKGCN_H -->|Resuelve Foto| PKGCN_P
    PKGCN_H -->|DML JSON_TABLE con Fechas| TKR_HP
    PKGCN_H -->|SELECT Tradicional (+)| TKR_U
    PKGCN_H -->|SELECT Tradicional (+)| TKR_RU
    PKGCN_H -->|SELECT Tradicional (+)| TKR_AP
    PKGCN_H -->|Validación Traslape Fechas/Horas| TKR_HP

    %% Invocaciones desde PKGCA (Mono-Tabla Estricto)
    PKGCA_HP -->|DELETE / UPDATE Mono-Tabla| TKR_HP
    PKGCA_AP -->|DELETE / UPDATE Mono-Tabla| TKR_AP
    PKGCA_U -->|UPDATE / SELECT Mono-Tabla| TKR_U

    %% Invocaciones desde DAOs
    DAO_HP -->|CRUD Atómico por PK| TKR_HP
    DAO_AP -->|CRUD Atómico por PK| TKR_AP

    %% Utilitarios a Tablas
    UTI_E -->|Log Autónomo| TKR_ERR
    UTI_T -->|Registro Traza| TKR_TRZ
```

