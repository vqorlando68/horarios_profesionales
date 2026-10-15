CREATE OR REPLACE PACKAGE pkgca_tkr_ausencias_profesional
AS
    /*
          Nombre       : pkgca_tkr_ausencias_profesional
          Descripción  : Paquete realizar DML sobre la tabla tkr_ausencias_profesional 
                         que no sean sobre la llave primaria
          Autor        : Orlando Arturo Valverde Quiceno
          e-mail       : vqorlando@gmail.com
          ----------------------------------------------------------------------
          Control de modificaciones
          Fecha        Efectuadas por                     Descripción
          ----------   ---------------   ---------------------------------------
          02/10/2025   OAVQ              1. Creación
    */
    /*
          Nombre       : p_borrar_ausencias_x_profesional
          Descripción  : Procedimiento para borar las ausencias de un profesional.
          -----------------------------------------------------------------------
          Control de modificaciones
          Fecha        Efectuadas por                     Descripción
          ----------   ---------------   ----------------------------------------
          02/10/2025   OAVQ              1. Creación
    */
    PROCEDURE p_borrar_ausencias_x_profesional (p_id_usuario IN NUMBER);
END pkgca_tkr_ausencias_profesional;
/
