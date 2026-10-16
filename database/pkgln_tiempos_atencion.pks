CREATE OR REPLACE PACKAGE pkgln_tiempos_atencion AS
    /*
    || =========================================================================
    || Paquete: pkgln_tiempos_atencion
    || Propósito: Orquestador transaccional de dominio para la gestión de
    ||            Tiempos de Atención de profesionales.
    || Estándar: oracle-plsql-architecture
    || =========================================================================
    */

    -- 1. Consultar tiempos de atención de un profesional
    PROCEDURE p_consultar_tiempos (
        p_json_entrada IN  CLOB,
        p_json_salida  OUT CLOB
    );

    -- 2. Guardar o actualizar tiempos de atención de un profesional
    PROCEDURE p_guardar_tiempos (
        p_json_entrada IN  CLOB,
        p_json_salida  OUT CLOB
    );

    -- 3. Eliminar la configuración de tiempo de atención para un tipo de aseguramiento
    PROCEDURE p_eliminar_tiempo (
        p_json_entrada IN  CLOB,
        p_json_salida  OUT CLOB
    );

END pkgln_tiempos_atencion;
/
