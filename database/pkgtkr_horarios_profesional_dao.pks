CREATE OR REPLACE PACKAGE PKGTKR_HORARIOS_PROFESIONAL_DAO
AS
    /*
    || =========================================================================
    || Paquete: PKGTKR_HORARIOS_PROFESIONAL_DAO
    || Propósito: Acceso a datos y persistencia atómica para la tabla 
    ||            TKR_HORARIOS_PROFESIONAL.
    || Estándar: oracle-plsql-architecture (Plantilla Oficial de 20 Métodos)
    || Reglas:
    ||   - Acceso exclusivo a la tabla TKR_HORARIOS_PROFESIONAL por PK o ROWID.
    ||   - CERO lógica de negocio.
    ||   - PROHIBIDO COMMIT o ROLLBACK en este paquete.
    || =========================================================================
    */

    -- Tipo colección para manejo en memoria de registros
    TYPE t_tkr_horarios_profesional IS TABLE OF tkr_horarios_profesional%ROWTYPE
        INDEX BY BINARY_INTEGER;

    -- 1. Insertar registro unitario
    PROCEDURE p_insertar (
        pro_tkr_horarios_profesional IN tkr_horarios_profesional%ROWTYPE
    );

    -- 2. Insertar colección masiva mediante FORALL
    PROCEDURE p_insertar_con_tabla (
        pta_tkr_horarios_profesional IN PKGTKR_HORARIOS_PROFESIONAL_DAO.t_tkr_horarios_profesional
    );

    -- 3. Traer registro por PK
    FUNCTION f_traer (
        pty_id IN tkr_horarios_profesional.id%TYPE
    ) RETURN tkr_horarios_profesional%ROWTYPE;

    -- 4. Consultar todos los registros
    PROCEDURE p_consultar_registros (
        pta_tkr_horarios_profesional OUT PKGTKR_HORARIOS_PROFESIONAL_DAO.t_tkr_horarios_profesional
    );

    -- 5. Eliminar registro por ROWID
    PROCEDURE p_eliminar_rowid (
        p_rowid IN VARCHAR2
    );

    -- 6. Eliminar registro por PK
    PROCEDURE p_eliminar (
        pty_id IN tkr_horarios_profesional.id%TYPE
    );

    -- 7. Eliminar todos los registros
    PROCEDURE p_eliminar_registros;

    -- 8. Verificar existencia por PK
    FUNCTION f_existe (
        pty_id IN tkr_horarios_profesional.id%TYPE
    ) RETURN BOOLEAN;

    -- 9. Verificar existencia y retornar registro
    FUNCTION f_existe (
        pty_id                       IN  tkr_horarios_profesional.id%TYPE,
        pro_tkr_horarios_profesional OUT tkr_horarios_profesional%ROWTYPE
    ) RETURN BOOLEAN;

    -- 10. Verificar existencia, retornar registro y ROWID
    FUNCTION f_existe (
        pty_id                       IN  tkr_horarios_profesional.id%TYPE,
        pro_tkr_horarios_profesional OUT tkr_horarios_profesional%ROWTYPE,
        p_rowid                      OUT VARCHAR2
    ) RETURN BOOLEAN;

    -- 11. Verificar existencia por ROWID
    FUNCTION f_existe_rowid (
        p_rowid IN VARCHAR2
    ) RETURN BOOLEAN;

    -- 12. Verificar existencia por ROWID y retornar registro
    FUNCTION f_existe_rowid (
        p_rowid                      IN  VARCHAR2,
        pro_tkr_horarios_profesional OUT tkr_horarios_profesional%ROWTYPE
    ) RETURN BOOLEAN;

    -- 13. Actualizar registro completo por PK en ROWTYPE
    PROCEDURE p_actualizar (
        pro_tkr_horarios_profesional IN tkr_horarios_profesional%ROWTYPE
    );

    -- 14. Actualizar indicando PK explícita
    PROCEDURE p_actualizar (
        pro_tkr_horarios_profesional IN tkr_horarios_profesional%ROWTYPE,
        pty_id                       IN tkr_horarios_profesional.id%TYPE
    );

    -- 15. Actualizar por ROWID
    PROCEDURE p_actualizar_rowid (
        pro_tkr_horarios_profesional IN tkr_horarios_profesional%ROWTYPE,
        p_rowid                      IN VARCHAR2
    );

    -- 16. Actualizar todos los registros
    PROCEDURE p_actualizar_registros (
        pro_tkr_horarios_profesional IN tkr_horarios_profesional%ROWTYPE
    );

    -- 17. Obtener valores por defecto
    PROCEDURE p_valores_defecto (
        pro_tkr_horarios_profesional IN OUT tkr_horarios_profesional%ROWTYPE
    );

    -- 18. Verificar existencia y retornar JSON CLOB
    FUNCTION f_existe_json (
        p_id                             IN  tkr_horarios_profesional.id%TYPE,
        p_json_tkr_horarios_profesional  OUT CLOB
    ) RETURN NUMBER;

    -- 19. Obtener JSON por PK
    FUNCTION f_json (
        p_id IN tkr_horarios_profesional.id%TYPE
    ) RETURN VARCHAR2;

    -- 20. Paginación: Calcular total de páginas
    FUNCTION f_total_paginas (
        p_json_entrada IN CLOB
    ) RETURN NUMBER;

    -- 21. Paginación: Consultar registros paginados retornando JSON
    FUNCTION f_consultar_paginado (
        p_pagina    IN NUMBER,
        p_registros IN NUMBER
    ) RETURN CLOB;

END PKGTKR_HORARIOS_PROFESIONAL_DAO;
/
