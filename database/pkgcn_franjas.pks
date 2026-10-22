CREATE OR REPLACE PACKAGE pkgcn_franjas AS
    /*
    || =========================================================================
    || Paquete: pkgcn_franjas
    || Propósito: Capa de Casos de Negocio para la gestión de Franjas de Atención
    ||            (Voluntario, Obligatorio, Giris) por rango de fechas.
    || Estándar: oracle-plsql-architecture
    || =========================================================================
    */

    -- 1. Validar traslape entre franjas de atención de un mismo profesional
    -- Regla: Franjas sin fecha_final (Franja Base) no validan contra franjas con fecha final.
    -- Las franjas con fecha_final solo validan contra otras franjas con fecha_final.
    FUNCTION f_existe_traslape_franja (
        p_id_usuario         IN NUMBER,
        p_dia_semana         IN VARCHAR2,
        p_hora_desde         IN VARCHAR2,
        p_hora_hasta         IN VARCHAR2,
        p_fecha_inicial      IN DATE,
        p_fecha_final        IN DATE DEFAULT NULL,
        p_id_franja_excluir  IN NUMBER DEFAULT NULL,
        p_id_convenio        IN NUMBER DEFAULT NULL
    ) RETURN BOOLEAN;

    -- 2. Desestructuración e inserción masiva de franjas
    PROCEDURE p_guardar_franjas_profesional (
        p_id_usuario   IN NUMBER,
        p_json_franjas IN CLOB
    );

    -- 3. Consultar franjas de un profesional formateado en JSON CLOB
    PROCEDURE p_consultar_franjas_json (
        p_id_usuario  IN  NUMBER,
        p_json_salida OUT CLOB
    );

END pkgcn_franjas;
/
