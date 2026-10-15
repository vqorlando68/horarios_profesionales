CREATE OR REPLACE PACKAGE pkgca_tkr_franjas_profesional AS
    /*
    || =========================================================================
    || Paquete: pkgca_tkr_franjas_profesional
    || Propósito: Capa de Acceso No-PK y DML Mono-Tabla para la entidad física
    ||            TKR_FRANJAS_PROFESIONAL.
    || Estándar: oracle-plsql-architecture
    || =========================================================================
    */

    -- Eliminar todas las franjas asociadas a un profesional
    PROCEDURE p_borrar_x_profesional (
        p_id_usuario IN tkr_franjas_profesional.id_usuario%TYPE
    );

    -- Eliminar franjas de un profesional dentro de un rango de vigencia específico
    PROCEDURE p_borrar_x_rango_fechas (
        p_id_usuario    IN tkr_franjas_profesional.id_usuario%TYPE,
        p_fecha_inicial IN tkr_franjas_profesional.fecha_inicial%TYPE,
        p_fecha_final   IN tkr_franjas_profesional.fecha_final%TYPE
    );

    -- Eliminar franjas de un profesional para un día específico (ej: domingo 'DO')
    PROCEDURE p_borrar_x_dia_semana (
        p_id_usuario IN tkr_franjas_profesional.id_usuario%TYPE,
        p_dia_semana IN tkr_franjas_profesional.dia_semana%TYPE
    );

    -- Consultar franjas registradas para un profesional
    FUNCTION f_consultar_x_profesional (
        p_id_usuario IN tkr_franjas_profesional.id_usuario%TYPE
    ) RETURN SYS_REFCURSOR;

    -- Verificar si existe al menos una franja base (sin fecha final) para el profesional
    FUNCTION f_existe_franja_base (
        p_id_usuario IN tkr_franjas_profesional.id_usuario%TYPE
    ) RETURN NUMBER;

END pkgca_tkr_franjas_profesional;
/
