PACKAGE           pkgca_tkr_usuarios
AS  
    /*  
          Nombre       : PKGCA_TKR_USUARIOS  
          Descripción  : Paquete realizar DML sobre la tabla usuarios  
                         que no sean sobre la llave primaria  
          Autor        : Orlando Arturo Valverde Quiceno  
          e-mail       : vqorlando@gmail.com  
          ----------------------------------------------------------------------  
          Control de modificaciones  
          Fecha        Efectuadas por                     Descripción  
          ----------   ---------------   ---------------------------------------  
          06/01/2022   OAVQ              1. Creación  
    */  
    /*  
          Nombre       : f_consulta_x_usuario  
          Descripción  : Procedimiento que devuelve el usuario pasando el alias.  
          ----------------------------------------------------------------------  
          Control de modificaciones  
          Fecha        Efectuadas por                     Descripción  
          ----------   ---------------   ---------------------------------------  
          06/01/2022   OAVQ              1. Creación  
    */  
    FUNCTION f_consulta_x_usuario (p_usuario          IN     tkr_usuarios.usuario%TYPE,  
                                   pro_tkr_usuarios      OUT tkr_usuarios%ROWTYPE)  
        RETURN BOOLEAN;  

    /*  
          Nombre       : f_validar_usuario_inactivo  
          Descripción  : Procedimiento que devuelve true si el usuario esta 
                        inactivo  
          ----------------------------------------------------------------------  
          Control de modificaciones  
          Fecha        Efectuadas por                     Descripción  
          ----------   ---------------   ---------------------------------------  
          06/01/2022   OAVQ              1. Creación  
    */  
    FUNCTION f_validar_usuario_inactivo (p_usuario          IN     tkr_usuarios.usuario%TYPE)  
        RETURN BOOLEAN;  

    /*  
          Nombre       : f_consulta_x_nombres_correo  
          Descripción  : Procedimiento que devuelve el usuario pasando los nombres
                         y el correo electrónico.  
          ----------------------------------------------------------------------  
          Control de modificaciones  
          Fecha        Efectuadas por                     Descripción  
          ----------   ---------------   ---------------------------------------  
          12/03/2022   OAVQ              1. Creación  
    */  
    FUNCTION f_consulta_x_nombres_correo (p_nombres          IN     tkr_usuarios.nombres%TYPE,  
                                          p_apellidos        IN     tkr_usuarios.apellidos%TYPE,
                                          p_correo           IN     tkr_usuarios.correo_electronico%TYPE,
                                          pro_tkr_usuarios      OUT tkr_usuarios%ROWTYPE)  
        RETURN BOOLEAN;  

    /*  
          Nombre       : p_devolver_coordinadores  
          Descripción  : Procedimiento que devuelve los coordinadores
                         activos.  
          ----------------------------------------------------------------------  
          Control de modificaciones  
          Fecha        Efectuadas por                     Descripción  
          ----------   ---------------   ---------------------------------------  
          03/02/2022   OAVQ              1. Creación  
    */  
    PROCEDURE p_devolver_coordinadores (pta_coordinadores     OUT pkgtkr_usuarios_dao.t_tkr_usuarios);

    /*  
          Nombre       : f_nombre_x_id  
          Descripción  : Función que devuelve el nombre pasando el id.  
          ----------------------------------------------------------------------  
          Control de modificaciones  
          Fecha        Efectuadas por                     Descripción  
          ----------   ---------------   ---------------------------------------  
          16/07/2022   OAVQ              1. Creación  
    */  
    FUNCTION f_nombre_x_id (p_id          IN     tkr_usuarios.id%TYPE)  
        RETURN VARCHAR2;  

    /*  
          Nombre       : f_id_x_usuario
          Descripción  : Función que devuelve el id pasando el usuario  
          ----------------------------------------------------------------------  
          Control de modificaciones  
          Fecha        Efectuadas por                     Descripción  
          ----------   ---------------   ---------------------------------------  
          16/07/2022   OAVQ              1. Creación  
    */  
    FUNCTION f_id_x_usuario (p_usuario          IN     tkr_usuarios.usuario%TYPE)  
        RETURN NUMBER;  

    /*  
          Nombre       : f_consulta_x_correo  
          Descripción  : Procedimiento que devuelve el usuario pasando el correo.  
          ----------------------------------------------------------------------  
          Control de modificaciones  
          Fecha        Efectuadas por                     Descripción  
          ----------   ---------------   ---------------------------------------  
          25/04/2023   OAVQ              1. Creación  
    */  
    FUNCTION f_consulta_x_correo (p_correo          IN   tkr_usuarios.correo_electronico%TYPE,  
                                   pro_tkr_usuarios      OUT tkr_usuarios%ROWTYPE)  
        RETURN BOOLEAN;  

    /*  
          Nombre       : p_devolver_usuarios_no_registrados  
          Descripción  : Procedimiento que devuelve los usuarios que se les
                         vencio la fecha de activacion.  
          ----------------------------------------------------------------------  
          Control de modificaciones  
          Fecha        Efectuadas por                     Descripción  
          ----------   ---------------   ---------------------------------------  
          01/06/2023   OAVQ              1. Creación  
    */  
    PROCEDURE p_devolver_usuarios_no_registrados(pta_usuarios   OUT pkgtkr_usuarios_dao.t_tkr_usuarios);

    /*  
          Nombre       : f_cantidad_profesionales  
          Descripción  : Función que devuelve la cantidad de profesionales
                         activos.  
          ----------------------------------------------------------------------  
          Control de modificaciones  
          Fecha        Efectuadas por                     Descripción  
          ----------   ---------------   ---------------------------------------  
          17/08/2023   OAVQ              1. Creación  
    */  
    FUNCTION f_cantidad_profesionales RETURN NUMBER;

    /*  
          Nombre       : f_profesionales_activos  
          Descripción  : Función que devuelve un refcursor con un listado de 
                         n profesionales cuando en el parametro de cantidad
                         se manda nulo devuelve todos.
          ----------------------------------------------------------------------  
          Control de modificaciones  
          Fecha        Efectuadas por                     Descripción  
          ----------   ---------------   ---------------------------------------  
          17/08/2023   OAVQ              1. Creación  
    */  
    FUNCTION f_profesionales_activos (p_cantidad IN NUMBER DEFAULT NULL) RETURN SYS_REFCURSOR;

    /*  
          Nombre       : f_generar_codigo  
          Descripción  : Función que devuelve un codigo aleatoriamente.
          ----------------------------------------------------------------------  
          Control de modificaciones  
          Fecha        Efectuadas por                     Descripción  
          ----------   ---------------   ---------------------------------------  
          17/08/2023   OAVQ              1. Creación  
    */  
    FUNCTION f_generar_codigo RETURN NUMBER;

    /*  
          Nombre       : f_existe_correo  
          Descripción  : Función que devuelve si existe el correo.  
          ----------------------------------------------------------------------  
          Control de modificaciones  
          Fecha        Efectuadas por                     Descripción  
          ----------   ---------------   ---------------------------------------  
          26/04/2023   OAVQ              1. Creación  
    */  
    FUNCTION f_existe_correo (p_correo          IN   tkr_usuarios.correo_electronico%TYPE)  
        RETURN NUMBER;  

    /*  
          Nombre       : f_validar_codigo  
          Descripción  : Función que devuelve si el codigo generado para la creacion
                         de un usuario es correcto.
          ----------------------------------------------------------------------  
          Control de modificaciones  
          Fecha        Efectuadas por                     Descripción  
          ----------   ---------------   ---------------------------------------  
          27/08/2023   OAVQ              1. Creación  
    */  
    FUNCTION f_validar_codigo(p_correo IN VARCHAR2, p_codigo IN NUMBER) RETURN NUMBER;

    /*  
          Nombre       : f_consulta_x_telefono  
          Descripción  : Procedimiento que devuelve el usuario pasando el telefono.  
          ----------------------------------------------------------------------  
          Control de modificaciones  
          Fecha        Efectuadas por                     Descripción  
          ----------   ---------------   ---------------------------------------  
          25/04/2023   OAVQ              1. Creación  
    */  
    FUNCTION f_consulta_x_telefono (p_telefono          IN   VARCHAR2,  
                                    pro_tkr_usuarios      OUT tkr_usuarios%ROWTYPE)  
        RETURN BOOLEAN;  

    /*  
          Nombre       : f_profesionales_disponibles  
          Descripción  : Procedimiento para devolver los profesionales disponibles.
          ----------------------------------------------------------------------  
          Control de modificaciones  
          Fecha        Efectuadas por                     Descripción  
          ----------   ---------------   ---------------------------------------  
          04/09/2023   OAVQ              1. Creación  
    */  
    FUNCTION f_profesionales_disponibles RETURN SYS_REFCURSOR;

    /*  
          Nombre       : f_existe_usuario_clave
          Descripción  : Funcion que devuelve si existe un usuario y la clave
                         que se pasan por parametro. Devuelve 1 si es correcta
                         y el nombre y apellidos de la persona
          ----------------------------------------------------------------------  
          Control de modificaciones  
          Fecha        Efectuadas por                     Descripción  
          ----------   ---------------   ---------------------------------------  
          04/09/2023   OAVQ              1. Creación  
    */  
    FUNCTION f_existe_usuario_clave (p_correo       IN VARCHAR2, 
                                     p_clave        IN VARCHAR2,
                                     p_nombres                  OUT VARCHAR2,
                                     p_apellidos                OUT VARCHAR2,
                                     p_telefono                 OUT NUMBER,
                                     p_id_tipo_identificacion   OUT NUMBER,
                                     p_identificacion           OUT VARCHAR2,
                                     p_direccion                OUT VARCHAR2)
        RETURN NUMBER;

    /*  
          Nombre       : f_existe_usuario_clave
          Descripción  : Funcion que devuelve si existe un usuario y la clave
                         que se pasan por parametro. Devuelve 1 si es correcta
                         y el nombre y apellidos de la persona
          ----------------------------------------------------------------------  
          Control de modificaciones  
          Fecha        Efectuadas por                     Descripción  
          ----------   ---------------   ---------------------------------------  
          04/09/2023   OAVQ              1. Creación  
    */  
    FUNCTION f_existe_usuario_clave (p_correo       IN VARCHAR2, 
                                     p_clave        IN VARCHAR2)
        RETURN NUMBER;

    /*  
          Nombre       : f_existe_usuario_clave
          Descripción  : Funcion que devuelve si existe un usuario y la clave
                         que se pasan por parametro. Devuelve 1 si es correcta
                         y el nombre y apellidos de la persona
          ----------------------------------------------------------------------  
          Control de modificaciones  
          Fecha        Efectuadas por                     Descripción  
          ----------   ---------------   ---------------------------------------  
          04/09/2023   OAVQ              1. Creación  
    */  
    FUNCTION f_existe_usuario_clave (p_correo       IN VARCHAR2, 
                                     p_clave        IN VARCHAR2,
                                     pro_usuario       OUT tkr_usuarios%ROWTYPE)
        RETURN NUMBER;

    /*
          Nombre       : f_maxima_fila_gsheet
          Descripción  : Función devuelve la maxima fila usuada en google sheet
                         de consultas.
          ----------------------------------------------------------------------
          Control de modificaciones
          Fecha        Efectuadas por                     Descripción
          ----------   ---------------   ---------------------------------------
          02/10/2023   OAVQ              1. Creación
    */
    FUNCTION f_maxima_fila_gsheet
        RETURN NUMBER;

    /*  
          Nombre       : f_existe_usuario_correo
          Descripción  : Funcion que devuelve si existe un usuario pasando correo
                         que se pasan por parametro. Devuelve 1 si es correcta
                         y el nombre y apellidos de la persona
          ----------------------------------------------------------------------  
          Control de modificaciones  
          Fecha        Efectuadas por                     Descripción  
          ----------   ---------------   ---------------------------------------  
          04/09/2023   OAVQ              1. Creación  
    */  
    FUNCTION f_existe_usuario_correo (p_correo       IN VARCHAR2, 
                                      p_nombres                  OUT VARCHAR2,
                                      p_apellidos                OUT VARCHAR2,
                                      p_telefono                 OUT NUMBER,
                                      p_id_tipo_identificacion   OUT NUMBER,
                                      p_identificacion           OUT VARCHAR2,
                                      p_direccion                OUT VARCHAR2)
        RETURN NUMBER;

    /*  
          Nombre       : f_existe_usuario_correo
          Descripción  : Funcion que devuelve si existe un usuario pasando correo
                         que se pasan por parametro. Devuelve 1 si es correcta
                         y el nombre y apellidos de la persona
          ----------------------------------------------------------------------  
          Control de modificaciones  
          Fecha        Efectuadas por                     Descripción  
          ----------   ---------------   ---------------------------------------  
          04/09/2023   OAVQ              1. Creación  
    */  
    FUNCTION f_existe_usuario_correo (p_correo       IN VARCHAR2, 
                                      pro_usuario       OUT tkr_usuarios%ROWTYPE)
        RETURN NUMBER;

    /*  
          Nombre       : p_existe_usuario_correo
          Descripción  : Procedimiento que devuelve si existe un usuario pasando correo
                         que se pasan por parametro. Devuelve 1 si es correcta
                         y el nombre y apellidos de la persona
          ----------------------------------------------------------------------  
          Control de modificaciones  
          Fecha        Efectuadas por                     Descripción  
          ----------   ---------------   ---------------------------------------  
          10/10/2023   OAVQ              1. Creación  
    */  
    PROCEDURE p_existe_usuario_correo (p_correo       IN VARCHAR2,
                                       p_id_tipo_identificacion   OUT NUMBER,
                                       p_tipo_identificacion      OUT VARCHAR2,
                                       p_identificacion           OUT VARCHAR2,
                                       p_nombres                  OUT VARCHAR2,
                                       p_apellidos                OUT VARCHAR2,
                                       p_direccion                OUT VARCHAR2,
                                       p_ciudad                   OUT VARCHAR2,
                                       p_telefono                 OUT VARCHAR2,
                                       p_existe                   OUT NUMBER,
                                       p_existe_dato_facturacion  OUT NUMBER,
                                       p_datos_facturacion        OUT VARCHAR2,
                                       p_codigo_error             OUT NUMBER,
                                       p_mensaje_error            OUT VARCHAR2);

    /*  
          Nombre       : f_existe_usuario_correo
          Descripción  : Funcion que devuelve si existe un usuario pasando correo
                         que se pasan por parametro. Devuelve 1 si es correcta en
                         estado activo
          ----------------------------------------------------------------------  
          Control de modificaciones  
          Fecha        Efectuadas por                     Descripción  
          ----------   ---------------   ---------------------------------------  
          13/01/2024   OAVQ              1. Creación  
    */  
    FUNCTION f_existe_correo_activo (p_correo       IN VARCHAR2) RETURN NUMBER;

    /*  
          Nombre       : p_json_usuario
          Descripción  : Procedimiento que devuelve un json con los datos basicos de
                         un usuario.
          ----------------------------------------------------------------------  
          Control de modificaciones  
          Fecha        Efectuadas por                     Descripción  
          ----------   ---------------   ---------------------------------------  
          15/01/2024   OAVQ              1. Creación  
    */  
    PROCEDURE p_json_usuario (p_id_usuario       IN NUMBER,
                              p_json_usuario        OUT VARCHAR2);

    /*  
          Nombre       : f_existe_identificacion_x_rol
          Descripción  : Funcion que devuelve si existe un usuario pasando tipo
                         y numero de identificacion. Devuelve 1 si es correcta en
                         estado activo
          ----------------------------------------------------------------------  
          Control de modificaciones  
          Fecha        Efectuadas por                     Descripción  
          ----------   ---------------   ---------------------------------------  
          13/01/2024   OAVQ              1. Creación  
    */  
    FUNCTION f_existe_identificacion_x_rol (p_id_tipo_identificacion  IN NUMBER,
                                            p_identificacion          IN VARCHAR2,
                                            p_id_rol                  IN NUMBER,
                                            p_json_usuario               OUT CLOB)
      RETURN NUMBER;

    /*  
          Nombre       : f_existe_identificacion  
          Descripción  : Función que devuelve si existe el registro de usuario
                         consultando por tipo y numero de identificacion
          ----------------------------------------------------------------------  
          Control de modificaciones  
          Fecha        Efectuadas por                     Descripción  
          ----------   ---------------   ---------------------------------------  
          26/04/2023   OAVQ              1. Creación  
    */  
    FUNCTION f_existe_identificacion (p_id_tipo_identificacion   IN NUMBER,
                                      p_identificacion           IN VARCHAR2,
                                      p_id_rol                   IN NUMBER,
                                      pro_usuario                   OUT tkr_usuarios%ROWTYPE)  
        RETURN NUMBER;  

    /*  
          Nombre       : f_consulta_x_identificacion  
          Descripción  : Procedimiento que devuelve el usuario pasando el tipo y
                         numero de identificacion.  
          ----------------------------------------------------------------------  
          Control de modificaciones  
          Fecha        Efectuadas por                     Descripción  
          ----------   ---------------   ---------------------------------------  
          05/03/2024   OAVQ              1. Creación  
    */  
    FUNCTION f_consulta_x_identificacion (p_id_tipo_identificacion  IN tkr_usuarios.id_tipo_identificacion%TYPE,
                                          p_identificacion          IN tkr_usuarios.identificacion%TYPE,  
                                          pro_tkr_usuarios             OUT tkr_usuarios%ROWTYPE)  
        RETURN BOOLEAN;  

    /*  
          Nombre       : f_existe_codigo_referencia
          Descripción  : Funcion que devuelve si existe un un codigo de 
                         referencia devolviendo el id del usuario que lo tiene.
          ----------------------------------------------------------------------  
          Control de modificaciones  
          Fecha        Efectuadas por                     Descripción  
          ----------   ---------------   ---------------------------------------  
          11/03/2024   OAVQ              1. Creación  
    */  
    FUNCTION f_existe_codigo_referencia (p_codigo_referencia   IN VARCHAR2) RETURN NUMBER;

    /*  
          Nombre       : f_existe_identificacion  
          Descripción  : Función que devuelve si existe el registro de usuario
                         consultando por tipo y numero de identificacion
          ----------------------------------------------------------------------  
          Control de modificaciones  
          Fecha        Efectuadas por                     Descripción  
          ----------   ---------------   ---------------------------------------  
          17/04/2023   OAVQ              1. Creación  
    */  
    FUNCTION f_existe_identificacion (p_id_tipo_identificacion   IN NUMBER,
                                      p_identificacion           IN VARCHAR2,
                                      pro_usuario                   OUT tkr_usuarios%ROWTYPE)  
        RETURN NUMBER;  

    /*  
          Nombre       : f_existe_identificacion  
          Descripción  : Función que devuelve si existe el registro de usuario
                         consultando por tipo y numero de identificacion
          ----------------------------------------------------------------------  
          Control de modificaciones  
          Fecha        Efectuadas por                     Descripción  
          ----------   ---------------   ---------------------------------------  
          26/04/2023   OAVQ              1. Creación  
    */  
    FUNCTION f_existe_identificacion (p_id_tipo_identificacion   IN NUMBER,
                                      p_identificacion           IN VARCHAR2)  
        RETURN NUMBER;  

    /*  
          Nombre       : f_existe_identificacion_prof 
          Descripción  : Función que devuelve si existe el registro de usuario
                         consultando por tipo y numero de identificacion para 
                         un profesional
          ----------------------------------------------------------------------  
          Control de modificaciones  
          Fecha        Efectuadas por                     Descripción  
          ----------   ---------------   ---------------------------------------  
          17/10/2024   OAVQ              1. Creación  
    */  
    FUNCTION f_existe_identificacion_prof (p_id_tipo_identificacion   IN NUMBER,
                                           p_identificacion           IN VARCHAR2)  
        RETURN NUMBER;  

    /*  
          Nombre       : f_existe_identificacion_prof 
          Descripción  : Función que devuelve si existe el registro de usuario
                         consultando por tipo y numero de identificacion para 
                         un profesional
          ----------------------------------------------------------------------  
          Control de modificaciones  
          Fecha        Efectuadas por                     Descripción  
          ----------   ---------------   ---------------------------------------  
          17/10/2024   OAVQ              1. Creación  
    */  
    FUNCTION f_existe_identificacion_prof (p_id_tipo_identificacion   IN NUMBER,
                                           p_identificacion           IN VARCHAR2,
                                           pro_tkr_usuarios              OUT tkr_usuarios%ROWTYPE)  
        RETURN NUMBER;  

    /*  
          Nombre       : f_existe_usuario 
          Descripción  : Función que devuelve si existe el registro de usuario
                         consultando por usuario
          ----------------------------------------------------------------------  
          Control de modificaciones  
          Fecha        Efectuadas por                     Descripción  
          ----------   ---------------   ---------------------------------------  
          17/10/2024   OAVQ              1. Creación  
    */  
    FUNCTION f_existe_usuario (p_usuario  IN VARCHAR2)  
        RETURN NUMBER;  

    /*  
          Nombre       : p_devolver_x_id_rol 
          Descripción  : Procedimiento que devuelve los usuarios por id_rol. 
          ----------------------------------------------------------------------  
          Control de modificaciones  
          Fecha        Efectuadas por                     Descripción  
          ----------   ---------------   ---------------------------------------  
          08/10/2025   OAVQ              1. Creación  
    */  
    PROCEDURE p_devolver_x_id_rol (p_id_rol        IN    NUMBER,
                                   pta_usuarios      OUT pkgtkr_usuarios_dao.t_tkr_usuarios);

    /*  
          Nombre       : f_existe_identificacion_usu 
          Descripción  : Función que devuelve si existe el registro de usuario
                         consultando por tipo y numero de identificacion
          ----------------------------------------------------------------------  
          Control de modificaciones  
          Fecha        Efectuadas por                     Descripción  
          ----------   ---------------   ---------------------------------------  
          17/04/2023   OAVQ              1. Creación  
    */  
    FUNCTION f_existe_identificacion_usu (p_id_tipo_identificacion   IN NUMBER,
                                          p_identificacion           IN VARCHAR2,
                                          p_usuario                  IN VARCHAR2,
                                          pro_usuario                   OUT tkr_usuarios%ROWTYPE)  
        RETURN NUMBER; 

    /*  
          Nombre       : p_devolver_x_comentarios
          Descripción  : Procedimiento que devuelve los usuarios por comentarios 
          ----------------------------------------------------------------------  
          Control de modificaciones  
          Fecha        Efectuadas por                     Descripción  
          ----------   ---------------   ---------------------------------------  
          03/07/2026   OAVQ              1. Creación  
    */  
    PROCEDURE p_devolver_x_comentarios (p_json_entrada  IN    VARCHAR2,
                                        pta_usuarios      OUT pkgtkr_usuarios_dao.t_tkr_usuarios);

    /*  
          Nombre       : p_actualizar_estado_capacitacion
          Descripción  : Procedimiento para actualizar el estado de la capacitacion
                         de un profesional
          ----------------------------------------------------------------------  
          Control de modificaciones  
          Fecha        Efectuadas por                     Descripción  
          ----------   ---------------   ---------------------------------------  
          15/07/2026   OAVQ              1. Creación  
    */  
    PROCEDURE p_actualizar_estado_capacitacion (p_id_usuario    IN NUMBER,
                                                p_estado        IN NUMBER);

    PROCEDURE p_actualizar_trabaja_festivos (
        p_id_usuario         IN NUMBER,
        p_trabaja_festivos   IN VARCHAR2
    );

    FUNCTION f_trabaja_festivos (
        p_id_usuario IN NUMBER
    ) RETURN VARCHAR2;

END pkgca_tkr_usuarios;