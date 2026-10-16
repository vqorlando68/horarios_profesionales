CREATE OR REPLACE PACKAGE pkgtkr_ausencias_profesional_dao
AS
    /*
        nombre       : pkgtkr_ausencias_profesional_dao
        descripción  : paquete primario de la tabla tkr_ausencias_profesional
        ------------------------------------------------------------------------
        control de modificaciones
        fecha        efectuadas por                     descripción
        ----------   ------------------- ---------------------------------------
        02/10/2025   oavq                1. creación del paquete
    */

    TYPE ta_tkr_ausencias_profesional IS TABLE OF tkr_ausencias_profesional%ROWTYPE
        INDEX BY BINARY_INTEGER;

    /*
        nombre       : p_insertar
        descripción  : procedimiento que inserta un registro de la tabla
                       [tkr_ausencias_profesional]
        ------------------------------------------------------------------------
        control de modificaciones
        fecha        efectuadas por                     descripción
        ----------   ------------------- ---------------------------------------
        02/10/2025   oavq                1. creación
    */
    PROCEDURE p_insertar (pro_tkr_ausencias_profesional IN tkr_ausencias_profesional%ROWTYPE);

    /*
        nombre       : p_insertar_con_tabla
        descripción  : procedimiento que inserta un registro de la tabla
                       [tkr_ausencias_profesional] con una tabla pl.
        ------------------------------------------------------------------------
        control de modificaciones
        fecha        efectuadas por                     descripción
        ----------   ------------------- ---------------------------------------
        02/10/2025   oavq                1. creación
    */
    PROCEDURE p_insertar_con_tabla (pta_tkr_ausencias_profesional IN pkgtkr_ausencias_profesional_dao.ta_tkr_ausencias_profesional);

    /*
        nombre       : f_traer
        descripción  : función que retorna un registro de la tabla
                       [tkr_ausencias_profesional]
        ------------------------------------------------------------------------
        control de modificaciones
        fecha        efectuadas por                     descripción
        ----------   ------------------- ---------------------------------------
        02/10/2025   oavq                1. creación
    */
    FUNCTION f_traer (pty_id IN tkr_ausencias_profesional.id%TYPE)
        RETURN tkr_ausencias_profesional%ROWTYPE;

    /*
        nombre       : p_consultar_registros
        descripción  : procedimiento que retorna todos los registros de la tabla
                       [tkr_ausencias_profesional]
        ------------------------------------------------------------------------
        control de modificaciones
        fecha        efectuadas por                     descripción
        ----------   ------------------- ---------------------------------------
        02/10/2025   oavq                1. creación
    */
    PROCEDURE p_consultar_registros (pta_tkr_ausencias_profesional OUT pkgtkr_ausencias_profesional_dao.ta_tkr_ausencias_profesional);

    /*
        nombre       : p_eliminar_rowid
        descripción  : procedimiento que elimina un registro de la tabla
                       [tkr_ausencias_profesional] por rowid
        ------------------------------------------------------------------------
        control de modificaciones
        fecha        efectuadas por                     descripción
        ----------   ------------------- ---------------------------------------
        02/10/2025   oavq                1. creación del paquete
    */
    PROCEDURE p_eliminar_rowid (p_rowid IN VARCHAR2);

    /*
        nombre       : p_eliminar
        descripción  : procedimiento que elimina un registro de la tabla
                       [tkr_ausencias_profesional]
        ------------------------------------------------------------------------
        control de modificaciones
        fecha        efectuadas por                     descripción
        ----------   ------------------- ---------------------------------------
        02/10/2025   oavq                1. creación
    */
    PROCEDURE p_eliminar (pty_id IN tkr_ausencias_profesional.id%TYPE);

    /*
        nombre       : p_eliminar_registros
        descripción  : procedimiento que elimina todos los registros de la tabla
                       [tkr_ausencias_profesional]
        ------------------------------------------------------------------------
        control de modificaciones
        fecha        efectuadas por                     descripción
        ----------   ------------------- ---------------------------------------
        02/10/2025   oavq                1. creación
    */
    PROCEDURE p_eliminar_registros;

    /*
        nombre       : f_existe
        descripción  : función que retorna si un registro existe o no de la tabla
                       [tkr_ausencias_profesional]
        ------------------------------------------------------------------------
        control de modificaciones
        fecha        efectuadas por                     descripción
        ----------   ------------------- ---------------------------------------
        02/10/2025   oavq                1. creación del paquete
    */
    FUNCTION f_existe (pty_id IN tkr_ausencias_profesional.id%TYPE)
        RETURN BOOLEAN;

    /*
        nombre       : f_existe
        descripción  : función que retorna si un regitro existe o no de la tabla
                       [tkr_ausencias_profesional] con la información del registro en caso
                       de encontrarlo
        ------------------------------------------------------------------------
        control de modificaciones
        fecha        efectuadas por                     descripción
        ----------   ------------------- ---------------------------------------
        02/10/2025   oavq                1. creación
    */
    FUNCTION f_existe (pty_id IN tkr_ausencias_profesional.id%TYPE, pro_tkr_ausencias_profesional OUT tkr_ausencias_profesional%ROWTYPE)
        RETURN BOOLEAN;

    /*
        nombre       : f_existe
        descripción  : función que retorna si un regitro existe o no de la tabla
                       [tkr_ausencias_profesional] con la información del registro como el
                       rowid en caso de encontrarlo
        ------------------------------------------------------------------------
        control de modificaciones
        fecha        efectuadas por                     descripción
        ----------   ------------------- ---------------------------------------
        02/10/2025   oavq                1. creación
    */
    FUNCTION f_existe (pty_id IN tkr_ausencias_profesional.id%TYPE, pro_tkr_ausencias_profesional OUT tkr_ausencias_profesional%ROWTYPE, p_rowid OUT VARCHAR2)
        RETURN BOOLEAN;

    /*
        nombre       : f_existe_rowid
        descripción  : función que retorna si un registro existe o no de la tabla
                       [tkr_ausencias_profesional]
        ------------------------------------------------------------------------
        control de modificaciones
        fecha        efectuadas por                     descripción
        ----------   ------------------- ---------------------------------------
        02/10/2025   oavq                1. creación del paquete
    */
    FUNCTION f_existe_rowid (p_rowid IN VARCHAR2)
        RETURN BOOLEAN;

    /*
        nombre       : f_existe_rowid
        descripción  : función que retorna si un registro existe o no de la tabla
                       [tkr_ausencias_profesional]
        ------------------------------------------------------------------------
        control de modificaciones
        fecha        efectuadas por                     descripción
        ----------   ------------------- ---------------------------------------
        02/10/2025   oavq                1. creación del paquete
    */
    FUNCTION f_existe_rowid (p_rowid IN VARCHAR2, pro_tkr_ausencias_profesional OUT tkr_ausencias_profesional%ROWTYPE)
        RETURN BOOLEAN;

    /*
        nombre       : p_actualizar
        descripción  : procedimiento que actualiza un registro de la tabla
                       [tkr_ausencias_profesional]
        ------------------------------------------------------------------------
        control de modificaciones
        fecha        efectuadas por                     descripción
        ----------   ------------------- ---------------------------------------
        02/10/2025   oavq                1. creación
    */
    PROCEDURE p_actualizar (pro_tkr_ausencias_profesional IN tkr_ausencias_profesional%ROWTYPE);

    /*
        nombre       : p_actualizar
        descripción  : procedimiento que actualiza un registro de la tabla
                       [tkr_ausencias_profesional]
        ------------------------------------------------------------------------
        control de modificaciones
        fecha        efectuadas por                     descripción
        ----------   ------------------- ---------------------------------------
        02/10/2025   oavq                1. creación del paquete
    */
    PROCEDURE p_actualizar (pro_tkr_ausencias_profesional IN tkr_ausencias_profesional%ROWTYPE, pty_id IN tkr_ausencias_profesional.id%TYPE);

    /*
        nombre       : p_actualizar_rowid
        descripción  : procedimiento que actualiza un registro de la tabla
                       [tkr_ausencias_profesional]
        ------------------------------------------------------------------------
        control de modificaciones
        fecha        efectuadas por                     descripción
        ----------   ------------------- ---------------------------------------
        02/10/2025   oavq                1. creación del paquete
    */
    PROCEDURE p_actualizar_rowid (pro_tkr_ausencias_profesional IN tkr_ausencias_profesional%ROWTYPE, p_rowid IN VARCHAR2);

    /*
        nombre       : p_actualizar_registros
        descripción  : procedimiento que actualiza todos los registros de la tabla
                       [tkr_ausencias_profesional]
        ------------------------------------------------------------------------
        control de modificaciones
        fecha        efectuadas por                     descripción
        ----------   ------------------- ---------------------------------------
        02/10/2025   oavq                1. creación del paquete
    */
    PROCEDURE p_actualizar_registros (pro_tkr_ausencias_profesional IN tkr_ausencias_profesional%ROWTYPE);

    /*
        nombre       : p_valores_defecto
        descripción  : procedimiento que devuelve los valores por defecto de la
                       tabla [tkr_ausencias_profesional]
        ------------------------------------------------------------------------
        control de modificaciones
        fecha        efectuadas por                     descripción
        ----------   ------------------- ---------------------------------------
        02/10/2025   oavq                1. creación del paquete
    */
    PROCEDURE p_valores_defecto (pro_tkr_ausencias_profesional IN OUT tkr_ausencias_profesional%ROWTYPE);

    /*
        nombre       : f_existe_json
        descripción  : función que retorna si un regitro existe o no de la tabla
                       [tkr_ausencias_profesional] con la información del registro en un json
                       en caso de encontrarlo, si existe devuelve 1
        ------------------------------------------------------------------------
        control de modificaciones
        fecha        efectuadas por                     descripción
        ----------   ------------------- ---------------------------------------
        02/10/2025   oavq                1. creación de la función
    */
    FUNCTION f_existe_json (p_id IN tkr_ausencias_profesional.id%TYPE, p_json_tkr_ausencias_profesional OUT CLOB)
        RETURN NUMBER;
    /*
        Nombre       : f_json
        Descripción  : Procedimiento que retorna si un json de la tabla
                       [tkr_ausencias_profesional] con la información del registro
        ------------------------------------------------------------------------
        Control de modificaciones
        Fecha        Efectuadas por                     Descripción
        ----------   ------------------- ---------------------------------------
        21/07/2025   TEKER                1. Creación de la función
    */
    FUNCTION f_json (p_id IN tkr_ausencias_profesional.id%TYPE) RETURN VARCHAR2;
END pkgtkr_ausencias_profesional_dao;
/
