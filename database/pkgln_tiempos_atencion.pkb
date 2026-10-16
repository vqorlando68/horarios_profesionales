CREATE OR REPLACE PACKAGE BODY pkgln_tiempos_atencion AS
    /*
    || =========================================================================
    || Paquete: pkgln_tiempos_atencion
    || Propósito: Orquestador transaccional de dominio para la gestión de
    ||            Tiempos de Atención de profesionales.
    || Estándar: oracle-plsql-architecture
    || =========================================================================
    */

    vro_error tkr_errores%ROWTYPE;

    -- 1. Consultar tiempos de atención de un profesional
    PROCEDURE p_consultar_tiempos (
        p_json_entrada IN  CLOB,
        p_json_salida  OUT CLOB
    ) IS
        v_obj_in        JSON_OBJECT_T;
        v_id_usuario    NUMBER;
        v_codigo_error  NUMBER;
        v_mensaje_error VARCHAR2(4000);
        v_resp_obj      JSON_OBJECT_T;
    BEGIN
        IF p_json_entrada IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'El payload de entrada JSON no puede ser nulo.');
        END IF;

        v_obj_in     := JSON_OBJECT_T.parse(p_json_entrada);
        v_id_usuario := v_obj_in.get_number('id_usuario');

        IF v_id_usuario IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'El identificador del profesional (id_usuario) es obligatorio.');
        END IF;

        pkgcn_tiempos_atencion.p_consultar_tiempos_json(
            p_id_usuario  => v_id_usuario,
            p_json_salida => p_json_salida
        );

    EXCEPTION
        WHEN OTHERS THEN
            v_codigo_error  := SQLCODE;
            v_mensaje_error := SQLERRM;
            vro_error.tipo            := 'E';
            vro_error.nombre_programa := 'PKGLN_TIEMPOS_ATENCION';
            vro_error.nombre_metodo   := 'p_consultar_tiempos';
            vro_error.parametros      := DBMS_LOB.SUBSTR(p_json_entrada, 4000, 1);
            vro_error.codigo_error    := TO_CHAR(v_codigo_error);
            vro_error.texto_error     := DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
            vro_error.mensaje_error   := SUBSTR(v_mensaje_error, 1, 4000);
            uti_ge_excepciones_pkg.p_grabar_log(vro_error);

            v_resp_obj := JSON_OBJECT_T();
            v_resp_obj.put('codigo', v_codigo_error);
            v_resp_obj.put('mensaje', v_mensaje_error);
            p_json_salida := v_resp_obj.to_clob();
    END p_consultar_tiempos;

    -- 2. Guardar o actualizar tiempos de atención de un profesional (flexible: 1 o más tipos)
    PROCEDURE p_guardar_tiempos (
        p_json_entrada IN  CLOB,
        p_json_salida  OUT CLOB
    ) IS
        v_obj_in         JSON_OBJECT_T;
        v_arr_tiempos    JSON_ARRAY_T;
        v_elem           JSON_OBJECT_T;
        v_id_usuario     NUMBER;
        v_id_tipo_aseg   NUMBER;
        v_duracion       NUMBER;
        v_validos_count  NUMBER := 0;
        v_codigo_error   NUMBER;
        v_mensaje_error  VARCHAR2(4000);
        v_resp_obj       JSON_OBJECT_T;
    BEGIN
        IF p_json_entrada IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'El payload de entrada JSON no puede ser nulo.');
        END IF;

        v_obj_in     := JSON_OBJECT_T.parse(p_json_entrada);
        v_id_usuario := v_obj_in.get_number('id_usuario');

        IF v_id_usuario IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'El identificador del profesional (id_usuario) es obligatorio.');
        END IF;

        -- Validación de la estructura del arreglo de tiempos
        IF v_obj_in.has('tiempos') THEN
            v_arr_tiempos := v_obj_in.get_array('tiempos');
            FOR i IN 0 .. v_arr_tiempos.get_size - 1 LOOP
                v_elem         := JSON_OBJECT_T(v_arr_tiempos.get(i));
                v_id_tipo_aseg := v_elem.get_number('id_tipo_aseguramiento');
                
                IF v_elem.has('duracion') AND NOT v_elem.get('duracion').is_null THEN
                    v_duracion := v_elem.get_number('duracion');
                    IF v_duracion <= 0 THEN
                        RAISE_APPLICATION_ERROR(-20004, 'La duración debe ser un número entero mayor a 0 minutos.');
                    END IF;
                    v_validos_count := v_validos_count + 1;
                END IF;

                IF v_id_tipo_aseg IS NULL THEN
                    RAISE_APPLICATION_ERROR(-20003, 'id_tipo_aseguramiento es obligatorio para cada elemento.');
                END IF;
            END LOOP;

            IF v_validos_count = 0 THEN
                RAISE_APPLICATION_ERROR(-20002, 'Debe especificar al menos un tiempo de atención válido para guardar.');
            END IF;
        ELSE
            RAISE_APPLICATION_ERROR(-20002, 'Debe proporcionar la propiedad "tiempos" con el listado a configurar.');
        END IF;

        -- Orquestar persistencia (MERGE) en la capa de negocio
        pkgcn_tiempos_atencion.p_guardar_tiempos_profesional(
            p_id_usuario   => v_id_usuario,
            p_json_tiempos => p_json_entrada
        );

        COMMIT;

        v_resp_obj := JSON_OBJECT_T();
        v_resp_obj.put('codigo', 0);
        v_resp_obj.put('mensaje', 'Tiempos de atención guardados exitosamente.');
        p_json_salida := v_resp_obj.to_clob();

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            v_codigo_error  := SQLCODE;
            v_mensaje_error := SQLERRM;
            vro_error.tipo            := 'E';
            vro_error.nombre_programa := 'PKGLN_TIEMPOS_ATENCION';
            vro_error.nombre_metodo   := 'p_guardar_tiempos';
            vro_error.parametros      := DBMS_LOB.SUBSTR(p_json_entrada, 4000, 1);
            vro_error.codigo_error    := TO_CHAR(v_codigo_error);
            vro_error.texto_error     := DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
            vro_error.mensaje_error   := SUBSTR(v_mensaje_error, 1, 4000);
            uti_ge_excepciones_pkg.p_grabar_log(vro_error);

            v_resp_obj := JSON_OBJECT_T();
            v_resp_obj.put('codigo', v_codigo_error);
            v_resp_obj.put('mensaje', v_mensaje_error);
            p_json_salida := v_resp_obj.to_clob();
    END p_guardar_tiempos;

    -- 3. Eliminar la configuración de tiempo de atención para un tipo de aseguramiento
    PROCEDURE p_eliminar_tiempo (
        p_json_entrada IN  CLOB,
        p_json_salida  OUT CLOB
    ) IS
        v_obj_in        JSON_OBJECT_T;
        v_id_usuario    NUMBER;
        v_id_tipo_aseg  NUMBER;
        v_codigo_error  NUMBER;
        v_mensaje_error VARCHAR2(4000);
        v_resp_obj      JSON_OBJECT_T;
    BEGIN
        IF p_json_entrada IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'El payload de entrada JSON no puede ser nulo.');
        END IF;

        v_obj_in       := JSON_OBJECT_T.parse(p_json_entrada);
        v_id_usuario   := v_obj_in.get_number('id_usuario');
        v_id_tipo_aseg := v_obj_in.get_number('id_tipo_aseguramiento');

        IF v_id_usuario IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'El identificador del profesional (id_usuario) es obligatorio.');
        END IF;

        IF v_id_tipo_aseg IS NULL THEN
            RAISE_APPLICATION_ERROR(-20002, 'El tipo de aseguramiento (id_tipo_aseguramiento) es obligatorio.');
        END IF;

        pkgcn_tiempos_atencion.p_eliminar_tiempo_profesional(
            p_id_usuario             => v_id_usuario,
            p_id_tipo_aseguramiento => v_id_tipo_aseg
        );

        COMMIT;

        v_resp_obj := JSON_OBJECT_T();
        v_resp_obj.put('codigo', 0);
        v_resp_obj.put('mensaje', 'Tiempo de atención eliminado exitosamente.');
        p_json_salida := v_resp_obj.to_clob();

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            v_codigo_error  := SQLCODE;
            v_mensaje_error := SQLERRM;
            vro_error.tipo            := 'E';
            vro_error.nombre_programa := 'PKGLN_TIEMPOS_ATENCION';
            vro_error.nombre_metodo   := 'p_eliminar_tiempo';
            vro_error.parametros      := DBMS_LOB.SUBSTR(p_json_entrada, 4000, 1);
            vro_error.codigo_error    := TO_CHAR(v_codigo_error);
            vro_error.texto_error     := DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
            vro_error.mensaje_error   := SUBSTR(v_mensaje_error, 1, 4000);
            uti_ge_excepciones_pkg.p_grabar_log(vro_error);

            v_resp_obj := JSON_OBJECT_T();
            v_resp_obj.put('codigo', v_codigo_error);
            v_resp_obj.put('mensaje', v_mensaje_error);
            p_json_salida := v_resp_obj.to_clob();
    END p_eliminar_tiempo;

END pkgln_tiempos_atencion;
/
