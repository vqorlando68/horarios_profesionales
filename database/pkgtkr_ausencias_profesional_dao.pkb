CREATE OR REPLACE PACKAGE BODY pkgtkr_ausencias_profesional_dao
AS
    PROCEDURE p_insertar (pro_tkr_ausencias_profesional IN tkr_ausencias_profesional%ROWTYPE)
    IS
    BEGIN
        INSERT INTO tkr_ausencias_profesional
             VALUES pro_tkr_ausencias_profesional;
    END p_insertar;

    PROCEDURE p_insertar_con_tabla (pta_tkr_ausencias_profesional IN pkgtkr_ausencias_profesional_dao.ta_tkr_ausencias_profesional)
    IS
    BEGIN
        FORALL t IN pta_tkr_ausencias_profesional.FIRST .. pta_tkr_ausencias_profesional.LAST
            INSERT INTO tkr_ausencias_profesional
                 VALUES pta_tkr_ausencias_profesional (t);
    END p_insertar_con_tabla;

    FUNCTION f_traer (pty_id IN tkr_ausencias_profesional.id%TYPE)
        RETURN tkr_ausencias_profesional%ROWTYPE
    IS
        vro_tkr_ausencias_profesional   tkr_ausencias_profesional%ROWTYPE;
    BEGIN
        SELECT *
          INTO vro_tkr_ausencias_profesional
          FROM tkr_ausencias_profesional
         WHERE id = pty_id;

        RETURN vro_tkr_ausencias_profesional;
    END f_traer;

    PROCEDURE p_consultar_registros (pta_tkr_ausencias_profesional OUT pkgtkr_ausencias_profesional_dao.ta_tkr_ausencias_profesional)
    IS
    BEGIN
        SELECT *
          BULK COLLECT INTO pta_tkr_ausencias_profesional
          FROM tkr_ausencias_profesional;
    END p_consultar_registros;

    PROCEDURE p_eliminar_rowid (p_rowid IN VARCHAR2)
    IS
    BEGIN
        DELETE tkr_ausencias_profesional
         WHERE ROWID = p_rowid;
    END p_eliminar_rowid;

    PROCEDURE p_eliminar (pty_id IN tkr_ausencias_profesional.id%TYPE)
    IS
    BEGIN
        DELETE FROM tkr_ausencias_profesional
              WHERE id = pty_id;
    END p_eliminar;

    PROCEDURE p_eliminar_registros
    IS
    BEGIN
        DELETE FROM tkr_ausencias_profesional;
    END p_eliminar_registros;

    FUNCTION f_existe (pty_id IN tkr_ausencias_profesional.id%TYPE)
        RETURN BOOLEAN
    IS
        v_existe        BOOLEAN := TRUE;
        vro_tkr_ausencias_profesional   tkr_ausencias_profesional%ROWTYPE;

        CURSOR cur_tkr_ausencias_profesional IS
            SELECT *
              FROM tkr_ausencias_profesional
             WHERE id = pty_id;
    BEGIN
        OPEN cur_tkr_ausencias_profesional;
        FETCH cur_tkr_ausencias_profesional INTO vro_tkr_ausencias_profesional;
        IF cur_tkr_ausencias_profesional%NOTFOUND
        THEN
            v_existe := FALSE;
        END IF;
        CLOSE cur_tkr_ausencias_profesional;

        RETURN v_existe;
    END f_existe;

    FUNCTION f_existe (pty_id IN tkr_ausencias_profesional.id%TYPE, pro_tkr_ausencias_profesional OUT tkr_ausencias_profesional%ROWTYPE)
        RETURN BOOLEAN
    IS
        v_existe   BOOLEAN := TRUE;

        CURSOR cur_tkr_ausencias_profesional IS
            SELECT *
              FROM tkr_ausencias_profesional
             WHERE id = pty_id;
    BEGIN
        OPEN cur_tkr_ausencias_profesional;
        FETCH cur_tkr_ausencias_profesional INTO pro_tkr_ausencias_profesional;
        IF cur_tkr_ausencias_profesional%NOTFOUND
        THEN
            v_existe := FALSE;
        END IF;
        CLOSE cur_tkr_ausencias_profesional;

        RETURN v_existe;
    END f_existe;

    FUNCTION f_existe (pty_id IN tkr_ausencias_profesional.id%TYPE, pro_tkr_ausencias_profesional OUT tkr_ausencias_profesional%ROWTYPE, p_rowid OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        v_existe   BOOLEAN := TRUE;

        CURSOR cur_rowid IS
            SELECT ROWID
              FROM tkr_ausencias_profesional
             WHERE id = pty_id;

        CURSOR cur_tkr_ausencias_profesional IS
            SELECT *
              FROM tkr_ausencias_profesional
             WHERE id = pty_id;
    BEGIN
        OPEN cur_rowid;
        FETCH cur_rowid INTO p_rowid;
        IF cur_rowid%NOTFOUND
        THEN
            v_existe := FALSE;
        END IF;
        CLOSE cur_rowid;

        IF v_existe = TRUE
        THEN
            OPEN cur_tkr_ausencias_profesional;
            FETCH cur_tkr_ausencias_profesional INTO pro_tkr_ausencias_profesional;
            IF cur_tkr_ausencias_profesional%NOTFOUND
            THEN
                v_existe := FALSE;
            END IF;
            CLOSE cur_tkr_ausencias_profesional;
        END IF;

        RETURN v_existe;
    END f_existe;

    FUNCTION f_existe_rowid (p_rowid IN VARCHAR2)
        RETURN BOOLEAN
    IS
        v_existe        BOOLEAN := TRUE;
        vro_tkr_ausencias_profesional   tkr_ausencias_profesional%ROWTYPE;

        CURSOR cur_tkr_ausencias_profesional IS
            SELECT *
              FROM tkr_ausencias_profesional
             WHERE ROWID = p_rowid;
    BEGIN
        OPEN cur_tkr_ausencias_profesional;
        FETCH cur_tkr_ausencias_profesional INTO vro_tkr_ausencias_profesional;
        IF cur_tkr_ausencias_profesional%NOTFOUND
        THEN
            v_existe := FALSE;
        END IF;
        CLOSE cur_tkr_ausencias_profesional;

        RETURN v_existe;
    END f_existe_rowid;

    FUNCTION f_existe_rowid (p_rowid IN VARCHAR2, pro_tkr_ausencias_profesional OUT tkr_ausencias_profesional%ROWTYPE)
        RETURN BOOLEAN
    IS
        v_existe   BOOLEAN := TRUE;

        CURSOR cur_tkr_ausencias_profesional IS
            SELECT *
              FROM tkr_ausencias_profesional
             WHERE ROWID = p_rowid;
    BEGIN
        OPEN cur_tkr_ausencias_profesional;
        FETCH cur_tkr_ausencias_profesional INTO pro_tkr_ausencias_profesional;
        IF cur_tkr_ausencias_profesional%NOTFOUND
        THEN
            v_existe := FALSE;
        END IF;
        CLOSE cur_tkr_ausencias_profesional;

        RETURN v_existe;
    END f_existe_rowid;

    PROCEDURE p_actualizar (pro_tkr_ausencias_profesional IN tkr_ausencias_profesional%ROWTYPE, pty_id IN tkr_ausencias_profesional.id%TYPE)
    IS
    BEGIN
        UPDATE tkr_ausencias_profesional
           SET row = pro_tkr_ausencias_profesional
         WHERE id = pty_id;
    END p_actualizar;

    PROCEDURE p_actualizar (pro_tkr_ausencias_profesional IN tkr_ausencias_profesional%ROWTYPE)
    IS
    BEGIN
        UPDATE tkr_ausencias_profesional
           SET row = pro_tkr_ausencias_profesional
         WHERE id = pro_tkr_ausencias_profesional.id;
    END p_actualizar;

    PROCEDURE p_actualizar_rowid (pro_tkr_ausencias_profesional IN tkr_ausencias_profesional%ROWTYPE, p_rowid IN VARCHAR2)
    IS
    BEGIN
        UPDATE tkr_ausencias_profesional
           SET row = pro_tkr_ausencias_profesional
         WHERE ROWID = p_rowid;
    END p_actualizar_rowid;

    PROCEDURE p_actualizar_registros (pro_tkr_ausencias_profesional IN tkr_ausencias_profesional%ROWTYPE)
    IS
    BEGIN
        UPDATE tkr_ausencias_profesional
           SET row = pro_tkr_ausencias_profesional;
    END p_actualizar_registros;

    PROCEDURE p_valores_defecto (pro_tkr_ausencias_profesional IN OUT tkr_ausencias_profesional%ROWTYPE)
    IS
        v_cadena        VARCHAR2 (10000) := NULL;
        v_delimitador   VARCHAR2 (1) := NULL;

        TYPE tr_cur IS REF CURSOR;

        cur_tkr_ausencias_profesional   tr_cur;
    BEGIN
        FOR x IN (  SELECT *
                      FROM sys.all_tab_cols c
                     WHERE c.owner = UPPER ('TEKER_DEV') AND c.table_name = UPPER('tkr_ausencias_profesional') AND c.column_id IS NOT NULL
                  ORDER BY c.column_id)
        LOOP
            v_cadena := v_cadena || v_delimitador || NVL (x.data_default, 'null');
            v_delimitador := ',';
        END LOOP;

        v_cadena := 'select ' || v_cadena || ' from dual';

        OPEN cur_tkr_ausencias_profesional FOR v_cadena;
        LOOP
            FETCH cur_tkr_ausencias_profesional INTO pro_tkr_ausencias_profesional;

            EXIT WHEN cur_tkr_ausencias_profesional%NOTFOUND;
        END LOOP;
        CLOSE cur_tkr_ausencias_profesional;
    END p_valores_defecto;

    FUNCTION f_existe_json (p_id IN tkr_ausencias_profesional.id%TYPE, p_json_tkr_ausencias_profesional OUT CLOB)
        RETURN NUMBER
    IS
        v_existe   NUMBER := 1;

        CURSOR cur_tkr_ausencias_profesional IS
            SELECT JSON_OBJECT(
                       'id'             VALUE a.id,
                       'id_usuario'     VALUE a.id_usuario,
                       'fecha_inicial'  VALUE TO_CHAR(a.fecha_inicial, 'YYYY-MM-DD'),
                       'fecha_final'    VALUE TO_CHAR(a.fecha_final, 'YYYY-MM-DD'),
                       'fecha_creacion' VALUE TO_CHAR(a.fecha_creacion, 'YYYY-MM-DD')
                       RETURNING CLOB
                   )
              FROM tkr_ausencias_profesional a
             WHERE a.id = p_id;
    BEGIN
        OPEN cur_tkr_ausencias_profesional;
        FETCH cur_tkr_ausencias_profesional INTO p_json_tkr_ausencias_profesional;
        IF cur_tkr_ausencias_profesional%NOTFOUND
        THEN
            v_existe := 0;
        END IF;
        CLOSE cur_tkr_ausencias_profesional;

        RETURN v_existe;
    END f_existe_json;

    FUNCTION f_json (p_id IN tkr_ausencias_profesional.id%TYPE)
        RETURN VARCHAR2
    IS
        v_json    VARCHAR2(32000);

        CURSOR cur_tkr_ausencias_profesional IS
            SELECT JSON_OBJECT(
                       'id'             VALUE a.id,
                       'id_usuario'     VALUE a.id_usuario,
                       'fecha_inicial'  VALUE TO_CHAR(a.fecha_inicial, 'YYYY-MM-DD'),
                       'fecha_final'    VALUE TO_CHAR(a.fecha_final, 'YYYY-MM-DD'),
                       'fecha_creacion' VALUE TO_CHAR(a.fecha_creacion, 'YYYY-MM-DD')
                   )
              FROM tkr_ausencias_profesional a
             WHERE a.id = p_id;
    BEGIN
        OPEN cur_tkr_ausencias_profesional;
        FETCH cur_tkr_ausencias_profesional INTO v_json;
        CLOSE cur_tkr_ausencias_profesional;

        RETURN v_json;
    END f_json;
END pkgtkr_ausencias_profesional_dao;
/
