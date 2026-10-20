CREATE OR REPLACE PACKAGE BODY pkgln_franjas AS
    /*
    || =========================================================================
    || Paquete: pkgln_franjas (BODY)
    || Propósito: Implementación del orquestador transaccional de Franjas de Atención.
    || Estándar: oracle-plsql-architecture
    || =========================================================================
    */

    vro_error tkr_errores%ROWTYPE;

    PROCEDURE p_do_commit (
        p_origen IN VARCHAR2
    ) IS
    BEGIN
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            vro_error.tipo            := 'E';
            vro_error.nombre_programa := 'PKGLN_FRANJAS';
            vro_error.nombre_metodo   := 'p_do_commit (' || p_origen || ')';
            vro_error.parametros      := NULL;
            vro_error.codigo_error    := TO_CHAR(SQLCODE);
            vro_error.texto_error     := DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
            vro_error.mensaje_error   := SUBSTR(SQLERRM, 1, 4000);
            uti_ge_excepciones_pkg.p_grabar_log(vro_error);
            RAISE_APPLICATION_ERROR(-20000, 'Error al confirmar la transacción de franjas: ' || SQLERRM);
    END p_do_commit;

    FUNCTION f_nombre_dia_semana (
        p_dia_semana IN VARCHAR2
    ) RETURN VARCHAR2 IS
    BEGIN
        CASE UPPER(TRIM(p_dia_semana))
            WHEN 'LU' THEN RETURN 'Lunes';
            WHEN 'MA' THEN RETURN 'Martes';
            WHEN 'MI' THEN RETURN 'Miércoles';
            WHEN 'JU' THEN RETURN 'Jueves';
            WHEN 'VI' THEN RETURN 'Viernes';
            WHEN 'SA' THEN RETURN 'Sábado';
            WHEN 'DO' THEN RETURN 'Domingo';
            ELSE RETURN NVL(p_dia_semana, '');
        END CASE;
    END f_nombre_dia_semana;

    FUNCTION f_parsear_fecha (
        p_fecha_str IN VARCHAR2
    ) RETURN DATE IS
    BEGIN
        IF p_fecha_str IS NULL OR p_fecha_str = 'null' OR p_fecha_str = 'undefined' OR TRIM(p_fecha_str) = '' THEN
            RETURN NULL;
        END IF;
        RETURN TO_DATE(TRIM(p_fecha_str), 'YYYY-MM-DD');
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20005, 'Formato de fecha inválido (' || p_fecha_str || '). Se espera YYYY-MM-DD.');
    END f_parsear_fecha;

    -- 1. Consultar franjas de un profesional
    PROCEDURE p_consultar_franjas (
        p_json_entrada IN  CLOB,
        p_json_salida  OUT CLOB
    ) IS
        v_obj_in     JSON_OBJECT_T;
        v_id_usuario NUMBER(12);
    BEGIN
        IF p_json_entrada IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'El payload JSON de entrada no puede ser nulo.');
        END IF;

        v_obj_in     := JSON_OBJECT_T.parse(p_json_entrada);
        v_id_usuario := v_obj_in.get_number('id_usuario');

        IF v_id_usuario IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'El identificador del profesional (id_usuario) es obligatorio.');
        END IF;

        pkgcn_franjas.p_consultar_franjas_json(
            p_id_usuario  => v_id_usuario,
            p_json_salida => p_json_salida
        );

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            IF SQLCODE BETWEEN -20999 AND -20001 THEN
                RAISE;
            END IF;

            vro_error.tipo            := 'E';
            vro_error.nombre_programa := 'PKGLN_FRANJAS';
            vro_error.nombre_metodo   := 'p_consultar_franjas';
            vro_error.parametros      := p_json_entrada;
            vro_error.codigo_error    := TO_CHAR(SQLCODE);
            vro_error.texto_error     := DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
            vro_error.mensaje_error   := SUBSTR(SQLERRM, 1, 4000);
            uti_ge_excepciones_pkg.p_grabar_log(vro_error);

            RAISE_APPLICATION_ERROR(
                -20000,
                'Error al consultar franjas del profesional: ' || SQLERRM
            );
    END p_consultar_franjas;

    -- 2. Guardar franjas (reemplazo completo o por vigencia)
    PROCEDURE p_guardar_franjas (
        p_json_entrada IN  CLOB,
        p_json_salida  OUT CLOB
    ) IS
        v_obj_in                JSON_OBJECT_T;
        v_arr_franjas           JSON_ARRAY_T;
        v_elem_franja           JSON_OBJECT_T;
        v_id_usuario            NUMBER(12);
        v_reemplazar_todo       NUMBER(1) := 1;
        v_reemplazar_vigencia   NUMBER(1) := 0;
        v_fecha_ini_orig_str    VARCHAR2(30);
        v_fecha_fin_orig_str    VARCHAR2(30);
        v_fecha_ini_orig        DATE;
        v_fecha_fin_orig        DATE;
        v_tiene_orig            BOOLEAN := FALSE;
        v_dia_semana            VARCHAR2(10);
        v_hora_desde            VARCHAR2(10);
        v_hora_hasta            VARCHAR2(10);
        v_tipo_atencion         VARCHAR2(10);
        v_modalidad             VARCHAR2(10);
        v_fecha_inicial_str     VARCHAR2(30);
        v_fecha_final_str       VARCHAR2(30);
        v_fecha_inicial         DATE;
        v_fecha_final           DATE;
        v_fecha_ini_lote        DATE;
        v_fecha_fin_lote        DATE;
        v_resp_obj              JSON_OBJECT_T;
    BEGIN
        IF p_json_entrada IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'El payload de entrada JSON no puede ser nulo.');
        END IF;

        v_obj_in          := JSON_OBJECT_T.parse(p_json_entrada);
        v_id_usuario      := v_obj_in.get_number('id_usuario');
        v_reemplazar_todo := NVL(v_obj_in.get_number('reemplazar_todo'), 1);

        IF v_obj_in.has('reemplazar_vigencia') THEN
            v_reemplazar_vigencia := v_obj_in.get_number('reemplazar_vigencia');
        END IF;

        IF v_obj_in.has('fecha_inicial_origen') THEN
            v_fecha_ini_orig_str := TRIM(v_obj_in.get_string('fecha_inicial_origen'));
        END IF;
        IF v_obj_in.has('fecha_final_origen') THEN
            v_fecha_fin_orig_str := TRIM(v_obj_in.get_string('fecha_final_origen'));
        END IF;

        IF v_fecha_ini_orig_str IS NOT NULL AND v_fecha_ini_orig_str <> 'null' AND v_fecha_ini_orig_str <> 'undefined' THEN
            v_fecha_ini_orig := f_parsear_fecha(v_fecha_ini_orig_str);
            v_tiene_orig     := TRUE;

            IF v_fecha_fin_orig_str IS NOT NULL AND v_fecha_fin_orig_str <> 'null' AND v_fecha_fin_orig_str <> 'undefined' THEN
                v_fecha_fin_orig := f_parsear_fecha(v_fecha_fin_orig_str);
            ELSE
                v_fecha_fin_orig := NULL;
            END IF;
        END IF;

        IF v_id_usuario IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'El identificador del profesional (id_usuario) es obligatorio.');
        END IF;

        -- Fase 1: Validación en memoria de la estructura del arreglo de franjas
        IF v_obj_in.has('franjas') THEN
            v_arr_franjas := v_obj_in.get_array('franjas');
            FOR i IN 0 .. v_arr_franjas.get_size - 1 LOOP
                v_elem_franja       := JSON_OBJECT_T(v_arr_franjas.get(i));
                v_dia_semana        := UPPER(TRIM(v_elem_franja.get_string('dia_semana')));
                v_hora_desde        := TRIM(v_elem_franja.get_string('hora_desde'));
                v_hora_hasta        := TRIM(v_elem_franja.get_string('hora_hasta'));
                v_fecha_inicial_str := TRIM(v_elem_franja.get_string('fecha_inicial'));
                v_fecha_final_str   := TRIM(v_elem_franja.get_string('fecha_final'));

                IF v_elem_franja.has('id_tipo_aseguramiento') THEN
                    IF v_elem_franja.get_number('id_tipo_aseguramiento') NOT IN (1, 2) THEN
                        RAISE_APPLICATION_ERROR(-20012, 'Tipo de aseguramiento inválido. Debe ser 1 (Voluntario) o 2 (Obligatorio).');
                    END IF;
                ELSIF v_elem_franja.has('tipo_atencion') THEN
                    v_tipo_atencion := UPPER(TRIM(v_elem_franja.get_string('tipo_atencion')));
                    IF v_tipo_atencion NOT IN ('V', 'O') THEN
                        RAISE_APPLICATION_ERROR(-20012, 'Tipo de atención/aseguramiento inválido (' || v_tipo_atencion || '). Debe ser 1/V (Voluntario) o 2/O (Obligatorio).');
                    END IF;
                END IF;

                IF v_elem_franja.has('modalidad') AND NOT v_elem_franja.get('modalidad').is_null THEN
                    v_modalidad := UPPER(TRIM(v_elem_franja.get_string('modalidad')));
                    IF v_modalidad IS NOT NULL AND v_modalidad <> '' AND v_modalidad NOT IN ('V', 'D') THEN
                        RAISE_APPLICATION_ERROR(-20013, 'Modalidad de atención inválida (' || v_modalidad || '). Debe ser V (Virtual), D (Domiciliaria) o vacía/NULL (Aplica para ambas).');
                    END IF;
                END IF;

                IF v_dia_semana NOT IN ('LU', 'MA', 'MI', 'JU', 'VI', 'SA', 'DO') THEN
                    RAISE_APPLICATION_ERROR(-20002, 'Día de la semana inválido (' || v_dia_semana || '). Debe ser LU, MA, MI, JU, VI, SA o DO.');
                END IF;

                IF v_hora_desde >= v_hora_hasta THEN
                    RAISE_APPLICATION_ERROR(-20003, 'La hora inicial (' || v_hora_desde || ') debe ser menor que la hora final (' || v_hora_hasta || ').');
                END IF;

                -- Validación de día domingo y flag trabaja_festivos
                IF v_dia_semana = 'DO' THEN
                    IF pkgca_tkr_usuarios.f_trabaja_festivos(v_id_usuario) = 'N' THEN
                        RAISE_APPLICATION_ERROR(-20010, 'No es posible registrar turnos para el día Domingo porque el profesional está configurado con no trabaja festivos.');
                    END IF;
                END IF;

                IF v_fecha_inicial_str IS NULL THEN
                    RAISE_APPLICATION_ERROR(-20004, 'La fecha inicial es obligatoria para cada franja configurada (formato YYYY-MM-DD).');
                END IF;

                v_fecha_inicial := f_parsear_fecha(v_fecha_inicial_str);

                IF i = 0 THEN
                    v_fecha_ini_lote := v_fecha_inicial;
                END IF;

                IF v_fecha_final_str IS NOT NULL THEN
                    v_fecha_final := f_parsear_fecha(v_fecha_final_str);
                    IF v_fecha_final < v_fecha_inicial THEN
                        RAISE_APPLICATION_ERROR(-20007, 'La fecha final (' || v_fecha_final_str || ') no puede ser menor a la fecha inicial (' || v_fecha_inicial_str || ').');
                    END IF;
                ELSE
                    v_fecha_final := NULL;
                END IF;

                IF i = 0 THEN
                    v_fecha_fin_lote := v_fecha_final;
                END IF;

                -- Validación interna de no solapamiento con las demás franjas del payload para el mismo día
                FOR j IN (i + 1) .. v_arr_franjas.get_size - 1 LOOP
                    DECLARE
                        v_comp_elem     JSON_OBJECT_T := JSON_OBJECT_T(v_arr_franjas.get(j));
                        v_comp_dia      VARCHAR2(10)  := UPPER(TRIM(v_comp_elem.get_string('dia_semana')));
                        v_comp_desde    VARCHAR2(10)  := TRIM(v_comp_elem.get_string('hora_desde'));
                        v_comp_hasta    VARCHAR2(10)  := TRIM(v_comp_elem.get_string('hora_hasta'));
                        v_comp_ini_str  VARCHAR2(30)  := TRIM(v_comp_elem.get_string('fecha_inicial'));
                        v_comp_fin_str  VARCHAR2(30)  := TRIM(v_comp_elem.get_string('fecha_final'));
                        v_comp_ini      DATE;
                        v_comp_fin      DATE;
                        v_fin_eff_1     DATE;
                        v_fin_eff_2     DATE;
                    BEGIN
                        IF v_dia_semana = v_comp_dia THEN
                            v_comp_ini  := f_parsear_fecha(v_comp_ini_str);
                            v_comp_fin  := f_parsear_fecha(v_comp_fin_str);
                            v_fin_eff_1 := NVL(v_fecha_final, TO_DATE('9999-12-31', 'YYYY-MM-DD'));
                            v_fin_eff_2 := NVL(v_comp_fin, TO_DATE('9999-12-31', 'YYYY-MM-DD'));

                            IF (v_fecha_inicial <= v_fin_eff_2 AND v_fin_eff_1 >= v_comp_ini)
                               AND (v_hora_desde < v_comp_hasta AND v_hora_hasta > v_comp_desde) THEN
                                RAISE_APPLICATION_ERROR(
                                    -20008,
                                    'Existe cruce de franjas para el día '
                                    || f_nombre_dia_semana(v_dia_semana)
                                    || ': el turno de ' || v_hora_desde || ' a ' || v_hora_hasta
                                    || ' se traslapa con el turno de ' || v_comp_desde || ' a ' || v_comp_hasta
                                    || '. Ajuste las horas para que cada franja tenga un único tipo de atención.'
                                );
                            END IF;
                        END IF;
                    END;
                END LOOP;
            END LOOP;
        END IF;

        -- Fase 2: Borrado previo controlado
        IF v_reemplazar_todo = 1 THEN
            pkgca_tkr_franjas_profesional.p_borrar_x_profesional(
                p_id_usuario => v_id_usuario
            );
        ELSIF v_tiene_orig THEN
            pkgca_tkr_franjas_profesional.p_borrar_x_rango_fechas(
                p_id_usuario    => v_id_usuario,
                p_fecha_inicial => v_fecha_ini_orig,
                p_fecha_final   => v_fecha_fin_orig
            );
        ELSIF v_reemplazar_vigencia = 1 AND v_fecha_ini_lote IS NOT NULL THEN
            pkgca_tkr_franjas_profesional.p_borrar_x_rango_fechas(
                p_id_usuario    => v_id_usuario,
                p_fecha_inicial => v_fecha_ini_lote,
                p_fecha_final   => v_fecha_fin_lote
            );
        END IF;

        -- Fase 3: Validación contra base de datos (exclusiva entre franjas, sin tocar horarios)
        -- 3.1 Unicidad de Franja Base: Solo una franja sin fecha final por profesional
        IF v_reemplazar_todo = 0 AND v_fecha_fin_lote IS NULL THEN
            IF pkgca_tkr_franjas_profesional.f_existe_franja_base(v_id_usuario) = 1 THEN
                RAISE_APPLICATION_ERROR(
                    -20011,
                    'El profesional ya cuenta con una Franja Base registrada (sin fecha final). Solo se permite una única Franja Base por profesional; debe modificar la existente o asignarle fecha final para registrarla como Franja Personalizada.'
                );
            END IF;
        END IF;

        -- 3.2 Validación de no traslape en BD solo para franjas personalizadas (con fecha_final)
        IF v_reemplazar_todo = 0 AND v_fecha_fin_lote IS NOT NULL AND v_arr_franjas IS NOT NULL THEN
            FOR i IN 0 .. v_arr_franjas.get_size - 1 LOOP
                v_elem_franja       := JSON_OBJECT_T(v_arr_franjas.get(i));
                v_dia_semana        := UPPER(TRIM(v_elem_franja.get_string('dia_semana')));
                v_hora_desde        := TRIM(v_elem_franja.get_string('hora_desde'));
                v_hora_hasta        := TRIM(v_elem_franja.get_string('hora_hasta'));
                v_fecha_inicial_str := TRIM(v_elem_franja.get_string('fecha_inicial'));
                v_fecha_final_str   := TRIM(v_elem_franja.get_string('fecha_final'));
                v_fecha_inicial     := f_parsear_fecha(v_fecha_inicial_str);
                v_fecha_final       := f_parsear_fecha(v_fecha_final_str);

                IF pkgcn_franjas.f_existe_traslape_franja(
                       p_id_usuario    => v_id_usuario,
                       p_dia_semana    => v_dia_semana,
                       p_hora_desde    => v_hora_desde,
                       p_hora_hasta    => v_hora_hasta,
                       p_fecha_inicial => v_fecha_inicial,
                       p_fecha_final   => v_fecha_final
                   ) THEN
                    RAISE_APPLICATION_ERROR(
                        -20009,
                        'La franja para el día ' || f_nombre_dia_semana(v_dia_semana)
                        || ' (' || v_hora_desde || ' a ' || v_hora_hasta
                        || ') se cruza con otra franja previamente registrada en la base de datos para ese rango de fechas.'
                    );
                END IF;
            END LOOP;
        END IF;

        -- Fase 4: Inserción de las nuevas franjas
        IF v_arr_franjas IS NOT NULL AND v_arr_franjas.get_size > 0 THEN
            pkgcn_franjas.p_guardar_franjas_profesional(
                p_id_usuario   => v_id_usuario,
                p_json_franjas => p_json_entrada
            );
        END IF;

        -- Fase 5: Commit atómico
        p_do_commit('PKGLN_FRANJAS.p_guardar_franjas');

        v_resp_obj := JSON_OBJECT_T();
        v_resp_obj.put('codigo', 0);
        v_resp_obj.put('mensaje', 'Franjas de atención guardadas exitosamente');
        p_json_salida := v_resp_obj.to_clob;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            IF SQLCODE BETWEEN -20999 AND -20001 THEN
                RAISE;
            END IF;

            vro_error.tipo            := 'E';
            vro_error.nombre_programa := 'PKGLN_FRANJAS';
            vro_error.nombre_metodo   := 'p_guardar_franjas';
            vro_error.parametros      := p_json_entrada;
            vro_error.codigo_error    := TO_CHAR(SQLCODE);
            vro_error.texto_error     := DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
            vro_error.mensaje_error   := SUBSTR(SQLERRM, 1, 4000);
            uti_ge_excepciones_pkg.p_grabar_log(vro_error);

            RAISE_APPLICATION_ERROR(
                -20000,
                'Error al guardar franjas: ' || SQLERRM
            );
    END p_guardar_franjas;

    -- 3. Eliminar franjas de una vigencia específica
    PROCEDURE p_eliminar_franjas_vigencia (
        p_json_entrada IN  CLOB,
        p_json_salida  OUT CLOB
    ) IS
        v_obj_in        JSON_OBJECT_T;
        v_id_usuario    NUMBER(12);
        v_str_ini       VARCHAR2(50);
        v_str_fin       VARCHAR2(50);
        v_fecha_inicial DATE;
        v_fecha_final   DATE;
        v_resp_obj      JSON_OBJECT_T;
    BEGIN
        IF p_json_entrada IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'El payload de entrada no puede ser nulo.');
        END IF;

        v_obj_in     := JSON_OBJECT_T.parse(p_json_entrada);
        v_id_usuario := v_obj_in.get_number('id_usuario');
        v_str_ini    := v_obj_in.get_string('fecha_inicial');
        v_str_fin    := v_obj_in.get_string('fecha_final');

        IF v_id_usuario IS NULL OR v_str_ini IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'El id_usuario y fecha_inicial son obligatorios.');
        END IF;

        v_fecha_inicial := f_parsear_fecha(v_str_ini);
        v_fecha_final   := f_parsear_fecha(v_str_fin);

        pkgca_tkr_franjas_profesional.p_borrar_x_rango_fechas(
            p_id_usuario    => v_id_usuario,
            p_fecha_inicial => v_fecha_inicial,
            p_fecha_final   => v_fecha_final
        );

        p_do_commit('PKGLN_FRANJAS.p_eliminar_franjas_vigencia');

        v_resp_obj := JSON_OBJECT_T();
        v_resp_obj.put('codigo', 0);
        v_resp_obj.put('mensaje', 'Vigencia de franjas eliminada exitosamente');
        p_json_salida := v_resp_obj.to_clob;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            IF SQLCODE BETWEEN -20999 AND -20001 THEN
                RAISE;
            END IF;

            vro_error.tipo            := 'E';
            vro_error.nombre_programa := 'PKGLN_FRANJAS';
            vro_error.nombre_metodo   := 'p_eliminar_franjas_vigencia';
            vro_error.parametros      := p_json_entrada;
            vro_error.codigo_error    := TO_CHAR(SQLCODE);
            vro_error.texto_error     := DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
            vro_error.mensaje_error   := SUBSTR(SQLERRM, 1, 4000);
            uti_ge_excepciones_pkg.p_grabar_log(vro_error);

            RAISE_APPLICATION_ERROR(
                -20000,
                'Error al eliminar vigencia de franjas: ' || SQLERRM
            );
    END p_eliminar_franjas_vigencia;

END pkgln_franjas;
/
