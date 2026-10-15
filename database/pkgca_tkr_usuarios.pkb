PACKAGE BODY pkgca_tkr_usuarios 
AS
    FUNCTION f_consulta_x_usuario (p_usuario IN tkr_usuarios.usuario%TYPE, pro_tkr_usuarios OUT tkr_usuarios%ROWTYPE)
        RETURN BOOLEAN
    AS
        v_existe   BOOLEAN := TRUE;

        CURSOR cur_tkr_usuarios IS
            SELECT *
              FROM tkr_usuarios
             WHERE UPPER (usuario) = UPPER (p_usuario);
    BEGIN
        OPEN cur_tkr_usuarios;

        FETCH cur_tkr_usuarios INTO pro_tkr_usuarios;

        IF cur_tkr_usuarios%NOTFOUND
        THEN
            v_existe := FALSE;
        END IF;

        CLOSE cur_tkr_usuarios;

        RETURN v_existe;
    END f_consulta_x_usuario;

    FUNCTION f_validar_usuario_inactivo (p_usuario IN tkr_usuarios.usuario%TYPE)
        RETURN BOOLEAN
    AS
        v_inactivo         BOOLEAN := FALSE;
        vro_tkr_usuarios   tkr_usuarios%ROWTYPE;

        CURSOR cur_tkr_usuarios IS
            SELECT *
              FROM tkr_usuarios
             WHERE UPPER (usuario) = UPPER (p_usuario) AND id_estado_usuario = 2;
    BEGIN
        OPEN cur_tkr_usuarios;

        FETCH cur_tkr_usuarios INTO vro_tkr_usuarios;

        IF cur_tkr_usuarios%FOUND
        THEN
            v_inactivo := TRUE;
        END IF;

        CLOSE cur_tkr_usuarios;

        RETURN v_inactivo;
    END f_validar_usuario_inactivo;

    FUNCTION f_consulta_x_nombres_correo (p_nombres          IN     tkr_usuarios.nombres%TYPE,
                                          p_apellidos        IN     tkr_usuarios.apellidos%TYPE,
                                          p_correo           IN     tkr_usuarios.correo_electronico%TYPE,
                                          pro_tkr_usuarios      OUT tkr_usuarios%ROWTYPE)
        RETURN BOOLEAN
    AS
        v_existe   BOOLEAN := TRUE;

        CURSOR cur_tkr_usuarios IS
            SELECT *
              FROM tkr_usuarios
             WHERE     UPPER (nombres) = UPPER (p_nombres)
                   AND UPPER (apellidos) = UPPER (p_apellidos)
                   AND UPPER (correo_electronico) = UPPER (p_correo);
    BEGIN
        OPEN cur_tkr_usuarios;

        FETCH cur_tkr_usuarios INTO pro_tkr_usuarios;

        IF cur_tkr_usuarios%NOTFOUND
        THEN
            v_existe := FALSE;
        END IF;

        CLOSE cur_tkr_usuarios;

        RETURN v_existe;
    END f_consulta_x_nombres_correo;

    PROCEDURE p_devolver_coordinadores (pta_coordinadores OUT pkgtkr_usuarios_dao.t_tkr_usuarios)
    AS
    BEGIN
        SELECT  u.*
          BULK COLLECT INTO pta_coordinadores
          FROM tkr_usuarios u
         WHERE     id_estado_usuario = 1
               AND (   (id > 0 AND id_rol = 2)
                    OR (EXISTS
                            (SELECT 1
                               FROM tkr_roles_usuario ru
                              WHERE ru.id_usuario = u.id AND ru.id_rol = 2))); 
    END p_devolver_coordinadores;

    FUNCTION f_nombre_x_id (p_id IN tkr_usuarios.id%TYPE)
        RETURN VARCHAR2
    AS
        v_nombre_completo   VARCHAR2 (100);

        CURSOR cur_nombre_completo IS
            SELECT INITCAP (nombres) || ' ' || INITCAP (apellidos)
              FROM tkr_usuarios
             WHERE id = p_id;
    BEGIN
        OPEN cur_nombre_completo;

        FETCH cur_nombre_completo INTO v_nombre_completo;

        CLOSE cur_nombre_completo;

        RETURN v_nombre_completo;
    END f_nombre_x_id;

    FUNCTION f_id_x_usuario (p_usuario IN tkr_usuarios.usuario%TYPE)
        RETURN NUMBER
    AS
        vnu_id   NUMBER;

        CURSOR cur_id IS
            SELECT id
              FROM tkr_usuarios
             WHERE LOWER (usuario) = LOWER (p_usuario);
    BEGIN
        OPEN cur_id;

        FETCH cur_id INTO vnu_id;

        CLOSE cur_id;

        RETURN vnu_id;
    END f_id_x_usuario;

    FUNCTION f_consulta_x_correo (p_correo           IN     tkr_usuarios.correo_electronico%TYPE,
                                  pro_tkr_usuarios      OUT tkr_usuarios%ROWTYPE)
        RETURN BOOLEAN
    AS
        v_existe   BOOLEAN := TRUE;

        CURSOR cur_tkr_usuarios IS
            SELECT *
              FROM tkr_usuarios
             WHERE UPPER (correo_electronico) = UPPER (p_correo);
    BEGIN
        OPEN cur_tkr_usuarios;

        FETCH cur_tkr_usuarios INTO pro_tkr_usuarios;

        IF cur_tkr_usuarios%NOTFOUND
        THEN
            v_existe := FALSE;
        END IF;

        CLOSE cur_tkr_usuarios;

        RETURN v_existe;
    END f_consulta_x_correo;

    PROCEDURE p_devolver_usuarios_no_registrados (pta_usuarios OUT pkgtkr_usuarios_dao.t_tkr_usuarios)
    IS
    BEGIN
        SELECT *
          BULK COLLECT INTO pta_usuarios
          FROM tkr_usuarios
         WHERE     id_rol = 3
               AND fecha_vencimiento_clave < f_fecha_actual
               AND SUBSTR (usuario, 1, 2) <> '--'
               AND id_estado_usuario = 2;
    END p_devolver_usuarios_no_registrados;

    FUNCTION f_cantidad_profesionales
        RETURN NUMBER
    IS
        vnu_cantidad_profesionales   NUMBER;

        CURSOR cur_profesionales IS
            SELECT COUNT (1)
              FROM tkr_usuarios
             WHERE id_estado_usuario = 1 AND id_rol = 4;
    BEGIN
        OPEN cur_profesionales;

        FETCH cur_profesionales INTO vnu_cantidad_profesionales;

        CLOSE cur_profesionales;

        RETURN vnu_cantidad_profesionales;
    END f_cantidad_profesionales;

    FUNCTION f_profesionales_activos (p_cantidad IN NUMBER DEFAULT NULL)
        RETURN SYS_REFCURSOR
    IS
        v_cursor   SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT id,
                   INITCAP (nombres) || ' ' || INITCAP (apellidos)    nombre_profesional,
                   CASE
                       WHEN f_archivo_foto (id) IS NULL
                       THEN
                           pkgca_tkr_parametros.f_consulta_valor (-7) || 'logo_circulo.png'
                       ELSE
                           pkgca_tkr_parametros.f_consulta_valor (-7) || f_archivo_foto (id)
                   END                                                url_foto
              FROM tkr_usuarios
             WHERE id_estado_usuario = 1 AND id_rol = 4 AND id > 0 AND (ROWNUM <= p_cantidad OR p_cantidad IS NULL);

        RETURN v_cursor;
    END f_profesionales_activos;

    FUNCTION f_generar_codigo
        RETURN NUMBER
    IS
        v_numero   NUMBER;

        CURSOR cur_numero IS
            SELECT FLOOR (DBMS_RANDOM.VALUE (1000, 9999))     AS numero
              FROM DUAL
             WHERE NOT EXISTS
                       (SELECT 1
                          FROM tkr_usuarios
                         WHERE clave_inicial = FLOOR (DBMS_RANDOM.VALUE (1000, 9999)));
    BEGIN
        OPEN cur_numero;

        FETCH cur_numero INTO v_numero;

        CLOSE cur_numero;

        RETURN NVL (v_numero, FLOOR (DBMS_RANDOM.VALUE (1000, 9999)));
    END f_generar_codigo;


    FUNCTION f_existe_correo (p_correo IN tkr_usuarios.correo_electronico%TYPE)
        RETURN NUMBER
    IS
        v_existe           NUMBER := 0;
        vro_tkr_usuarios   tkr_usuarios%ROWTYPE;

        CURSOR cur_tkr_usuarios IS
            SELECT *
              FROM tkr_usuarios
             WHERE UPPER (correo_electronico) = UPPER (p_correo) AND id_estado_usuario = 1;
    BEGIN
        OPEN cur_tkr_usuarios;

        FETCH cur_tkr_usuarios INTO vro_tkr_usuarios;

        IF cur_tkr_usuarios%FOUND
        THEN
            v_existe := 1;
        END IF;

        CLOSE cur_tkr_usuarios;

        RETURN v_existe;
    END f_existe_correo;

    FUNCTION f_validar_codigo (p_correo IN VARCHAR2, p_codigo IN NUMBER)
        RETURN NUMBER
    IS
        v_existe      NUMBER := 0;
        vro_usuario   tkr_usuarios%ROWTYPE;

        CURSOR cur_tkr_usuarios IS
            SELECT *
              FROM tkr_usuarios
             WHERE UPPER (correo_electronico) = UPPER (p_correo) AND clave_inicial = p_codigo;
    BEGIN
        OPEN cur_tkr_usuarios;

        FETCH cur_tkr_usuarios INTO vro_usuario;

        IF cur_tkr_usuarios%FOUND
        THEN
            v_existe := 1;

            UPDATE tkr_usuarios
               SET id_estado_usuario = 1
             WHERE id = vro_usuario.id;

            COMMIT;
        END IF;

        CLOSE cur_tkr_usuarios;

        RETURN v_existe;
    END f_validar_codigo;

    FUNCTION f_consulta_x_telefono (p_telefono IN VARCHAR2, pro_tkr_usuarios OUT tkr_usuarios%ROWTYPE)
        RETURN BOOLEAN
    IS
        v_existe   BOOLEAN := TRUE;

        CURSOR cur_tkr_usuarios IS
            SELECT *
              FROM tkr_usuarios
             WHERE TO_CHAR (telefono) = p_telefono;
    BEGIN
        OPEN cur_tkr_usuarios;

        FETCH cur_tkr_usuarios INTO pro_tkr_usuarios;

        IF cur_tkr_usuarios%NOTFOUND
        THEN
            v_existe := FALSE;
        END IF;

        CLOSE cur_tkr_usuarios;

        RETURN v_existe;
    END f_consulta_x_telefono;

    FUNCTION f_profesionales_disponibles
        RETURN SYS_REFCURSOR
    IS
        v_cursor   SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT id, fecha_disponible
              FROM tkr_usuarios
             WHERE     disponible = 'S'
                   AND id_rol = 4
                   AND (NVL (fecha_disponible, f_fecha_actual) - (10 / 1440)) <= f_fecha_actual;

        RETURN v_cursor;
    END f_profesionales_disponibles;

    FUNCTION f_existe_usuario_clave (p_correo                   IN     VARCHAR2,
                                     p_clave                    IN     VARCHAR2,
                                     p_nombres                     OUT VARCHAR2,
                                     p_apellidos                   OUT VARCHAR2,
                                     p_telefono                    OUT NUMBER,
                                     p_id_tipo_identificacion      OUT NUMBER,
                                     p_identificacion              OUT VARCHAR2,
                                     p_direccion                   OUT VARCHAR2)
        RETURN NUMBER
    IS
        v_retorno     NUMBER := 0;
        vro_usuario   tkr_usuarios%ROWTYPE;

        CURSOR cur_usuario IS
            SELECT *
              FROM tkr_usuarios
             WHERE     UPPER (correo_electronico) = UPPER (p_correo)
                   AND clave = DBMS_CRYPTO.hash (UTL_I18N.string_to_raw (LOWER (p_clave), 'AL32UTF8'), 3);
    BEGIN
        OPEN cur_usuario;

        FETCH cur_usuario INTO vro_usuario;

        IF cur_usuario%FOUND
        THEN
            v_retorno := 1;
            p_nombres := vro_usuario.nombres;
            p_apellidos := vro_usuario.apellidos;
            p_telefono := vro_usuario.telefono;
            p_id_tipo_identificacion := vro_usuario.id_tipo_identificacion;
            p_identificacion := vro_usuario.identificacion;
            p_direccion := vro_usuario.direccion;
        END IF;

        CLOSE cur_usuario;

        RETURN v_retorno;
    END f_existe_usuario_clave;

    FUNCTION f_existe_usuario_clave (p_correo IN VARCHAR2, p_clave IN VARCHAR2)
        RETURN NUMBER
    IS
        v_retorno     NUMBER := 0;
        vro_usuario   tkr_usuarios%ROWTYPE;

        CURSOR cur_usuario IS
            SELECT *
              FROM tkr_usuarios
             WHERE     UPPER (correo_electronico) = UPPER (p_correo)
                   AND clave = DBMS_CRYPTO.hash (UTL_I18N.string_to_raw (LOWER (p_clave), 'AL32UTF8'), 3);
    BEGIN
        OPEN cur_usuario;

        FETCH cur_usuario INTO vro_usuario;

        IF cur_usuario%FOUND
        THEN
            v_retorno := 1;
        END IF;

        CLOSE cur_usuario;

        RETURN v_retorno;
    END f_existe_usuario_clave;

    FUNCTION f_existe_usuario_clave (p_correo IN VARCHAR2, p_clave IN VARCHAR2, pro_usuario OUT tkr_usuarios%ROWTYPE)
        RETURN NUMBER
    IS
        v_retorno   NUMBER := 0;

        CURSOR cur_usuario IS
            SELECT *
              FROM tkr_usuarios
             WHERE     UPPER (correo_electronico) = UPPER (p_correo)
                   AND clave = DBMS_CRYPTO.hash (UTL_I18N.string_to_raw (LOWER (p_clave), 'AL32UTF8'), 3);
    BEGIN
        OPEN cur_usuario;

        FETCH cur_usuario INTO pro_usuario;

        IF cur_usuario%FOUND
        THEN
            v_retorno := 1;
        END IF;

        CLOSE cur_usuario;

        RETURN v_retorno;
    END f_existe_usuario_clave;

    FUNCTION f_maxima_fila_gsheet
        RETURN NUMBER
    IS
        vnu_maxima_fila   NUMBER;
    BEGIN
        SELECT MAX (NVL (numero_fila_gsheet, 0)) INTO vnu_maxima_fila FROM tkr_usuarios;

        RETURN vnu_maxima_fila;
    END f_maxima_fila_gsheet;

    FUNCTION f_existe_usuario_correo (p_correo                   IN     VARCHAR2,
                                      p_nombres                     OUT VARCHAR2,
                                      p_apellidos                   OUT VARCHAR2,
                                      p_telefono                    OUT NUMBER,
                                      p_id_tipo_identificacion      OUT NUMBER,
                                      p_identificacion              OUT VARCHAR2,
                                      p_direccion                   OUT VARCHAR2)
        RETURN NUMBER
    IS
        v_retorno     NUMBER := 0;
        vro_usuario   tkr_usuarios%ROWTYPE;

        CURSOR cur_usuario IS
            SELECT *
              FROM tkr_usuarios
             WHERE UPPER (correo_electronico) = UPPER (p_correo) AND id_rol = 3;
    BEGIN
        OPEN cur_usuario;

        FETCH cur_usuario INTO vro_usuario;

        IF cur_usuario%FOUND
        THEN
            v_retorno := 1;
            p_nombres := vro_usuario.nombres;
            p_apellidos := vro_usuario.apellidos;
            p_telefono := vro_usuario.telefono;
            p_id_tipo_identificacion := vro_usuario.id_tipo_identificacion;
            p_identificacion := vro_usuario.identificacion;
            p_direccion := vro_usuario.direccion;
        END IF;

        CLOSE cur_usuario;

        RETURN v_retorno;
    END f_existe_usuario_correo;

    FUNCTION f_existe_usuario_correo (p_correo IN VARCHAR2, pro_usuario OUT tkr_usuarios%ROWTYPE)
        RETURN NUMBER
    IS
        v_retorno   NUMBER := 0;

        CURSOR cur_usuario IS
            SELECT *
              FROM tkr_usuarios
             WHERE UPPER (correo_electronico) = UPPER (p_correo) AND id_rol = 3;
    BEGIN
        OPEN cur_usuario;

        FETCH cur_usuario INTO pro_usuario;

        IF cur_usuario%FOUND
        THEN
            v_retorno := 1;
        END IF;

        CLOSE cur_usuario;

        RETURN v_retorno;
    END f_existe_usuario_correo;

    PROCEDURE p_existe_usuario_correo (p_correo                    IN     VARCHAR2,
                                       p_id_tipo_identificacion       OUT NUMBER,
                                       p_tipo_identificacion          OUT VARCHAR2,
                                       p_identificacion               OUT VARCHAR2,
                                       p_nombres                      OUT VARCHAR2,
                                       p_apellidos                    OUT VARCHAR2,
                                       p_direccion                    OUT VARCHAR2,
                                       p_ciudad                       OUT VARCHAR2,
                                       p_telefono                     OUT VARCHAR2,
                                       p_existe                       OUT NUMBER,
                                       p_existe_dato_facturacion      OUT NUMBER,
                                       p_datos_facturacion            OUT VARCHAR2,
                                       p_codigo_error                 OUT NUMBER,
                                       p_mensaje_error                OUT VARCHAR2)
    AS
        vro_usuario               tkr_usuarios%ROWTYPE;
        vro_tipo_identificacion   tkr_tipos_identificacion%ROWTYPE;
        vro_ciudad                tkr_ciudades%ROWTYPE;

        CURSOR cur_usuario IS
            SELECT *
              FROM tkr_usuarios
             WHERE UPPER (correo_electronico) = UPPER (p_correo) AND id_rol = 3;
    BEGIN
        p_existe := 0;
        p_codigo_error := 0;
        p_existe_dato_facturacion := 0;

        OPEN cur_usuario;

        FETCH cur_usuario INTO vro_usuario;

        IF cur_usuario%FOUND
        THEN
            p_existe := 1;
            p_nombres := pkgln_varios.f_enmascarar_cadena (vro_usuario.nombres, 'C');
            p_apellidos := pkgln_varios.f_enmascarar_cadena (vro_usuario.apellidos, 'C');
            p_telefono := pkgln_varios.f_enmascarar_cadena (vro_usuario.telefono, 'C');
            p_identificacion := pkgln_varios.f_enmascarar_cadena (vro_usuario.identificacion, 'C');
            p_direccion := pkgln_varios.f_enmascarar_cadena (vro_usuario.direccion, 'C');

            IF pkgtkr_tipos_identificacion_dao.f_existe (vro_usuario.id_tipo_identificacion, vro_tipo_identificacion) =
               TRUE
            THEN
                p_id_tipo_identificacion := vro_usuario.id_tipo_identificacion;
                p_tipo_identificacion := pkgln_varios.f_enmascarar_cadena (vro_tipo_identificacion.descripcion, 'C');
            END IF;

            IF pkgtkr_ciudades_dao.f_existe (vro_usuario.id_ciudad_residencia, vro_ciudad) = TRUE
            THEN
                p_ciudad := pkgln_varios.f_enmascarar_cadena (vro_ciudad.nombre_ciudad, 'C');
            END IF;

            IF p_id_tipo_identificacion IN (1, 2, 3)
            THEN
                IF pkgcn_citas.f_existe_datos_facturacion (p_id_tipo_identificacion,
                                                           vro_usuario.identificacion,
                                                           p_datos_facturacion) =
                   1
                THEN
                    p_existe_dato_facturacion := 1;
                END IF;
            END IF;
        END IF;

        CLOSE cur_usuario;
    END p_existe_usuario_correo;

    FUNCTION f_existe_correo_activo (p_correo IN VARCHAR2)
        RETURN NUMBER
    IS
        v_retorno     NUMBER := 0;
        vro_usuario   tkr_usuarios%ROWTYPE;

        CURSOR cur_usuario IS
            SELECT *
              FROM tkr_usuarios
             WHERE UPPER (correo_electronico) = UPPER (p_correo) AND id_estado_usuario = 1;
    BEGIN
        OPEN cur_usuario;

        FETCH cur_usuario INTO vro_usuario;

        IF cur_usuario%FOUND
        THEN
            v_retorno := 1;
        END IF;

        CLOSE cur_usuario;

        RETURN v_retorno;
    END f_existe_correo_activo;

    PROCEDURE p_json_usuario (p_id_usuario       IN NUMBER,
                              p_json_usuario        OUT VARCHAR2)
    IS
        CURSOR cur_json_usuario IS
            SELECT json_object ('id'     VALUE id, 'img_url' VALUE img_url, 
                                'nombre' VALUE nombre_completo,
                                'correo_electronico' VALUE correo_electronico,
                                'codigo_referencia' VALUE codigo_referencia)    AS usuario_json
              FROM (SELECT INITCAP (u.nombres) || ' ' || INITCAP (u.apellidos)    AS nombre_completo,
                           u.correo_electronico,
                           CASE
                               WHEN f_archivo_foto (u.id) IS NULL
                               THEN
                                   pkgca_tkr_parametros.f_consulta_valor (-7) || 'logo_circulo.png'
                               ELSE
                                   pkgca_tkr_parametros.f_consulta_valor (-7) || f_archivo_foto (u.id)
                           END                                                    img_url,
                           id,
                           u.codigo_referencia
                      FROM tkr_usuarios u)
             WHERE id = p_id_usuario;
    BEGIN
        OPEN cur_json_usuario;
        FETCH cur_json_usuario INTO p_json_usuario;
        CLOSE cur_json_usuario;

    END p_json_usuario;

    FUNCTION f_existe_identificacion_x_rol (p_id_tipo_identificacion  IN NUMBER,
                                            p_identificacion          IN VARCHAR2,
                                            p_id_rol                  IN NUMBER,
                                            p_json_usuario               OUT CLOB)
      RETURN NUMBER
    IS
      v_existe   NUMBER := 1;  

      CURSOR cur_tkr_usuario  
      IS  
        SELECT json_object (
            'ID'                        VALUE id,
            'NOMBRES'                   VALUE nombres,
            'APELLIDOS'                 VALUE apellidos,
            'FECHA_NACIMIENTO'          VALUE fecha_nacimiento,
            'USUARIO'                   VALUE usuario,
            'ID_CIUDAD_RESIDENCIA'      VALUE id_ciudad_residencia,
            'DIRECCION'                 VALUE direccion,
            'CORREO_ELECTRONICO'        VALUE correo_electronico,
            'TELEFONO'                  VALUE telefono,
            'ID_PRESTADOR_SALUD'        VALUE id_prestador_salud,
            'ASEGURADOR_2'              VALUE asegurador_2,
            'ID_ESTADO_USUARIO'         VALUE id_estado_usuario,
            'ID_GENERO'                 VALUE id_genero,
            'ID_MEDIO'                  VALUE id_medio,
            'ID_BARRIO'                 VALUE id_barrio,
            'DISPONIBLE'                VALUE disponible,
            'ID_ROL'                    VALUE id_rol,
            'ID_TIPO_IDENTIFICACION'    VALUE id_tipo_identificacion,
            'IDENTIFICACION'            VALUE identificacion,
            'ID_PERFIL_DOCTOR'          VALUE id_perfil_doctor,
            'FECHA_DISPONIBLE'          VALUE fecha_disponible,
            'TRABAJA_FESTIVOS'          VALUE trabaja_festivos,
            'IDIOMAS'                   VALUE idiomas,
            'REGIMEN_SIMPLE'            VALUE regimen_simple,
            'ID_PAIS'                   VALUE id_pais,
            'ID_PLAN_ASEGURADOR'        VALUE id_plan_asegurador,
            'BARRIO'                    VALUE barrio,
            'ESTADO_CAPACITACION'       VALUE estado_capacitacion,
            'NO_TENER_EN_CUENTA'        VALUE no_tener_en_cuenta
        RETURNING CLOB)   
  FROM (SELECT id,
               nombres,
               apellidos,
               TO_CHAR(fecha_nacimiento,'dd/mm/yyyy') fecha_nacimiento,
               usuario,
               id_ciudad_residencia,
               direccion,
               correo_electronico,
               telefono,
               id_prestador_salud,
               asegurador_2,
               id_estado_usuario,
               id_genero,
               id_medio,
               id_barrio,
               disponible,
               id_rol,
               id_tipo_identificacion,
               identificacion,
               id_perfil_doctor,
               fecha_disponible,
               trabaja_festivos,
               idiomas,
               regimen_simple,
               id_pais,
               id_plan_asegurador,
               barrio,
               estado_capacitacion,
               '0' no_tener_en_cuenta
          FROM tkr_usuarios
         WHERE     id_tipo_identificacion = p_id_tipo_identificacion
               AND identificacion = p_identificacion
               --AND id_estado_usuario = 1
               AND id_rol = p_id_rol
               AND ROWNUM = 1);
    BEGIN  
       OPEN cur_tkr_usuario;  
       FETCH cur_tkr_usuario INTO   p_json_usuario;  
       IF cur_tkr_usuario%NOTFOUND THEN  
          v_existe := 0;  
       END IF;  
       CLOSE cur_tkr_usuario;  
