CREATE OR REPLACE PACKAGE BODY PKGTKR_AUSENCIAS_PROFESIONAL_DAO
AS
    /*
    || =========================================================================
    || Paquete: PKGTKR_AUSENCIAS_PROFESIONAL_DAO (Body)
    || Propósito: Implementación oficial de persistencia para
    ||            TKR_AUSENCIAS_PROFESIONAL.
    || Estándar: oracle-plsql-architecture
    || =========================================================================
    */

    -- 1. Insertar
    PROCEDURE p_insertar (
        pro_tkr_ausencias_profesional IN tkr_ausencias_profesional%ROWTYPE
    ) IS
    BEGIN
        INSERT INTO tkr_ausencias_profesional VALUES pro_tkr_ausencias_profesional;
    END p_insertar;

    -- 2. Insertar colección
    PROCEDURE p_insertar_con_tabla (
        pta_tkr_ausencias_profesional IN PKGTKR_AUSENCIAS_PROFESIONAL_DAO.t_tkr_ausencias_profesional
    ) IS
    BEGIN
        FORALL i IN pta_tkr_ausencias_profesional.FIRST .. pta_tkr_ausencias_profesional.LAST
            INSERT INTO tkr_ausencias_profesional VALUES pta_tkr_ausencias_profesional(i);
    END p_insertar_con_tabla;

    -- 3. Traer por PK
    FUNCTION f_traer (
        pty_id IN tkr_ausencias_profesional.id%TYPE
    ) RETURN tkr_ausencias_profesional%ROWTYPE IS
        vro_reg tkr_ausencias_profesional%ROWTYPE;
    BEGIN
        SELECT *
          INTO vro_reg
          FROM tkr_ausencias_profesional
         WHERE id = pty_id;
        RETURN vro_reg;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END f_traer;

    -- 4. Consultar todos
    PROCEDURE p_consultar_registros (
        pta_tkr_ausencias_profesional OUT PKGTKR_AUSENCIAS_PROFESIONAL_DAO.t_tkr_ausencias_profesional
    ) IS
    BEGIN
        SELECT *
          BULK COLLECT INTO pta_tkr_ausencias_profesional
          FROM tkr_ausencias_profesional;
    END p_consultar_registros;

    -- 5. Eliminar por ROWID
    PROCEDURE p_eliminar_rowid (
        p_rowid IN VARCHAR2
    ) IS
    BEGIN
        DELETE FROM tkr_ausencias_profesional WHERE ROWID = p_rowid;
    END p_eliminar_rowid;

    -- 6. Eliminar por PK
    PROCEDURE p_eliminar (
        pty_id IN tkr_ausencias_profesional.id%TYPE
    ) IS
    BEGIN
        DELETE FROM tkr_ausencias_profesional WHERE id = pty_id;
    END p_eliminar;

    -- 7. Eliminar todos
    PROCEDURE p_eliminar_registros IS
    BEGIN
        DELETE FROM tkr_ausencias_profesional;
    END p_eliminar_registros;

    -- 8. Existe por PK
    FUNCTION f_existe (
        pty_id IN tkr_ausencias_profesional.id%TYPE
    ) RETURN BOOLEAN IS
        v_dummy NUMBER;
    BEGIN
        SELECT 1
          INTO v_dummy
          FROM tkr_ausencias_profesional
         WHERE id = pty_id;
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN FALSE;
    END f_existe;

    -- 9. Existe y retorna registro
    FUNCTION f_existe (
        pty_id                        IN  tkr_ausencias_profesional.id%TYPE,
        pro_tkr_ausencias_profesional OUT tkr_ausencias_profesional%ROWTYPE
    ) RETURN BOOLEAN IS
    BEGIN
        SELECT *
          INTO pro_tkr_ausencias_profesional
          FROM tkr_ausencias_profesional
         WHERE id = pty_id;
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN FALSE;
    END f_existe;

    -- 10. Existe, retorna registro y ROWID
    FUNCTION f_existe (
        pty_id                        IN  tkr_ausencias_profesional.id%TYPE,
        pro_tkr_ausencias_profesional OUT tkr_ausencias_profesional%ROWTYPE,
        p_rowid                       OUT VARCHAR2
    ) RETURN BOOLEAN IS
    BEGIN
        SELECT t.*, ROWID
          INTO pro_tkr_ausencias_profesional, p_rowid
          FROM tkr_ausencias_profesional t
         WHERE id = pty_id;
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_rowid := NULL;
            RETURN FALSE;
    END f_existe;

    -- 11. Existe por ROWID
    FUNCTION f_existe_rowid (
        p_rowid IN VARCHAR2
    ) RETURN BOOLEAN IS
        v_dummy NUMBER;
    BEGIN
        SELECT 1
          INTO v_dummy
          FROM tkr_ausencias_profesional
         WHERE ROWID = p_rowid;
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN FALSE;
    END f_existe_rowid;

    -- 12. Existe por ROWID y retorna registro
    FUNCTION f_existe_rowid (
        p_rowid                       IN  VARCHAR2,
        pro_tkr_ausencias_profesional OUT tkr_ausencias_profesional%ROWTYPE
    ) RETURN BOOLEAN IS
    BEGIN
        SELECT *
          INTO pro_tkr_ausencias_profesional
          FROM tkr_ausencias_profesional
         WHERE ROWID = p_rowid;
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN FALSE;
    END f_existe_rowid;

    -- 13. Actualizar por ROWTYPE
    PROCEDURE p_actualizar (
        pro_tkr_ausencias_profesional IN tkr_ausencias_profesional%ROWTYPE
    ) IS
    BEGIN
        UPDATE tkr_ausencias_profesional
           SET ROW = pro_tkr_ausencias_profesional
         WHERE id = pro_tkr_ausencias_profesional.id;
    END p_actualizar;

    -- 14. Actualizar con PK explícita
    PROCEDURE p_actualizar (
        pro_tkr_ausencias_profesional IN tkr_ausencias_profesional%ROWTYPE,
        pty_id                        IN tkr_ausencias_profesional.id%TYPE
    ) IS
    BEGIN
        UPDATE tkr_ausencias_profesional
           SET ROW = pro_tkr_ausencias_profesional
         WHERE id = pty_id;
    END p_actualizar;

    -- 15. Actualizar por ROWID
    PROCEDURE p_actualizar_rowid (
        pro_tkr_ausencias_profesional IN tkr_ausencias_profesional%ROWTYPE,
        p_rowid                       IN VARCHAR2
    ) IS
    BEGIN
        UPDATE tkr_ausencias_profesional
           SET ROW = pro_tkr_ausencias_profesional
         WHERE ROWID = p_rowid;
    END p_actualizar_rowid;

    -- 16. Actualizar todos
    PROCEDURE p_actualizar_registros (
        pro_tkr_ausencias_profesional IN tkr_ausencias_profesional%ROWTYPE
    ) IS
    BEGIN
        UPDATE tkr_ausencias_profesional
           SET ROW = pro_tkr_ausencias_profesional;
    END p_actualizar_registros;

    -- 17. Valores por defecto
    PROCEDURE p_valores_defecto (
        pro_tkr_ausencias_profesional IN OUT tkr_ausencias_profesional%ROWTYPE
    ) IS
    BEGIN
        pro_tkr_ausencias_profesional.fecha_creacion := SYSDATE;
    END p_valores_defecto;

    -- 18. Existe JSON
    FUNCTION f_existe_json (
        p_id                              IN  tkr_ausencias_profesional.id%TYPE,
        p_json_tkr_ausencias_profesional  OUT CLOB
    ) RETURN NUMBER IS
        v_existe NUMBER := 0;
    BEGIN
        SELECT 1,
               JSON_OBJECT(
                   'id'             VALUE t.id,
                   'id_usuario'     VALUE t.id_usuario,
                   'fecha_inicial'  VALUE TO_CHAR(t.fecha_inicial, 'YYYY-MM-DD'),
                   'fecha_final'    VALUE TO_CHAR(t.fecha_final, 'YYYY-MM-DD'),
                   'fecha_creacion' VALUE TO_CHAR(t.fecha_creacion, 'YYYY-MM-DD"T"HH24:MI:SS')
                   RETURNING CLOB
               )
          INTO v_existe, p_json_tkr_ausencias_profesional
          FROM tkr_ausencias_profesional t
         WHERE t.id = p_id;
        RETURN v_existe;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_json_tkr_ausencias_profesional := NULL;
            RETURN 0;
    END f_existe_json;

    -- 19. JSON por PK
    FUNCTION f_json (
        p_id IN tkr_ausencias_profesional.id%TYPE
    ) RETURN VARCHAR2 IS
        v_json VARCHAR2(4000);
    BEGIN
        SELECT JSON_OBJECT(
                   'id'            VALUE t.id,
                   'id_usuario'    VALUE t.id_usuario,
                   'fecha_inicial' VALUE TO_CHAR(t.fecha_inicial, 'YYYY-MM-DD'),
                   'fecha_final'   VALUE TO_CHAR(t.fecha_final, 'YYYY-MM-DD')
               )
          INTO v_json
          FROM tkr_ausencias_profesional t
         WHERE t.id = p_id;
        RETURN v_json;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END f_json;

    -- 20. Total páginas
    FUNCTION f_total_paginas (
        p_json_entrada IN CLOB
    ) RETURN NUMBER IS
        v_obj_in    JSON_OBJECT_T;
        v_registros NUMBER := 10;
        v_total_reg NUMBER := 0;
    BEGIN
        IF p_json_entrada IS NOT NULL THEN
            v_obj_in    := JSON_OBJECT_T.parse(p_json_entrada);
            v_registros := NVL(v_obj_in.get_number('registros_por_pagina'), 10);
        END IF;

        SELECT COUNT(*)
          INTO v_total_reg
          FROM tkr_ausencias_profesional;

        RETURN CEIL(v_total_reg / v_registros);
    END f_total_paginas;

    -- 21. Consultar paginado
    FUNCTION f_consultar_paginado (
        p_pagina    IN NUMBER,
        p_registros IN NUMBER
    ) RETURN CLOB IS
        v_offset NUMBER;
        v_json   CLOB;
    BEGIN
        v_offset := (NVL(p_pagina, 1) - 1) * NVL(p_registros, 10);

        SELECT JSON_OBJECT(
                   'pagina'             VALUE p_pagina,
                   'registros_solicitados' VALUE p_registros,
                   'datos'              VALUE COALESCE(
                       JSON_ARRAYAGG(
                           JSON_OBJECT(
                               'id'            VALUE t.id,
                               'id_usuario'    VALUE t.id_usuario,
                               'fecha_inicial' VALUE TO_CHAR(t.fecha_inicial, 'YYYY-MM-DD'),
                               'fecha_final'   VALUE TO_CHAR(t.fecha_final, 'YYYY-MM-DD'),
                               'fecha_creacion' VALUE TO_CHAR(t.fecha_creacion, 'YYYY-MM-DD"T"HH24:MI:SS')
                           )
                           ORDER BY t.fecha_inicial DESC
                       ),
                       JSON_ARRAY()
                   )
                   RETURNING CLOB
               )
          INTO v_json
          FROM (
              SELECT *
                FROM tkr_ausencias_profesional
               ORDER BY id
              OFFSET v_offset ROWS FETCH NEXT p_registros ROWS ONLY
          ) t;

        RETURN v_json;
    END f_consultar_paginado;

END PKGTKR_AUSENCIAS_PROFESIONAL_DAO;
/
