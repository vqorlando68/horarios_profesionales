CREATE OR REPLACE PACKAGE BODY pkgca_tkr_ausencias_profesional
AS
    PROCEDURE p_borrar_ausencias_x_profesional (p_id_usuario IN NUMBER)
    IS
    BEGIN
        DELETE tkr_ausencias_profesional 
         WHERE id_usuario = p_id_usuario;
           --AND fecha_inicial >= f_fecha_actual;
    END p_borrar_ausencias_x_profesional;
END pkgca_tkr_ausencias_profesional;
/