--dbms_output.put_line('0.v_json: '||  p_json_usuario);          

       RETURN v_existe;  
    END f_existe_identificacion_x_rol;  

    FUNCTION f_existe_identificacion (p_id_tipo_identificacion   IN  NUMBER,
                                      p_identificacion           IN VARCHAR2,
                                      p_id_rol                   IN NUMBER,
                                      pro_usuario                   OUT tkr_usuarios%ROWTYPE)  
        RETURN NUMBER  
    IS
      v_existe   NUMBER := 1;  

      CURSOR cur_tkr_usuario  
      IS  
        SELECT  *
          FROM tkr_usuarios
         WHERE id_tipo_identificacion = p_id_tipo_identificacion
           AND identificacion = p_identificacion
           AND id_rol = p_id_rol;
    BEGIN  
       OPEN cur_tkr_usuario;  
       FETCH cur_tkr_usuario INTO   pro_usuario;  
       IF cur_tkr_usuario%NOTFOUND THEN  
          v_existe := 0;  
       END IF;  
       CLOSE cur_tkr_usuario;  

       RETURN v_existe;  
    END f_existe_identificacion;  

    FUNCTION f_consulta_x_identificacion (p_id_tipo_identificacion  IN tkr_usuarios.id_tipo_identificacion%TYPE,
                                          p_identificacion          IN tkr_usuarios.identificacion%TYPE,  
                                          pro_tkr_usuarios             OUT tkr_usuarios%ROWTYPE)  
        RETURN BOOLEAN
    IS  
        v_existe   BOOLEAN := TRUE;

        CURSOR cur_tkr_usuarios IS
            SELECT *
              FROM tkr_usuarios
             WHERE id_tipo_identificacion = p_id_tipo_identificacion
               AND identificacion = p_identificacion
               and id_estado_usuario = 1;
    BEGIN
        OPEN cur_tkr_usuarios;
        FETCH cur_tkr_usuarios INTO pro_tkr_usuarios;
        IF cur_tkr_usuarios%NOTFOUND
        THEN
            v_existe := FALSE;
        END IF;
        CLOSE cur_tkr_usuarios;

        RETURN v_existe;
    END f_consulta_x_identificacion;

    FUNCTION f_existe_codigo_referencia (p_codigo_referencia   IN VARCHAR2) RETURN NUMBER
    IS
        v_retorno       NUMBER := 0;
        vro_usuario     tkr_usuarios%ROWTYPE;

        CURSOR cur_usuario IS
            SELECT *
              FROM tkr_usuarios
             WHERE codigo_referencia = p_codigo_referencia;
    BEGIN
        OPEN cur_usuario;
        FETCH cur_usuario INTO vro_usuario;
        IF cur_usuario%FOUND
        THEN
            v_retorno := vro_usuario.id;
        END IF;
        CLOSE cur_usuario;

        RETURN v_retorno;
    END f_existe_codigo_referencia;

    FUNCTION f_existe_identificacion (p_id_tipo_identificacion   IN NUMBER,
                                      p_identificacion           IN VARCHAR2,
                                      pro_usuario                   OUT tkr_usuarios%ROWTYPE)  
        RETURN NUMBER  
    IS
      v_existe   NUMBER := 1;  

      CURSOR cur_tkr_usuario  
      IS  
        SELECT *
          FROM tkr_usuarios
         WHERE id_tipo_identificacion = p_id_tipo_identificacion
           AND identificacion = p_identificacion
           AND id_estado_usuario = 1
           AND rownum = 1;
    BEGIN  
       OPEN cur_tkr_usuario;  
       FETCH cur_tkr_usuario INTO   pro_usuario;  
       IF cur_tkr_usuario%NOTFOUND THEN  
          v_existe := 0;  
       END IF;  
       CLOSE cur_tkr_usuario;  

       RETURN v_existe;  
    END f_existe_identificacion;        

    FUNCTION f_existe_identificacion (p_id_tipo_identificacion   IN  NUMBER,
                                      p_identificacion           IN VARCHAR2)  
        RETURN NUMBER  
    IS
      v_existe      NUMBER := 1;  
      vro_usuario   tkr_usuarios%ROWTYPE;

      CURSOR cur_tkr_usuario  
      IS  
        SELECT  *
          FROM tkr_usuarios
         WHERE id_tipo_identificacion = p_id_tipo_identificacion
           AND identificacion = p_identificacion;
    BEGIN  
       OPEN cur_tkr_usuario;  
       FETCH cur_tkr_usuario INTO   vro_usuario;  
       IF cur_tkr_usuario%NOTFOUND THEN  
          v_existe := 0;  
       END IF;  
       CLOSE cur_tkr_usuario;  

       RETURN v_existe;  
    END f_existe_identificacion;  

    FUNCTION f_existe_identificacion_prof (p_id_tipo_identificacion   IN NUMBER,
                                           p_identificacion           IN VARCHAR2)  
        RETURN NUMBER
    IS
      v_existe      NUMBER := 1;  
      vro_usuario   tkr_usuarios%ROWTYPE;

      CURSOR cur_tkr_usuario  
      IS  
        SELECT  *
          FROM tkr_usuarios
         WHERE id_tipo_identificacion = p_id_tipo_identificacion
           AND identificacion = p_identificacion
           AND id_rol = 4;
    BEGIN  
       OPEN cur_tkr_usuario;  
       FETCH cur_tkr_usuario INTO   vro_usuario;  
       IF cur_tkr_usuario%NOTFOUND THEN  
          v_existe := 0;  
       END IF;  
       CLOSE cur_tkr_usuario;  

       RETURN v_existe;  
    END f_existe_identificacion_prof;  

    FUNCTION f_existe_identificacion_prof (p_id_tipo_identificacion   IN NUMBER,
                                           p_identificacion           IN VARCHAR2,
                                           pro_tkr_usuarios              OUT tkr_usuarios%ROWTYPE)  
        RETURN NUMBER
    IS
      v_existe      NUMBER := 1;  

      CURSOR cur_tkr_usuario  
      IS  
        SELECT  *
          FROM tkr_usuarios
         WHERE id_tipo_identificacion = p_id_tipo_identificacion
           AND identificacion = p_identificacion
           AND id_rol = 4;
    BEGIN  
       OPEN cur_tkr_usuario;  
       FETCH cur_tkr_usuario INTO   pro_tkr_usuarios;  
       IF cur_tkr_usuario%NOTFOUND THEN  
          v_existe := 0;  
       END IF;  
       CLOSE cur_tkr_usuario;  

       RETURN v_existe;  
    END f_existe_identificacion_prof;  
    
    FUNCTION f_existe_usuario (p_usuario  IN VARCHAR2)  
        RETURN NUMBER
    IS
      v_existe      NUMBER := 1;  
      vro_usuario   tkr_usuarios%ROWTYPE;

      CURSOR cur_tkr_usuario  
      IS  
        SELECT  *
          FROM tkr_usuarios
         WHERE usuario = p_usuario;
    BEGIN  
       OPEN cur_tkr_usuario;  
       FETCH cur_tkr_usuario INTO   vro_usuario;  
       IF cur_tkr_usuario%NOTFOUND THEN  
          v_existe := 0;  
       END IF;  
       CLOSE cur_tkr_usuario;  

       RETURN v_existe;  
    END f_existe_usuario;  

    PROCEDURE p_devolver_x_id_rol (p_id_rol        IN    NUMBER,
                                   pta_usuarios      OUT pkgtkr_usuarios_dao.t_tkr_usuarios)
    AS
    BEGIN
        SELECT *
          BULK COLLECT INTO pta_usuarios
          FROM tkr_usuarios u
         WHERE id_estado_usuario = 1 AND id > 0 AND id_rol = p_id_rol;
    END p_devolver_x_id_rol;

    FUNCTION f_existe_identificacion_usu (p_id_tipo_identificacion   IN NUMBER,
                                          p_identificacion           IN VARCHAR2,
                                          p_usuario                  IN VARCHAR2,
                                          pro_usuario                   OUT tkr_usuarios%ROWTYPE)  
        RETURN NUMBER 
    IS
        v_retorno   NUMBER := 0;

        CURSOR cur_usuario IS
            SELECT *
              FROM tkr_usuarios
             WHERE id_tipo_identificacion = p_id_tipo_identificacion
               AND identificacion = p_identificacion
               AND UPPER (usuario) = UPPER (p_usuario);
    BEGIN
        OPEN cur_usuario;

        FETCH cur_usuario INTO pro_usuario;

        IF cur_usuario%FOUND
        THEN
            v_retorno := 1;
        END IF;

        CLOSE cur_usuario;

        RETURN v_retorno;
    END f_existe_identificacion_usu;

    PROCEDURE p_devolver_x_comentarios (p_json_entrada  IN    VARCHAR2,
                                        pta_usuarios      OUT pkgtkr_usuarios_dao.t_tkr_usuarios)
    IS
    BEGIN
        SELECT * BULK COLLECT INTO pta_usuarios
          FROM tkr_usuarios
         WHERE comentarios = json_value(p_json_entrada,'$.comentarios')
           AND id_estado_usuario = 1;
    END p_devolver_x_comentarios;
    
    PROCEDURE p_actualizar_estado_capacitacion (p_id_usuario    IN NUMBER,
                                                p_estado        IN NUMBER)
    IS
    BEGIN
        UPDATE tkr_usuarios SET estado_capacitacion = p_estado
         WHERE id = p_id_usuario;
    END p_actualizar_estado_capacitacion;

    PROCEDURE p_actualizar_trabaja_festivos (
        p_id_usuario         IN NUMBER,
        p_trabaja_festivos   IN VARCHAR2
    ) IS
    BEGIN
        UPDATE tkr_usuarios
           SET trabaja_festivos = UPPER(TRIM(p_trabaja_festivos))
         WHERE id = p_id_usuario;
    END p_actualizar_trabaja_festivos;

    FUNCTION f_trabaja_festivos (
        p_id_usuario IN NUMBER
    ) RETURN VARCHAR2 IS
        v_trabaja VARCHAR2(1);
    BEGIN
        SELECT NVL(trabaja_festivos, 'N')
          INTO v_trabaja
          FROM tkr_usuarios
         WHERE id = p_id_usuario;
        RETURN v_trabaja;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 'N';
    END f_trabaja_festivos;

END pkgca_tkr_usuarios;