CREATE OR REPLACE PACKAGE PKGTKR_AUSENCIAS_PROFESIONAL_DAO
AS
    /*
    || =========================================================================
    || Paquete: PKGTKR_AUSENCIAS_PROFESIONAL_DAO
    || Propósito: Acceso a datos de la tabla TKR_AUSENCIAS_PROFESIONAL.
    || Estándar: oracle-plsql-architecture (20 métodos oficiales)
    || =========================================================================
    */

    TYPE t_tkr_ausencias_profesional IS TABLE OF tkr_ausencias_profesional%ROWTYPE
        INDEX BY BINARY_INTEGER;

    -- Compatibilidad hacia atrás
    SUBTYPE ta_tkr_ausencias_profesional IS t_tkr_ausencias_profesional;

    -- 1. Insertar
    PROCEDURE p_insertar (
        pro_tkr_ausencias_profesional IN tkr_ausencias_profesional%ROWTYPE
    );

    -- 2. Insertar con tabla PL
    PROCEDURE p_insertar_con_tabla (
        pta_tkr_ausencias_profesional IN PKGTKR_AUSENCIAS_PROFESIONAL_DAO.t_tkr_ausencias_profesional
    );

    -- 3. Traer por PK
    FUNCTION f_traer (
        pty_id IN tkr_ausencias_profesional.id%TYPE
    ) RETURN tkr_ausencias_profesional%ROWTYPE;

    -- 4. Consultar todos los registros
    PROCEDURE p_consultar_registros (
        pta_tkr_ausencias_profesional OUT PKGTKR_AUSENCIAS_PROFESIONAL_DAO.t_tkr_ausencias_profesional
    );

    -- 5. Eliminar por ROWID
    PROCEDURE p_eliminar_rowid (
        p_rowid IN VARCHAR2
    );

    -- 6. Eliminar por PK
    PROCEDURE p_eliminar (
        pty_id IN tkr_ausencias_profesional.id%TYPE
    );

    -- 7. Eliminar todos
    PROCEDURE p_eliminar_registros;

    -- 8. Existe por PK
    FUNCTION f_existe (
        pty_id IN tkr_ausencias_profesional.id%TYPE
    ) RETURN BOOLEAN;

    -- 9. Existe y retorna registro
    FUNCTION f_existe (
        pty_id                        IN  tkr_ausencias_profesional.id%TYPE,
        pro_tkr_ausencias_profesional OUT tkr_ausencias_profesional%ROWTYPE
    ) RETURN BOOLEAN;

    -- 10. Existe, retorna registro y ROWID
    FUNCTION f_existe (
        pty_id                        IN  tkr_ausencias_profesional.id%TYPE,
        pro_tkr_ausencias_profesional OUT tkr_ausencias_profesional%ROWTYPE,
        p_rowid                       OUT VARCHAR2
    ) RETURN BOOLEAN;

    -- 11. Existe por ROWID
    FUNCTION f_existe_rowid (
        p_rowid IN VARCHAR2
    ) RETURN BOOLEAN;

    -- 12. Existe por ROWID y retorna registro
    FUNCTION f_existe_rowid (
        p_rowid                       IN  VARCHAR2,
        pro_tkr_ausencias_profesional OUT tkr_ausencias_profesional%ROWTYPE
    ) RETURN BOOLEAN;

    -- 13. Actualizar registro completo por PK en ROWTYPE
    PROCEDURE p_actualizar (
        pro_tkr_ausencias_profesional IN tkr_ausencias_profesional%ROWTYPE
    );

    -- 14. Actualizar con PK explícita
    PROCEDURE p_actualizar (
        pro_tkr_ausencias_profesional IN tkr_ausencias_profesional%ROWTYPE,
        pty_id                        IN tkr_ausencias_profesional.id%TYPE
    );

    -- 15. Actualizar por ROWID
    PROCEDURE p_actualizar_rowid (
        pro_tkr_ausencias_profesional IN tkr_ausencias_profesional%ROWTYPE,
        p_rowid                       IN VARCHAR2
    );

    -- 16. Actualizar todos
    PROCEDURE p_actualizar_registros (
        pro_tkr_ausencias_profesional IN tkr_ausencias_profesional%ROWTYPE
    );

    -- 17. Valores por defecto
    PROCEDURE p_valores_defecto (
        pro_tkr_ausencias_profesional IN OUT tkr_ausencias_profesional%ROWTYPE
    );

    -- 18. Existe JSON
    FUNCTION f_existe_json (
        p_id                              IN  tkr_ausencias_profesional.id%TYPE,
        p_json_tkr_ausencias_profesional  OUT CLOB
    ) RETURN NUMBER;

    -- 19. JSON por PK
    FUNCTION f_json (
        p_id IN tkr_ausencias_profesional.id%TYPE
    ) RETURN VARCHAR2;

    -- 20. Total páginas
    FUNCTION f_total_paginas (
        p_json_entrada IN CLOB
    ) RETURN NUMBER;

    -- 21. Consultar paginado
    FUNCTION f_consultar_paginado (
        p_pagina    IN NUMBER,
        p_registros IN NUMBER
    ) RETURN CLOB;

END PKGTKR_AUSENCIAS_PROFESIONAL_DAO;
/
