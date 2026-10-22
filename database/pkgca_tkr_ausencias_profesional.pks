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

    /*
          Nombre       : f_existe_ausencia
          Descripción  : Función para validar si un profesional ya tiene una ausencia 
                         registrada que se traslape o cubra un rango de fechas.
          -----------------------------------------------------------------------
          Control de modificaciones
          Fecha        Efectuadas por                     Descripción
          ----------   ---------------   ----------------------------------------
          16/10/2026   OAVQ              1. Creación
    */
    FUNCTION f_existe_ausencia (
        p_id_usuario    IN NUMBER,
        p_fecha_inicial IN DATE,
        p_fecha_final   IN DATE
    ) RETURN BOOLEAN;

    /*
          Nombre       : f_contar_ausencias_rango
          Descripción  : Función para contar la cantidad de ausencias registradas 
                         para un profesional que se intersecten con un rango de fechas.
          -----------------------------------------------------------------------
          Control de modificaciones
          Fecha        Efectuadas por                     Descripción
          ----------   ---------------   ----------------------------------------
          20/10/2026   OAVQ              1. Creación
    */
    FUNCTION f_contar_ausencias_rango (
        p_id_usuario    IN NUMBER,
        p_fecha_inicial IN DATE,
        p_fecha_final   IN DATE
    ) RETURN NUMBER;
END pkgca_tkr_ausencias_profesional;
/
