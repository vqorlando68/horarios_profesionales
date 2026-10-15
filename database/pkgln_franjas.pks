CREATE OR REPLACE PACKAGE pkgln_franjas AS
    /*
    || =========================================================================
    || Paquete: pkgln_franjas
    || Propósito: Orquestador transaccional de dominio para la gestión de
    ||            Franjas de Atención por profesional.
    || Estándar: oracle-plsql-architecture
    || =========================================================================
    */

    -- 1. Consultar franjas de un profesional
    PROCEDURE p_consultar_franjas (
        p_json_entrada IN  CLOB,
        p_json_salida  OUT CLOB
    );

    -- 2. Guardar franjas (reemplazo completo o por vigencia)
    PROCEDURE p_guardar_franjas (
        p_json_entrada IN  CLOB,
        p_json_salida  OUT CLOB
    );

    -- 3. Eliminar franjas de una vigencia específica
    PROCEDURE p_eliminar_franjas_vigencia (
        p_json_entrada IN  CLOB,
        p_json_salida  OUT CLOB
    );

END pkgln_franjas;
/
