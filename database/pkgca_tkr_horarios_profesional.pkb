CREATE OR REPLACE PACKAGE BODY pkgca_tkr_horarios_profesional AS
    /*
    || =========================================================================
    || Paquete: pkgca_tkr_horarios_profesional (BODY)
    || Propósito: Implementación de operaciones DML y consultas mono-tabla sobre
    ||            TKR_HORARIOS_PROFESIONAL.
    || Estándar: oracle-plsql-architecture
    || =========================================================================
    */

    -- Eliminar todos los horarios asociados a un profesional
    PROCEDURE p_borrar_x_profesional (
        p_id_usuario IN tkr_horarios_profesional.id_usuario%TYPE
    ) IS
    BEGIN
        DELETE FROM tkr_horarios_profesional
         WHERE id_usuario = p_id_usuario;
    END p_borrar_x_profesional;

    -- Eliminar horarios de un profesional dentro de un rango de vigencia específico
    PROCEDURE p_borrar_x_rango_fechas (
        p_id_usuario    IN tkr_horarios_profesional.id_usuario%TYPE,
        p_fecha_inicial IN tkr_horarios_profesional.fecha_inicial%TYPE,
        p_fecha_final   IN tkr_horarios_profesional.fecha_final%TYPE
    ) IS
    BEGIN
        DELETE FROM tkr_horarios_profesional
         WHERE id_usuario = p_id_usuario
           AND fecha_inicial = p_fecha_inicial
           AND ( (fecha_final IS NULL AND p_fecha_final IS NULL)
                 OR (fecha_final = p_fecha_final) );
    END p_borrar_x_rango_fechas;

    -- Inactivar lógicamente todos los horarios de un profesional
    PROCEDURE p_inactivar_x_profesional (
        p_id_usuario IN tkr_horarios_profesional.id_usuario%TYPE
    ) IS
    BEGIN
        UPDATE tkr_horarios_profesional
           SET activo                  = 0,
               fecha_modificacion      = SYSDATE
         WHERE id_usuario = p_id_usuario
           AND activo     = 1;
    END p_inactivar_x_profesional;

    -- Eliminar horarios de un profesional para un día específico (ej: domingo 'DO')
    PROCEDURE p_borrar_x_dia_semana (
        p_id_usuario IN tkr_horarios_profesional.id_usuario%TYPE,
        p_dia_semana IN tkr_horarios_profesional.dia_semana%TYPE
    ) IS
    BEGIN
        DELETE FROM tkr_horarios_profesional
         WHERE id_usuario = p_id_usuario
           AND dia_semana = UPPER(TRIM(p_dia_semana));
    END p_borrar_x_dia_semana;

    -- Consultar horarios registrados para un profesional (solo tabla tkr_horarios_profesional)
    FUNCTION f_consultar_x_profesional (
        p_id_usuario IN tkr_horarios_profesional.id_usuario%TYPE
    ) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT id,
                   id_usuario,
                   dia_semana,
                   hora_desde,
                   hora_hasta,
                   fecha_inicial,
                   fecha_final,
                   id_tipo_aseguramiento,
                   activo,
                   fecha_creacion
              FROM tkr_horarios_profesional
             WHERE id_usuario = p_id_usuario
             ORDER BY fecha_inicial DESC, dia_semana ASC, hora_desde ASC;
        RETURN v_cursor;
    END f_consultar_x_profesional;

    -- Consultar horarios activos de un profesional vigentes para una fecha de referencia
    FUNCTION f_consultar_vigentes_fecha (
        p_id_usuario IN tkr_horarios_profesional.id_usuario%TYPE,
        p_fecha      IN DATE
    ) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
        v_fecha  DATE := TRUNC(NVL(p_fecha, SYSDATE));
    BEGIN
        OPEN v_cursor FOR
            SELECT id,
                   id_usuario,
                   dia_semana,
                   hora_desde,
                   hora_hasta,
                   fecha_inicial,
                   fecha_final,
                   id_tipo_aseguramiento,
                   activo
              FROM tkr_horarios_profesional
             WHERE id_usuario = p_id_usuario
               AND activo = 1
               AND fecha_inicial <= v_fecha
               AND (fecha_final IS NULL OR fecha_final >= v_fecha)
             ORDER BY dia_semana ASC, hora_desde ASC;
        RETURN v_cursor;
    END f_consultar_vigentes_fecha;

    -- Verificar si existe al menos un horario base (sin fecha final) para el profesional
    FUNCTION f_existe_horario_base (
        p_id_usuario IN tkr_horarios_profesional.id_usuario%TYPE
    ) RETURN NUMBER IS
        v_count NUMBER := 0;
    BEGIN
        SELECT COUNT(*)
          INTO v_count
          FROM tkr_horarios_profesional
         WHERE id_usuario = p_id_usuario
           AND fecha_final IS NULL
           AND ROWNUM = 1;

        IF v_count > 0 THEN
            RETURN 1;
        ELSE
            RETURN 0;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 0;
    END f_existe_horario_base;

END pkgca_tkr_horarios_profesional;
/
