CREATE OR REPLACE PACKAGE BODY pkgca_tkr_ausencias_profesional
AS
    PROCEDURE p_borrar_ausencias_x_profesional (p_id_usuario IN NUMBER)
    IS
    BEGIN
        DELETE tkr_ausencias_profesional 
         WHERE id_usuario = p_id_usuario;
           --AND fecha_inicial >= f_fecha_actual;
    END p_borrar_ausencias_x_profesional;

    FUNCTION f_existe_ausencia (
        p_id_usuario    IN NUMBER,
        p_fecha_inicial IN DATE,
        p_fecha_final   IN DATE
    ) RETURN BOOLEAN IS
        v_cant NUMBER := 0;
    BEGIN
        SELECT COUNT(1)
          INTO v_cant
          FROM tkr_ausencias_profesional a
         WHERE a.id_usuario = p_id_usuario
           AND a.fecha_inicial <= NVL(p_fecha_final, TO_DATE('9999-12-31', 'YYYY-MM-DD'))
           AND a.fecha_final   >= p_fecha_inicial;

        RETURN (v_cant > 0);
    END f_existe_ausencia;

    FUNCTION f_contar_ausencias_rango (
        p_id_usuario    IN NUMBER,
        p_fecha_inicial IN DATE,
        p_fecha_final   IN DATE
    ) RETURN NUMBER IS
        v_cant NUMBER := 0;
    BEGIN
        SELECT COUNT(1)
          INTO v_cant
          FROM tkr_ausencias_profesional a
         WHERE a.id_usuario = p_id_usuario
           AND a.fecha_inicial <= NVL(p_fecha_final, TO_DATE('9999-12-31', 'YYYY-MM-DD'))
           AND a.fecha_final   >= p_fecha_inicial;

        RETURN v_cant;
    END f_contar_ausencias_rango;
END pkgca_tkr_ausencias_profesional;
/
