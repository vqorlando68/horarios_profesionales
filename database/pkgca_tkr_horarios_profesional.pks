CREATE OR REPLACE PACKAGE pkgca_tkr_horarios_profesional AS
    /*
    || =========================================================================
    || Paquete: pkgca_tkr_horarios_profesional
    || Propósito: Capa de Acceso No-PK y DML Mono-Tabla para la entidad física
    ||            TKR_HORARIOS_PROFESIONAL.
    || Estándar: oracle-plsql-architecture
    || Reglas:
    ||   - Acceso y DML EXCLUSIVAMENTE sobre la tabla TKR_HORARIOS_PROFESIONAL.
    ||   - PROHIBIDO realizar JOINs o interactuar con múltiples tablas en esta capa.
    ||   - Retorno de cursores con SYS_REFCURSOR.
    ||   - PROHIBIDO COMMIT o ROLLBACK en este paquete.
    || =========================================================================
    */

    -- Eliminar todos los horarios asociados a un profesional
    PROCEDURE p_borrar_x_profesional (
        p_id_usuario IN tkr_horarios_profesional.id_usuario%TYPE
    );

    -- Eliminar horarios de un profesional dentro de un rango de vigencia específico
    PROCEDURE p_borrar_x_rango_fechas (
        p_id_usuario    IN tkr_horarios_profesional.id_usuario%TYPE,
        p_fecha_inicial IN tkr_horarios_profesional.fecha_inicial%TYPE,
        p_fecha_final   IN tkr_horarios_profesional.fecha_final%TYPE
    );

    -- Inactivar lógicamente todos los horarios de un profesional
    PROCEDURE p_inactivar_x_profesional (
        p_id_usuario IN tkr_horarios_profesional.id_usuario%TYPE
    );

    -- Eliminar horarios de un profesional para un día específico (ej: domingo 'DO')
    PROCEDURE p_borrar_x_dia_semana (
        p_id_usuario IN tkr_horarios_profesional.id_usuario%TYPE,
        p_dia_semana IN tkr_horarios_profesional.dia_semana%TYPE
    );

    -- Consultar horarios registrados para un profesional (solo tabla tkr_horarios_profesional)
    FUNCTION f_consultar_x_profesional (
        p_id_usuario IN tkr_horarios_profesional.id_usuario%TYPE
    ) RETURN SYS_REFCURSOR;

    -- Consultar horarios activos de un profesional vigentes para una fecha de referencia
    FUNCTION f_consultar_vigentes_fecha (
        p_id_usuario IN tkr_horarios_profesional.id_usuario%TYPE,
        p_fecha      IN DATE
    ) RETURN SYS_REFCURSOR;

    -- Verificar si existe al menos un horario base (sin fecha final) para el profesional
    FUNCTION f_existe_horario_base (
        p_id_usuario IN tkr_horarios_profesional.id_usuario%TYPE
    ) RETURN NUMBER;

END pkgca_tkr_horarios_profesional;
/
