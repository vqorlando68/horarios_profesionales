CREATE OR REPLACE PACKAGE BODY PKGCN_HORARIOS
AS
    /*
    || =========================================================================
    || Paquete: PKGCN_HORARIOS (Body)
    || Propósito: Implementación de la capa multi-tabla de casos de negocio para
    ||            horarios y ausencias de profesionales.
    || Estándar: oracle-plsql-architecture
    || =========================================================================
    */

    -- 1. Consultar profesionales habilitados mediante SYS_REFCURSOR
    FUNCTION f_consultar_profesionales (
        p_filtro_nombre IN VARCHAR2 DEFAULT NULL
    ) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT u.id,
                   TRIM(u.nombres || ' ' || u.apellidos) AS nombre_completo,
                   u.nombres,
                   u.apellidos,
                   u.correo_electronico,
                   u.telefono,
                   NVL(u.trabaja_festivos, 'N') AS trabaja_festivos,
                   pkgcn_profesionales.f_url_foto_profesional(u.id) AS url_foto
              FROM tkr_usuarios u
         WHERE u.id_estado_usuario = 1
           AND EXISTS (SELECT 1 FROM tkr_roles_usuario ru WHERE ru.id_usuario = u.id AND ru.id_rol = 4)
               AND (
                   p_filtro_nombre IS NULL
                   OR UPPER(u.nombres || ' ' || u.apellidos) LIKE '%' || UPPER(TRIM(p_filtro_nombre)) || '%'
                   OR UPPER(u.correo_electronico) LIKE '%' || UPPER(TRIM(p_filtro_nombre)) || '%'
                   OR TO_CHAR(u.telefono) LIKE '%' || TRIM(p_filtro_nombre) || '%'
               )
             ORDER BY u.nombres ASC, u.apellidos ASC;
        RETURN v_cursor;
    END f_consultar_profesionales;

    -- 2. Consultar profesionales habilitados formateado en JSON CLOB
    PROCEDURE p_consultar_profesionales_json (
        p_filtro_nombre IN  VARCHAR2,
        p_json_salida   OUT CLOB
    ) IS
    BEGIN
        SELECT JSON_OBJECT(
                   'codigo'  VALUE 0,
                   'mensaje' VALUE 'Profesionales consultados exitosamente',
                   'datos'   VALUE COALESCE(
                       JSON_ARRAYAGG(
                           JSON_OBJECT(
                               'id_usuario'       VALUE u.id,
                               'nombre_completo'  VALUE TRIM(u.nombres || ' ' || u.apellidos),
                               'nombres'          VALUE u.nombres,
                               'apellidos'        VALUE u.apellidos,
                               'correo'           VALUE u.correo_electronico,
                               'telefono'         VALUE u.telefono,
                               'trabaja_festivos' VALUE NVL(u.trabaja_festivos, 'N'),
                               'url_foto'         VALUE pkgcn_profesionales.f_url_foto_profesional(u.id)
                           )
                           ORDER BY u.nombres, u.apellidos
                          RETURNING CLOB
                   ),
                       TO_CLOB('[]')
                   ) FORMAT JSON
                   RETURNING CLOB
               )
          INTO p_json_salida
          FROM tkr_usuarios u
         WHERE u.id_estado_usuario = 1
           AND EXISTS (SELECT 1 FROM tkr_roles_usuario ru WHERE ru.id_usuario = u.id AND ru.id_rol = 4)
           AND (
               p_filtro_nombre IS NULL
               OR UPPER(u.nombres || ' ' || u.apellidos) LIKE '%' || UPPER(TRIM(p_filtro_nombre)) || '%'
               OR UPPER(u.correo_electronico) LIKE '%' || UPPER(TRIM(p_filtro_nombre)) || '%'
               OR TO_CHAR(u.telefono) LIKE '%' || TRIM(p_filtro_nombre) || '%'
           );
    END p_consultar_profesionales_json;

    -- 3. Validar si existe traslape de horario para un profesional evaluando día, horas, vigencia de fechas y convenio
    FUNCTION f_existe_traslape_horario (
        p_id_usuario         IN NUMBER,
        p_dia_semana         IN VARCHAR2,
        p_hora_desde         IN VARCHAR2,
        p_hora_hasta         IN VARCHAR2,
        p_fecha_inicial      IN DATE,
        p_fecha_final        IN DATE DEFAULT NULL,
        p_id_horario_excluir IN NUMBER DEFAULT NULL,
        p_id_convenio        IN NUMBER DEFAULT NULL
    ) RETURN BOOLEAN IS
        v_conteo    NUMBER := 0;
        v_fin_nuevo DATE;
    BEGIN
        -- Regla de Negocio y Jerarquía de Prioridad:
        -- 1) Horario por día (p_fecha_inicial = p_fecha_final): Prioridad 1
        -- 2) Horario Personalizado (p_fecha_inicial <> p_fecha_final): Prioridad 2
        -- 3) Horario Base (fecha_final IS NULL): Prioridad 3
        -- Regla de Prioridad de Convenio:
        -- - La prioridad de una franja es cuando tiene id_convenio (convenio específico prevalece sobre convenio general null).
        -- - Por tanto, una franja con id_convenio específico no colisiona con una franja general (id_convenio IS NULL).
        -- - Solo se evalúa traslape entre franjas del mismo nivel (ambas con id_convenio específico o ambas generales null).
        IF p_fecha_final IS NULL THEN
            RETURN FALSE;
        END IF;

        v_fin_nuevo := p_fecha_final;

        -- 1. Si es Horario por día (fecha inicial igual a fecha final):
        -- Solo se valida traslape contra otros Horarios por día en esa misma fecha exacta.
        IF TRUNC(p_fecha_inicial) = TRUNC(v_fin_nuevo) THEN
            SELECT COUNT(*)
              INTO v_conteo
              FROM tkr_horarios_profesional h
             WHERE h.id_usuario = p_id_usuario
               AND h.dia_semana = UPPER(TRIM(p_dia_semana))
               AND h.activo = 1
               AND (p_id_horario_excluir IS NULL OR h.id <> p_id_horario_excluir)
               AND h.fecha_final IS NOT NULL
               AND TRUNC(h.fecha_inicial) = TRUNC(h.fecha_final)
               AND TRUNC(h.fecha_inicial) = TRUNC(p_fecha_inicial)
               -- Intersección de horas
               AND p_hora_desde < h.hora_hasta
               AND p_hora_hasta > h.hora_desde
               -- Prioridad de convenio
               AND (
                   (p_id_convenio IS NULL AND h.id_convenio IS NULL)
                   OR
                   (p_id_convenio IS NOT NULL AND h.id_convenio IS NOT NULL)
               );

            RETURN (v_conteo > 0);
        END IF;

        -- 2. Si es Horario Personalizado (rango fecha inicial <> fecha final):
        -- Solo se valida traslape contra otros Horarios Personalizados de rango
        SELECT COUNT(*)
          INTO v_conteo
          FROM tkr_horarios_profesional h
         WHERE h.id_usuario = p_id_usuario
           AND h.dia_semana = UPPER(TRIM(p_dia_semana))
           AND h.activo = 1
           AND (p_id_horario_excluir IS NULL OR h.id <> p_id_horario_excluir)
           AND h.fecha_final IS NOT NULL
           AND TRUNC(h.fecha_inicial) <> TRUNC(h.fecha_final)
           -- 1. Intersección de rangos de fechas (vigencia)
           AND TRUNC(p_fecha_inicial) <= TRUNC(h.fecha_final)
           AND TRUNC(v_fin_nuevo)     >= TRUNC(h.fecha_inicial)
           -- 2. Intersección de rangos de horas dentro del mismo día
           AND p_hora_desde < h.hora_hasta
           AND p_hora_hasta > h.hora_desde
           -- Prioridad de convenio
           AND (
               (p_id_convenio IS NULL AND h.id_convenio IS NULL)
               OR
               (p_id_convenio IS NOT NULL AND h.id_convenio IS NOT NULL)
           );

        RETURN (v_conteo > 0);
    END f_existe_traslape_horario;

    -- 4. Desestructuración de JSON e inserción masiva de horarios con rango de fechas
    PROCEDURE p_guardar_horarios_profesional (
        p_id_usuario    IN NUMBER,
        p_json_horarios IN CLOB
    ) IS
    BEGIN
        INSERT INTO tkr_horarios_profesional (
            id,
            id_usuario,
            dia_semana,
            hora_desde,
            hora_hasta,
            fecha_inicial,
            fecha_final,
            id_tipo_aseguramiento,
            id_convenio,
            activo,
            fecha_creacion
        )
        SELECT tkr_horarios_profesional_seq.NEXTVAL,
               p_id_usuario,
               UPPER(TRIM(jt.dia_semana)),
               TRIM(jt.hora_desde),
               TRIM(jt.hora_hasta),
               TO_DATE(TRIM(jt.fecha_inicial), 'YYYY-MM-DD'),
               CASE 
                   WHEN TRIM(jt.fecha_final) IS NOT NULL 
                   THEN TO_DATE(TRIM(jt.fecha_final), 'YYYY-MM-DD')
                   ELSE NULL
               END,
               COALESCE(
                   (SELECT CASE WHEN UPPER(TRIM(e.tipo_aseguramiento)) = 'O' THEN 2 
                                WHEN UPPER(TRIM(e.tipo_aseguramiento)) = 'V' THEN 1 
                                ELSE NULL END
                      FROM tkr_convenios c, tkr_entidades e
                     WHERE c.id = jt.id_convenio
                       AND e.id(+) = c.id_entidad_hijo
                       AND ROWNUM = 1),
                   jt.id_tipo_aseguramiento,
                   CASE WHEN UPPER(TRIM(jt.tipo_atencion)) = 'O' THEN 2 ELSE 1 END
               ),
               jt.id_convenio,
               1,
               SYSDATE
          FROM JSON_TABLE(p_json_horarios, '$.horarios[*]'
                   COLUMNS (
                       dia_semana            VARCHAR2(10) PATH '$.dia_semana',
                       hora_desde            VARCHAR2(10) PATH '$.hora_desde',
                       hora_hasta            VARCHAR2(10) PATH '$.hora_hasta',
                       fecha_inicial         VARCHAR2(20) PATH '$.fecha_inicial',
                       fecha_final           VARCHAR2(20) PATH '$.fecha_final',
                       id_tipo_aseguramiento NUMBER       PATH '$.id_tipo_aseguramiento',
                       id_convenio           NUMBER       PATH '$.id_convenio',
                       tipo_atencion         VARCHAR2(10) PATH '$.tipo_atencion'
                   )
               ) jt;
    END p_guardar_horarios_profesional;

    -- 5. Consultar agenda integral de un profesional (horarios vigentes y ausencias) en JSON CLOB
    PROCEDURE p_consultar_agenda_profesional_json (
        p_id_usuario  IN  NUMBER,
        p_json_salida OUT CLOB
    ) IS
        v_json_profesional CLOB;
        v_json_horarios    CLOB;
        v_json_ausencias   CLOB;
        v_resp_obj         JSON_OBJECT_T;
    BEGIN
        -- A. Datos de cabecera del profesional (multi-tabla)
        SELECT JSON_OBJECT(
                   'id_usuario'      VALUE u.id,
                   'nombre_completo' VALUE TRIM(u.nombres || ' ' || u.apellidos),
                   'nombres'         VALUE u.nombres,
                   'apellidos'       VALUE u.apellidos,
                   'correo'          VALUE u.correo_electronico,
                   'url_foto'        VALUE pkgcn_profesionales.f_url_foto_profesional(u.id)
                   RETURNING CLOB
               )
          INTO v_json_profesional
          FROM tkr_usuarios      u,
               tkr_roles_usuario ru
          WHERE ru.id_usuario = u.id
            AND ru.id_rol = 4
            AND u.id = p_id_usuario
            AND ROWNUM = 1;

        -- B. Horarios registrados del profesional con su rango de vigencia y convenio
        SELECT COALESCE(
                   JSON_ARRAYAGG(
                       JSON_OBJECT(
                           'id'            VALUE h.id,
                           'dia_semana'    VALUE h.dia_semana,
                           'hora_desde'    VALUE h.hora_desde,
                           'hora_hasta'    VALUE h.hora_hasta,
                           'fecha_inicial' VALUE TO_CHAR(h.fecha_inicial, 'YYYY-MM-DD'),
                           'fecha_final'   VALUE TO_CHAR(h.fecha_final, 'YYYY-MM-DD'),
                           'id_tipo_aseguramiento' VALUE NVL(h.id_tipo_aseguramiento, 1),
                           'tipo_atencion'         VALUE (CASE WHEN NVL(h.id_tipo_aseguramiento, 1) = 2 THEN 'O' ELSE 'V' END),
                           'tipo_aseguramiento'    VALUE (CASE WHEN NVL(h.id_tipo_aseguramiento, 1) = 2 THEN 'Obligatorio' ELSE 'Voluntario' END),
                           'id_convenio'           VALUE h.id_convenio,
                           'nombre_convenio'       VALUE c.nombre_convenio,
                           'activo'        VALUE h.activo
                       )
                       ORDER BY CASE h.dia_semana
                                    WHEN 'LU' THEN 1
                                    WHEN 'MA' THEN 2
                                    WHEN 'MI' THEN 3
                                    WHEN 'JU' THEN 4
                                    WHEN 'VI' THEN 5
                                    WHEN 'SA' THEN 6
                                    WHEN 'DO' THEN 7
                                    ELSE 8
                                END,
                                h.hora_desde
                       RETURNING CLOB
                   ),
                   TO_CLOB('[]')
               )
          INTO v_json_horarios
          FROM tkr_horarios_profesional h,
               tkr_convenios            c
         WHERE c.id(+)      = h.id_convenio
           AND h.id_usuario = p_id_usuario
           AND h.activo     = 1;

        -- C. Ausencias programadas del profesional
        SELECT COALESCE(
                   JSON_ARRAYAGG(
                       JSON_OBJECT(
                           'id'            VALUE a.id,
                           'id_usuario'    VALUE a.id_usuario,
                           'fecha_inicial' VALUE TO_CHAR(a.fecha_inicial, 'YYYY-MM-DD'),
                           'fecha_final'   VALUE TO_CHAR(a.fecha_final, 'YYYY-MM-DD')
                       )
                       ORDER BY a.fecha_inicial ASC
                       RETURNING CLOB
                   ),
                   TO_CLOB('[]')
               )
          INTO v_json_ausencias
          FROM tkr_ausencias_profesional a
         WHERE a.id_usuario = p_id_usuario;

        -- D. Consolidación de respuesta JSON usando JSON_OBJECT_T
        v_resp_obj := JSON_OBJECT_T();
        v_resp_obj.put('codigo', 0);
        v_resp_obj.put('mensaje', 'Agenda de profesional recuperada con éxito');
        v_resp_obj.put('profesional', JSON_ELEMENT_T.parse(v_json_profesional));
        v_resp_obj.put('horarios', JSON_ARRAY_T.parse(v_json_horarios));
        v_resp_obj.put('ausencias', JSON_ARRAY_T.parse(v_json_ausencias));
        p_json_salida := v_resp_obj.to_clob();

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            v_resp_obj := JSON_OBJECT_T();
            v_resp_obj.put('codigo', -20002);
            v_resp_obj.put('mensaje', 'Profesional no encontrado o no activo con rol médico');
            p_json_salida := v_resp_obj.to_clob();
    END p_consultar_agenda_profesional_json;

    -- 6. Consultar ausencias en JSON (soporte y retrocompatibilidad)
    PROCEDURE p_consultar_ausencias_json (
        p_json      IN  CLOB,
        p_resultado OUT CLOB
    ) IS
        v_id_usuario    NUMBER;
        v_fecha_inicio  DATE;
        v_fecha_fin     DATE;
        v_arr           JSON_ARRAY_T := JSON_ARRAY_T();
        v_obj           JSON_OBJECT_T;
        v_res_obj       JSON_OBJECT_T := JSON_OBJECT_T();
        CURSOR c_ausencias IS
            SELECT a.id,
                   a.id_usuario,
                   a.fecha_inicial,
                   a.fecha_final
              FROM tkr_ausencias_profesional a
             WHERE a.id_usuario = v_id_usuario
               AND (v_fecha_inicio IS NULL OR a.fecha_final >= v_fecha_inicio)
               AND (v_fecha_fin IS NULL OR a.fecha_inicial <= v_fecha_fin)
             ORDER BY a.fecha_inicial ASC;
    BEGIN
        SELECT jt.id_usuario,
               TO_DATE(NVL(jt.fecha_inicio, jt.fecha_inicial), 'YYYY-MM-DD'),
               TO_DATE(NVL(jt.fecha_fin, jt.fecha_final), 'YYYY-MM-DD')
          INTO v_id_usuario,
               v_fecha_inicio,
               v_fecha_fin
          FROM JSON_TABLE(p_json, '$'
                   COLUMNS (
                       id_usuario    NUMBER       PATH '$.id_usuario',
                       fecha_inicio  VARCHAR2(20) PATH '$.fecha_inicio',
                       fecha_fin     VARCHAR2(20) PATH '$.fecha_fin',
                       fecha_inicial VARCHAR2(20) PATH '$.fecha_inicial',
                       fecha_final   VARCHAR2(20) PATH '$.fecha_final'
                   )
               ) jt;

        FOR r IN c_ausencias LOOP
            v_obj := JSON_OBJECT_T();
            v_obj.put('id', r.id);
            v_obj.put('id_usuario', r.id_usuario);
            v_obj.put('fecha_inicial', TO_CHAR(r.fecha_inicial, 'YYYY-MM-DD'));
            v_obj.put('fecha_final', TO_CHAR(r.fecha_final, 'YYYY-MM-DD'));
            v_arr.append(v_obj);
        END LOOP;

        v_res_obj.put('codigo', 0);
        v_res_obj.put('mensaje', 'Ausencias consultadas exitosamente');
        v_res_obj.put('datos', v_arr);
        p_resultado := v_res_obj.to_clob();
    END p_consultar_ausencias_json;

    -- 7. Eliminar ausencias de festivos de una vigencia personalizada si no solapa con otra vigencia personalizada
    PROCEDURE p_eliminar_ausencias_festivos_vigencia (
        p_id_usuario    IN NUMBER,
        p_fecha_inicial IN DATE,
        p_fecha_final   IN DATE
    ) IS
    BEGIN
        IF p_id_usuario IS NULL OR p_fecha_inicial IS NULL OR p_fecha_final IS NULL THEN
            RETURN;
        END IF;

        DELETE FROM tkr_ausencias_profesional a
         WHERE a.id_usuario = p_id_usuario
           -- Que caiga dentro del rango personalizado que se elimina
           AND TRUNC(a.fecha_inicial) >= TRUNC(p_fecha_inicial)
           AND TRUNC(a.fecha_final)   <= TRUNC(p_fecha_final)
           -- Que sea un día festivo nacional
           AND EXISTS (
               SELECT 1
                 FROM tkr_festivos f
                WHERE f.id_pais = 1
                  AND TRUNC(f.fecha_festivo) BETWEEN TRUNC(a.fecha_inicial) AND TRUNC(a.fecha_final)
           )
           -- Siempre y cuando el día no esté en otro rango personalizado activo que quede para ese profesional
           AND NOT EXISTS (
               SELECT 1
                 FROM tkr_horarios_profesional h
                WHERE h.id_usuario = p_id_usuario
                  AND h.activo = 1
                  AND h.fecha_final IS NOT NULL
                  -- Excluir el rango personalizado que se está borrando
                  AND NOT (
                      TRUNC(h.fecha_inicial) = TRUNC(p_fecha_inicial)
                      AND TRUNC(h.fecha_final) = TRUNC(p_fecha_final)
                  )
                  -- El día está cubierto por este otro rango personalizado
                  AND TRUNC(a.fecha_inicial) <= TRUNC(h.fecha_final)
                  AND TRUNC(a.fecha_final)   >= TRUNC(h.fecha_inicial)
           );
    END p_eliminar_ausencias_festivos_vigencia;

    -- 8. Consultar citas ocupadas de un profesional en un rango de fechas (id_estado_cita IN (2,3))
    FUNCTION f_consultar_citas_ocupadas (
        p_id_usuario    IN NUMBER,
        p_fecha_inicial IN DATE,
        p_fecha_final   IN DATE
    ) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT ct.id,
                   ct.fecha_inicio_cita,
                   ct.fecha_final_cita
              FROM tkr_citas         ct,
                   tkr_cita_usuarios cu
             WHERE ct.id                 = cu.id_cita
               AND cu.id_usuario_atiende = p_id_usuario
               AND ct.id_estado_cita    IN (2, 3)
               AND ct.fecha_inicio_cita <= (TRUNC(p_fecha_final) + 1 - (1 / 86400))
               AND NVL(ct.fecha_final_cita, ct.fecha_inicio_cita) >= TRUNC(p_fecha_inicial);
        RETURN v_cursor;
    END f_consultar_citas_ocupadas;

    -- 9. Persistir en una única instrucción DML el bitmap y slots sincronizados del día
    PROCEDURE p_sincronizar_agenda_slots (
        p_id_usuario            IN NUMBER,
        p_fecha                 IN DATE,
        p_id_convenio           IN NUMBER,
        p_id_tipo_aseguramiento IN NUMBER,
        p_modalidad             IN VARCHAR2,
        p_bitmap_disponible     IN VARCHAR2,
        p_bitmap_ocupado        IN VARCHAR2,
        p_slots_disponibles     IN NUMBER
    ) IS
    BEGIN
        MERGE INTO tkr_disponibilidad_bitmap dest
        USING (
            SELECT p_id_usuario                    AS id_usuario,
                   TRUNC(p_fecha)                  AS fecha,
                   p_id_convenio                   AS id_convenio,
                   NVL(p_id_tipo_aseguramiento, 1) AS id_tipo_aseguramiento,
                   NVL(p_modalidad, 'V')           AS modalidad,
                   p_bitmap_disponible             AS bitmap_disponible,
                   p_bitmap_ocupado                AS bitmap_ocupado,
                   NVL(p_slots_disponibles, 0)     AS slots_disponibles
              FROM DUAL
        ) src
           ON (    dest.id_usuario            = src.id_usuario
               AND TRUNC(dest.fecha)          = src.fecha
               AND NVL(dest.id_convenio, -1)  = NVL(src.id_convenio, -1)
               AND dest.id_tipo_aseguramiento = src.id_tipo_aseguramiento
               AND dest.modalidad             = src.modalidad )
         WHEN MATCHED THEN
            UPDATE SET
                dest.bitmap_disponible   = src.bitmap_disponible,
                dest.bitmap_ocupado      = src.bitmap_ocupado,
                dest.slots_disponibles   = src.slots_disponibles,
                dest.fecha_actualizacion = SYSTIMESTAMP AT TIME ZONE 'America/Bogota'
         WHEN NOT MATCHED THEN
            INSERT (
                id_usuario,
                fecha,
                id_convenio,
                id_tipo_aseguramiento,
                modalidad,
                bitmap_disponible,
                bitmap_ocupado,
                slots_disponibles,
                fecha_actualizacion
            ) VALUES (
                src.id_usuario,
                src.fecha,
                src.id_convenio,
                src.id_tipo_aseguramiento,
                src.modalidad,
                src.bitmap_disponible,
                src.bitmap_ocupado,
                src.slots_disponibles,
                SYSTIMESTAMP AT TIME ZONE 'America/Bogota'
            );
    END p_sincronizar_agenda_slots;

END PKGCN_HORARIOS;
/
