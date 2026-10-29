/**
 * =============================================================================
 * CUERPO DEL PAQUETE DAO: PKGTKR_REFRESCAR_AGENDA_DAO
 * =============================================================================
 * Implementación oficial de los 20 métodos estándar para la tabla tkr_refrescar_agenda.
 * =============================================================================
 */
CREATE OR REPLACE PACKAGE BODY PKGTKR_REFRESCAR_AGENDA_DAO
AS
    -- 1. Insertar registro completo
    PROCEDURE p_insertar (
        pro_tkr_refrescar_agenda IN tkr_refrescar_agenda%ROWTYPE
    ) IS
    BEGIN
        INSERT INTO tkr_refrescar_agenda VALUES pro_tkr_refrescar_agenda;
    END p_insertar;

    -- 2. Traer registro por PK
    FUNCTION f_traer (
        pty_id IN tkr_refrescar_agenda.id%TYPE
    ) RETURN tkr_refrescar_agenda%ROWTYPE IS
        vro_tkr_refrescar_agenda tkr_refrescar_agenda%ROWTYPE;
    BEGIN
        SELECT *
          INTO vro_tkr_refrescar_agenda
          FROM tkr_refrescar_agenda
         WHERE id = pty_id;
        RETURN vro_tkr_refrescar_agenda;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END f_traer;

    -- 3. Consultar todos los registros
    PROCEDURE p_consultar_registros (
        pta_tkr_refrescar_agenda OUT PKGTKR_REFRESCAR_AGENDA_DAO.t_tkr_refrescar_agenda
    ) IS
    BEGIN
        SELECT *
          BULK COLLECT INTO pta_tkr_refrescar_agenda
          FROM tkr_refrescar_agenda;
    END p_consultar_registros;

    -- 4. Eliminar registro por ROWID
    PROCEDURE p_eliminar_rowid (
        p_rowid IN VARCHAR2
    ) IS
    BEGIN
        DELETE FROM tkr_refrescar_agenda
         WHERE ROWID = p_rowid;
    END p_eliminar_rowid;

    -- 5. Eliminar registro por PK
    PROCEDURE p_eliminar (
        pty_id IN tkr_refrescar_agenda.id%TYPE
    ) IS
    BEGIN
        DELETE FROM tkr_refrescar_agenda
         WHERE id = pty_id;
    END p_eliminar;

    -- 6. Eliminar todos los registros (Uso restringido)
    PROCEDURE p_eliminar_registros IS
    BEGIN
        DELETE FROM tkr_refrescar_agenda;
    END p_eliminar_registros;

    -- 7. Verificar existencia por PK
    FUNCTION f_existe (
        pty_id IN tkr_refrescar_agenda.id%TYPE
    ) RETURN BOOLEAN IS
        v_existe NUMBER(1);
    BEGIN
        SELECT 1
          INTO v_existe
          FROM tkr_refrescar_agenda
         WHERE id = pty_id;
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN FALSE;
    END f_existe;

    -- 8. Verificar existencia y retornar registro
    FUNCTION f_existe (
        pty_id                   IN  tkr_refrescar_agenda.id%TYPE,
        pro_tkr_refrescar_agenda OUT tkr_refrescar_agenda%ROWTYPE
    ) RETURN BOOLEAN IS
    BEGIN
        SELECT *
          INTO pro_tkr_refrescar_agenda
          FROM tkr_refrescar_agenda
         WHERE id = pty_id;
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN FALSE;
    END f_existe;

    -- 9. Verificar existencia, retornar registro y ROWID
    FUNCTION f_existe (
        pty_id                   IN  tkr_refrescar_agenda.id%TYPE,
        pro_tkr_refrescar_agenda OUT tkr_refrescar_agenda%ROWTYPE,
        p_rowid                  OUT VARCHAR2
    ) RETURN BOOLEAN IS
    BEGIN
        SELECT ROWID
          INTO p_rowid
          FROM tkr_refrescar_agenda
         WHERE id = pty_id;

        SELECT *
          INTO pro_tkr_refrescar_agenda
          FROM tkr_refrescar_agenda
         WHERE ROWID = p_rowid;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN FALSE;
    END f_existe;

    -- 10. Verificar existencia por ROWID
    FUNCTION f_existe_rowid (
        p_rowid IN VARCHAR2
    ) RETURN BOOLEAN IS
        v_existe NUMBER(1);
    BEGIN
        SELECT 1
          INTO v_existe
          FROM tkr_refrescar_agenda
         WHERE ROWID = p_rowid;
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN FALSE;
    END f_existe_rowid;

    -- 11. Verificar existencia por ROWID y retornar registro
    FUNCTION f_existe_rowid (
        p_rowid                  IN  VARCHAR2,
        pro_tkr_refrescar_agenda OUT tkr_refrescar_agenda%ROWTYPE
    ) RETURN BOOLEAN IS
    BEGIN
        SELECT *
          INTO pro_tkr_refrescar_agenda
          FROM tkr_refrescar_agenda
         WHERE ROWID = p_rowid;
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN FALSE;
    END f_existe_rowid;

    -- 12. Actualizar registro completo por PK en ROWTYPE
    PROCEDURE p_actualizar (
        pro_tkr_refrescar_agenda IN tkr_refrescar_agenda%ROWTYPE
    ) IS
    BEGIN
        UPDATE tkr_refrescar_agenda
           SET ROW = pro_tkr_refrescar_agenda
         WHERE id = pro_tkr_refrescar_agenda.id;
    END p_actualizar;

    -- 13. Actualizar indicando PK explícita
    PROCEDURE p_actualizar (
        pro_tkr_refrescar_agenda IN tkr_refrescar_agenda%ROWTYPE,
        pty_id                   IN tkr_refrescar_agenda.id%TYPE
    ) IS
    BEGIN
        UPDATE tkr_refrescar_agenda
           SET ROW = pro_tkr_refrescar_agenda
         WHERE id = pty_id;
    END p_actualizar;

    -- 14. Actualizar por ROWID
    PROCEDURE p_actualizar_rowid (
        pro_tkr_refrescar_agenda IN tkr_refrescar_agenda%ROWTYPE,
        p_rowid                  IN VARCHAR2
    ) IS
    BEGIN
        UPDATE tkr_refrescar_agenda
           SET ROW = pro_tkr_refrescar_agenda
         WHERE ROWID = p_rowid;
    END p_actualizar_rowid;

    -- 15. Actualizar todos los registros (Uso restringido)
    PROCEDURE p_actualizar_registros (
        pro_tkr_refrescar_agenda IN tkr_refrescar_agenda%ROWTYPE
    ) IS
    BEGIN
        UPDATE tkr_refrescar_agenda
           SET ROW = pro_tkr_refrescar_agenda;
    END p_actualizar_registros;

    -- 16. Obtener valores por defecto
    PROCEDURE p_valores_defecto (
        pro_tkr_refrescar_agenda IN OUT tkr_refrescar_agenda%ROWTYPE
    ) IS
    BEGIN
        pro_tkr_refrescar_agenda.fecha := TRUNC(f_fecha_actual);
    END p_valores_defecto;

    -- 17. Verificar existencia y retornar JSON CLOB
    FUNCTION f_existe_json (
        p_id                        IN  tkr_refrescar_agenda.id%TYPE,
        p_json_tkr_refrescar_agenda OUT CLOB
    ) RETURN NUMBER IS
    BEGIN
        SELECT JSON_OBJECT(*)
          INTO p_json_tkr_refrescar_agenda
          FROM tkr_refrescar_agenda
         WHERE id = p_id;
        RETURN 1;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_json_tkr_refrescar_agenda := NULL;
            RETURN 0;
    END f_existe_json;

    -- 18. Obtener JSON por PK
    FUNCTION f_json (
        p_id IN tkr_refrescar_agenda.id%TYPE
    ) RETURN VARCHAR2 IS
        v_json VARCHAR2(4000);
    BEGIN
        SELECT JSON_OBJECT(*)
          INTO v_json
          FROM tkr_refrescar_agenda
         WHERE id = p_id;
        RETURN v_json;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END f_json;

    -- 19. Calcular total de páginas para paginación recibiendo JSON con campo "registros"
    FUNCTION f_total_paginas (
        p_json_entrada IN CLOB
    ) RETURN NUMBER IS
        v_registros_por_pagina NUMBER;
        v_total_registros      NUMBER;
    BEGIN
        v_registros_por_pagina := NVL(TO_NUMBER(JSON_VALUE(p_json_entrada, '$.registros')), 10);
        IF v_registros_por_pagina <= 0 THEN
            v_registros_por_pagina := 10;
        END IF;

        SELECT COUNT(1)
          INTO v_total_registros
          FROM tkr_refrescar_agenda;

        RETURN CEIL(v_total_registros / v_registros_por_pagina);
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 0;
    END f_total_paginas;

    -- 20. Consultar registros paginados retornando JSON con información correspondiente
    FUNCTION f_consultar_paginado (
        p_pagina    IN NUMBER,
        p_registros IN NUMBER
    ) RETURN CLOB IS
        v_offset NUMBER;
        v_limite NUMBER;
        v_json   CLOB;
    BEGIN
        v_limite := NVL(p_registros, 10);
        IF v_limite <= 0 THEN
            v_limite := 10;
        END IF;

        v_offset := (GREATEST(NVL(p_pagina, 1), 1) - 1) * v_limite;

        SELECT NVL(
                   JSON_ARRAYAGG(
                       JSON_OBJECT(*)
                       RETURNING CLOB
                   ),
                   TO_CLOB('[]')
               )
          INTO v_json
          FROM (
              SELECT *
                FROM tkr_refrescar_agenda
               ORDER BY id ASC
              OFFSET v_offset ROWS
               FETCH NEXT v_limite ROWS ONLY
          ) t;

        RETURN v_json;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN TO_CLOB('[]');
    END f_consultar_paginado;

END PKGTKR_REFRESCAR_AGENDA_DAO;
/

