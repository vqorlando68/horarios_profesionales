CREATE OR REPLACE PACKAGE PKGTKR_REFRESCAR_AGENDA_DAO
AS
    /*
    || =========================================================================
    || Paquete: PKGTKR_REFRESCAR_AGENDA_DAO
    || Propósito: Acceso a datos y persistencia atómica para la tabla 
    ||            TKR_REFRESCAR_AGENDA.
    || Estándar: oracle-plsql-architecture (Plantilla Oficial de 20 Métodos)
    || Reglas:
    ||   - Acceso exclusivo a la tabla TKR_REFRESCAR_AGENDA por PK o ROWID.
    ||   - CERO lógica de negocio.
    ||   - PROHIBIDO COMMIT o ROLLBACK en este paquete.
    || =========================================================================
    */

    -- Tipo colección para consultas generales
    TYPE t_tkr_refrescar_agenda IS TABLE OF tkr_refrescar_agenda%ROWTYPE
        INDEX BY BINARY_INTEGER;

    -- 1. Insertar registro completo
    PROCEDURE p_insertar (
        pro_tkr_refrescar_agenda IN tkr_refrescar_agenda%ROWTYPE
    );

    -- 2. Traer registro por PK
    FUNCTION f_traer (
        pty_id IN tkr_refrescar_agenda.id%TYPE
    ) RETURN tkr_refrescar_agenda%ROWTYPE;

    -- 3. Consultar todos los registros
    PROCEDURE p_consultar_registros (
        pta_tkr_refrescar_agenda OUT PKGTKR_REFRESCAR_AGENDA_DAO.t_tkr_refrescar_agenda
    );

    -- 4. Eliminar registro por ROWID
    PROCEDURE p_eliminar_rowid (
        p_rowid IN VARCHAR2
    );

    -- 5. Eliminar registro por PK
    PROCEDURE p_eliminar (
        pty_id IN tkr_refrescar_agenda.id%TYPE
    );

    -- 6. Eliminar todos los registros (Uso restringido)
    PROCEDURE p_eliminar_registros;

    -- 7. Verificar existencia por PK
    FUNCTION f_existe (
        pty_id IN tkr_refrescar_agenda.id%TYPE
    ) RETURN BOOLEAN;

    -- 8. Verificar existencia y retornar registro
    FUNCTION f_existe (
        pty_id                   IN  tkr_refrescar_agenda.id%TYPE,
        pro_tkr_refrescar_agenda OUT tkr_refrescar_agenda%ROWTYPE
    ) RETURN BOOLEAN;

    -- 9. Verificar existencia, retornar registro y ROWID
    FUNCTION f_existe (
        pty_id                   IN  tkr_refrescar_agenda.id%TYPE,
        pro_tkr_refrescar_agenda OUT tkr_refrescar_agenda%ROWTYPE,
        p_rowid                  OUT VARCHAR2
    ) RETURN BOOLEAN;

    -- 10. Verificar existencia por ROWID
    FUNCTION f_existe_rowid (
        p_rowid IN VARCHAR2
    ) RETURN BOOLEAN;

    -- 11. Verificar existencia por ROWID y retornar registro
    FUNCTION f_existe_rowid (
        p_rowid                  IN  VARCHAR2,
        pro_tkr_refrescar_agenda OUT tkr_refrescar_agenda%ROWTYPE
    ) RETURN BOOLEAN;

    -- 12. Actualizar registro completo por PK en ROWTYPE
    PROCEDURE p_actualizar (
        pro_tkr_refrescar_agenda IN tkr_refrescar_agenda%ROWTYPE
    );

    -- 13. Actualizar indicando PK explícita
    PROCEDURE p_actualizar (
        pro_tkr_refrescar_agenda IN tkr_refrescar_agenda%ROWTYPE,
        pty_id                   IN tkr_refrescar_agenda.id%TYPE
    );

    -- 14. Actualizar por ROWID
    PROCEDURE p_actualizar_rowid (
        pro_tkr_refrescar_agenda IN tkr_refrescar_agenda%ROWTYPE,
        p_rowid                  IN VARCHAR2
    );

    -- 15. Actualizar todos los registros (Uso restringido)
    PROCEDURE p_actualizar_registros (
        pro_tkr_refrescar_agenda IN tkr_refrescar_agenda%ROWTYPE
    );

    -- 16. Obtener valores por defecto
    PROCEDURE p_valores_defecto (
        pro_tkr_refrescar_agenda IN OUT tkr_refrescar_agenda%ROWTYPE
    );

    -- 17. Verificar existencia y retornar JSON CLOB
    FUNCTION f_existe_json (
        p_id                        IN  tkr_refrescar_agenda.id%TYPE,
        p_json_tkr_refrescar_agenda OUT CLOB
    ) RETURN NUMBER;

    -- 18. Obtener JSON por PK
    FUNCTION f_json (
        p_id IN tkr_refrescar_agenda.id%TYPE
    ) RETURN VARCHAR2;

    -- 19. Calcular total de páginas para paginación recibiendo JSON con campo "registros"
    FUNCTION f_total_paginas (
        p_json_entrada IN CLOB
    ) RETURN NUMBER;

    -- 20. Consultar registros paginados retornando JSON con información correspondiente
    FUNCTION f_consultar_paginado (
        p_pagina    IN NUMBER,
        p_registros IN NUMBER
    ) RETURN CLOB;

END PKGTKR_REFRESCAR_AGENDA_DAO;
/

