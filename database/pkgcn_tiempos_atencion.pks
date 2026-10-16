CREATE OR REPLACE PACKAGE pkgcn_tiempos_atencion AS
    /*
    || =========================================================================
    || Paquete: pkgcn_tiempos_atencion
    || Propósito: Capa de Casos de Negocio para la gestión de Tiempos de Atención
    ||            por profesional y tipo de aseguramiento.
    || Estándar: oracle-plsql-architecture
    || =========================================================================
    */

    -- 1. Consultar tiempos de atención de un profesional en formato JSON
    PROCEDURE p_consultar_tiempos_json (
        p_id_usuario  IN  NUMBER,
        p_json_salida OUT CLOB
    );

    -- 2. Guardar o actualizar (Merge) tiempos de atención para un profesional
    PROCEDURE p_guardar_tiempos_profesional (
        p_id_usuario   IN NUMBER,
        p_json_tiempos IN CLOB
    );

    -- 3. Eliminar la configuración de tiempo de atención para un tipo de aseguramiento
    PROCEDURE p_eliminar_tiempo_profesional (
        p_id_usuario             IN NUMBER,
        p_id_tipo_aseguramiento IN NUMBER
    );

END pkgcn_tiempos_atencion;
/
