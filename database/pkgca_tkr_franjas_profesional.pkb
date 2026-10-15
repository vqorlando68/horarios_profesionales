CREATE OR REPLACE PACKAGE BODY pkgca_tkr_franjas_profesional AS
    /*
    || =========================================================================
    || Paquete: pkgca_tkr_franjas_profesional (BODY)
    || Propósito: Implementación de operaciones DML y consultas mono-tabla sobre
    ||            TKR_FRANJAS_PROFESIONAL.
    || Estándar: oracle-plsql-architecture
    || =========================================================================
    */

    PROCEDURE p_borrar_x_profesional (
        p_id_usuario IN tkr_franjas_profesional.id_usuario%TYPE
    ) IS
    BEGIN
        DELETE FROM tkr_franjas_profesional
         WHERE id_usuario = p_id_usuario;
    END p_borrar_x_profesional;

    PROCEDURE p_borrar_x_rango_fechas (
        p_id_usuario    IN tkr_franjas_profesional.id_usuario%TYPE,
        p_fecha_inicial IN tkr_franjas_profesional.fecha_inicial%TYPE,
        p_fecha_final   IN tkr_franjas_profesional.fecha_final%TYPE
    ) IS
    BEGIN
        DELETE FROM tkr_franjas_profesional
         WHERE id_usuario = p_id_usuario
           AND fecha_inicial = p_fecha_inicial
           AND ( (fecha_final IS NULL AND p_fecha_final IS NULL)
                 OR (fecha_final = p_fecha_final) );
    END p_borrar_x_rango_fechas;

    PROCEDURE p_borrar_x_dia_semana (
        p_id_usuario IN tkr_franjas_profesional.id_usuario%TYPE,
        p_dia_semana IN tkr_franjas_profesional.dia_semana%TYPE
    ) IS
    BEGIN
        DELETE FROM tkr_franjas_profesional
         WHERE id_usuario = p_id_usuario
           AND dia_semana = UPPER(TRIM(p_dia_semana));
    END p_borrar_x_dia_semana;

    FUNCTION f_consultar_x_profesional (
        p_id_usuario IN tkr_franjas_profesional.id_usuario%TYPE
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
                   tipo_atencion,
                   activo,
                   fecha_creacion
              FROM tkr_franjas_profesional
             WHERE id_usuario = p_id_usuario
             ORDER BY fecha_inicial DESC, dia_semana ASC, hora_desde ASC;
        RETURN v_cursor;
    END f_consultar_x_profesional;

    FUNCTION f_existe_franja_base (
        p_id_usuario IN tkr_franjas_profesional.id_usuario%TYPE
    ) RETURN NUMBER IS
        v_count NUMBER := 0;
    BEGIN
        SELECT COUNT(*)
          INTO v_count
          FROM tkr_franjas_profesional
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
    END f_existe_franja_base;

END pkgca_tkr_franjas_profesional;
/
