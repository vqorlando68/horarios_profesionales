CREATE OR REPLACE PACKAGE BODY pkgca_tkr_festivos
AS
    /*
    || =========================================================================
    || Paquete     : pkgca_tkr_festivos (Body)
    || Propósito   : Implementación mono-tabla sobre TKR_FESTIVOS.
    || Estándar    : oracle-plsql-architecture
    || =========================================================================
    */

    FUNCTION f_es_festivo (
        p_fecha   IN DATE,
        p_id_pais IN tkr_festivos.id_pais%TYPE DEFAULT 1
    ) RETURN BOOLEAN IS
        v_existe NUMBER(1) := 0;
    BEGIN
        IF p_fecha IS NULL THEN
            RETURN FALSE;
        END IF;

        SELECT 1
          INTO v_existe
          FROM tkr_festivos f
         WHERE TRUNC(f.fecha_festivo) = TRUNC(p_fecha)
           AND f.id_pais = p_id_pais;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN FALSE;
        WHEN OTHERS THEN
            RETURN FALSE;
    END f_es_festivo;

    FUNCTION f_obtener_nombre_festivo (
        p_fecha   IN DATE,
        p_id_pais IN tkr_festivos.id_pais%TYPE DEFAULT 1
    ) RETURN VARCHAR2 IS
        v_nombre tkr_festivos.nombre_festivo%TYPE;
    BEGIN
        IF p_fecha IS NULL THEN
            RETURN NULL;
        END IF;

        SELECT f.nombre_festivo
          INTO v_nombre
          FROM tkr_festivos f
         WHERE TRUNC(f.fecha_festivo) = TRUNC(p_fecha)
           AND f.id_pais = p_id_pais;

        RETURN v_nombre;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
        WHEN OTHERS THEN
            RETURN NULL;
    END f_obtener_nombre_festivo;

    FUNCTION f_consultar_festivos_pais (
        p_id_pais IN tkr_festivos.id_pais%TYPE DEFAULT 1
    ) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT f.id,
                   f.id_pais,
                   TO_CHAR(f.fecha_festivo, 'YYYY-MM-DD') AS fecha_festivo,
                   f.nombre_festivo
              FROM tkr_festivos f
             WHERE f.id_pais = p_id_pais
             ORDER BY f.fecha_festivo ASC;

        RETURN v_cursor;
    END f_consultar_festivos_pais;

END pkgca_tkr_festivos;
/
