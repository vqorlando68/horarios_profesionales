# Documentación de Capa Multi-Tabla: PKGCN_HORARIOS

## 1. `f_consultar_profesionales`
- **Información que trae:** Consulta los profesionales habilitados (`id_estado_usuario = 1`, `id_rol = 4` en `tkr_roles_usuario`) filtrando opcionalmente por nombre, correo o teléfono, retornando un `SYS_REFCURSOR`.
- **Información que modifica:** Ninguna (solo lectura).

## 2. `p_consultar_profesionales_json`
- **Información que trae:** Retorna en un `CLOB` JSON la lista de profesionales habilitados con su nombre completo, correo, teléfono, indicador `trabaja_festivos` y URL de fotografía.
- **Información que modifica:** Ninguna (solo lectura).

## 3. `f_existe_traslape_horario`
- **Información que trae:** Verifica en `tkr_horarios_profesional` si un rango horario para un día de la semana, vigencia de fechas y convenio presenta traslape con horarios previamente registrados del mismo nivel jerárquico.
- **Información que modifica:** Ninguna (solo lectura).

## 4. `p_guardar_horarios_profesional`
- **Información que trae:** Desestructura el arreglo `$.horarios[*]` del JSON de entrada mediante `JSON_TABLE` y resuelve el `id_tipo_aseguramiento` cruzando `tkr_convenios` y `tkr_entidades` con sintaxis tradicional `(+)`.
- **Información que modifica:** Inserta masivamente los nuevos registros de horario en `tkr_horarios_profesional`.

## 5. `p_consultar_agenda_profesional_json`
- **Información que trae:** Consolida en un `CLOB` JSON los datos del profesional (`tkr_usuarios`, `tkr_roles_usuario`), sus horarios activos (`tkr_horarios_profesional`, `tkr_convenios`) y sus ausencias programadas (`tkr_ausencias_profesional`).
- **Información que modifica:** Ninguna (solo lectura).

## 6. `p_consultar_ausencias_json`
- **Información que trae:** Consulta las ausencias de un profesional en `tkr_ausencias_profesional` filtradas por rango de fechas, retornando un `CLOB` JSON.
- **Información que modifica:** Ninguna (solo lectura).

## 7. `p_eliminar_ausencias_festivos_vigencia`
- **Información que trae:** Verifica en `tkr_festivos` y `tkr_horarios_profesional` qué ausencias por festivos pertenecen exclusivamente a una vigencia personalizada que se está eliminando.
- **Información que modifica:** Elimina de `tkr_ausencias_profesional` los registros de festivos de dicha vigencia que no se solapen con otra vigencia activa.

## 8. `f_consultar_citas_ocupadas`
- **Información que trae:** Consulta en una única instrucción `SELECT` las citas ocupadas de un profesional en `tkr_citas` (filtrando por `ct.id_profesional = p_id_usuario` o existencia en `tkr_cita_usuarios.id_usuario_atiende = p_id_usuario`) entre `fecha_inicio_cita` y `fecha_final_cita` con `id_estado_cita IN (2, 3)`, retornando un `SYS_REFCURSOR`.
- **Información que modifica:** Ninguna (solo lectura).

## 9. `p_sincronizar_agenda_slots`
- **Información que trae:** Recibe por parámetro los vectores `p_bitmap_disponible`, `p_bitmap_ocupado` y `p_slots_disponibles` calculados por el orquestador `PKGLN_HORARIOS.p_sincronizar_agenda`.
- **Información que modifica:** Ejecuta una única instrucción DML (`MERGE INTO tkr_disponibilidad_bitmap`) para actualizar o insertar los slots y bitmaps del profesional en la fecha indicada.

