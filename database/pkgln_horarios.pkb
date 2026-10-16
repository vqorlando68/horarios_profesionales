CREATE OR REPLACE PACKAGE BODY PKGLN_HORARIOS
AS
    /*
    || =========================================================================
    || Paquete: PKGLN_HORARIOS (Body)
    || Propósito: Orquestación transaccional para horarios y ausencias de profesionales
    || Estándar: oracle-plsql-architecture
    || Reglas:
    ||   - PROHIBIDO: Cero SQL directo (SELECT, INSERT, UPDATE, DELETE).
    ||   - Delegación estricta a pkgca_, pkgcn_ y DAOs.
    ||   - Transaccionalidad mediante p_do_commit('<paquete>.<metodo>').
    ||   - Manejo de excepciones con uti_ge_excepciones_pkg.p_grabar_log y -20000.
    || =========================================================================
    */

    vro_error tkr_errores%ROWTYPE;

    -- Procedimiento privado de confirmación transaccional
    PROCEDURE p_do_commit (p_origen IN VARCHAR2) IS
    BEGIN
        COMMIT;
    END p_do_commit;

    -- Función utilitaria interna para parsear fechas ISO
    FUNCTION f_parsear_fecha (
        p_str_fecha IN VARCHAR2
    ) RETURN DATE IS
        v_fecha  DATE;
        v_limpia VARCHAR2(50);
    BEGIN
        IF p_str_fecha IS NULL THEN
            RETURN NULL;
        END IF;

        v_limpia := SUBSTR(TRIM(p_str_fecha), 1, 10);

        BEGIN
            v_fecha := TO_DATE(v_limpia, 'YYYY-MM-DD');
        EXCEPTION
            WHEN OTHERS THEN
                BEGIN
                    v_fecha := TO_DATE(SUBSTR(TRIM(p_str_fecha), 1, 19), 'YYYY-MM-DD"T"HH24:MI:SS');
                EXCEPTION
                    WHEN OTHERS THEN
                        v_fecha := TO_DATE(SUBSTR(TRIM(p_str_fecha), 1, 19), 'YYYY-MM-DD HH24:MI:SS');
                END;
        END;

        RETURN TRUNC(v_fecha);
    END f_parsear_fecha;

    -- Función utilitaria interna para obtener el nombre legible del día
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

    -- 1. Listar profesionales habilitados
    PROCEDURE p_listar_profesionales (
        p_json_entrada IN  CLOB,
        p_json_salida  OUT CLOB
    ) IS
        v_obj_in NUMBER := 0;
        v_filtro VARCHAR2(200);
    BEGIN
        IF p_json_entrada IS NOT NULL THEN
            BEGIN
                DECLARE
                    v_json JSON_OBJECT_T := JSON_OBJECT_T.parse(p_json_entrada);
                BEGIN
                    v_filtro := v_json.get_string('filtro');
                END;
            EXCEPTION
                WHEN OTHERS THEN
                    NULL;
            END;
        END IF;

        -- Delegación a caso de negocio JSON
        PKGCN_HORARIOS.p_consultar_profesionales_json(
            p_filtro_nombre => v_filtro,
            p_json_salida   => p_json_salida
        );

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            IF SQLCODE BETWEEN -20999 AND -20001 THEN
                RAISE;
            END IF;

            vro_error.tipo            := 'E';
            vro_error.nombre_programa := 'PKGLN_HORARIOS';
            vro_error.nombre_metodo   := 'p_listar_profesionales';
            vro_error.parametros      := p_json_entrada;
            vro_error.codigo_error    := TO_CHAR(SQLCODE);
            vro_error.texto_error     := DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
            vro_error.mensaje_error   := SUBSTR(SQLERRM, 1, 4000);

            uti_ge_excepciones_pkg.p_grabar_log(vro_error);

            RAISE_APPLICATION_ERROR(
                -20000,
                'Se presento un error comunicarse con soporte. Número error: '
                || vro_error.id
                || ' - '
                || SQLERRM
            );
    END p_listar_profesionales;

    -- 2. Guardar y sincronizar horarios multi-rango
    PROCEDURE p_guardar_horarios (
        p_json_entrada IN  CLOB,
        p_json_salida  OUT CLOB
    ) IS
        v_obj_in                JSON_OBJECT_T;
        v_arr_horarios          JSON_ARRAY_T;
        v_elem_horario          JSON_OBJECT_T;
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
            BEGIN
                v_fecha_ini_orig := TO_DATE(v_fecha_ini_orig_str, 'YYYY-MM-DD');
                v_tiene_orig     := TRUE;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE_APPLICATION_ERROR(-20005, 'Formato inválido en fecha_inicial_origen (' || v_fecha_ini_orig_str || ').');
            END;

            IF v_fecha_fin_orig_str IS NOT NULL AND v_fecha_fin_orig_str <> 'null' AND v_fecha_fin_orig_str <> 'undefined' THEN
                BEGIN
                    v_fecha_fin_orig := TO_DATE(v_fecha_fin_orig_str, 'YYYY-MM-DD');
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE_APPLICATION_ERROR(-20006, 'Formato inválido en fecha_final_origen (' || v_fecha_fin_orig_str || ').');
                END;
            ELSE
                v_fecha_fin_orig := NULL;
            END IF;
        END IF;

        IF v_id_usuario IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'El identificador del profesional (id_usuario) es obligatorio.');
        END IF;

        -- Fase 1: Validación en memoria de la estructura del arreglo de horarios
        IF v_obj_in.has('horarios') THEN
            v_arr_horarios := v_obj_in.get_array('horarios');
            FOR i IN 0 .. v_arr_horarios.get_size - 1 LOOP
                v_elem_horario      := JSON_OBJECT_T(v_arr_horarios.get(i));
                v_dia_semana        := UPPER(TRIM(v_elem_horario.get_string('dia_semana')));
                v_hora_desde        := TRIM(v_elem_horario.get_string('hora_desde'));
                v_hora_hasta        := TRIM(v_elem_horario.get_string('hora_hasta'));
                v_fecha_inicial_str := TRIM(v_elem_horario.get_string('fecha_inicial'));
                v_fecha_final_str   := TRIM(v_elem_horario.get_string('fecha_final'));

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

                -- Validación de fecha_inicial obligatoria
                IF v_fecha_inicial_str IS NULL THEN
                    RAISE_APPLICATION_ERROR(-20004, 'La fecha inicial es obligatoria para cada horario configurado (formato YYYY-MM-DD).');
                END IF;

                BEGIN
                    v_fecha_inicial := TO_DATE(v_fecha_inicial_str, 'YYYY-MM-DD');
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE_APPLICATION_ERROR(-20005, 'Formato inválido en fecha_inicial (' || v_fecha_inicial_str || '). Se espera YYYY-MM-DD.');
                END;

                -- Guardar fechas del primer elemento para soporte de reemplazo de vigencia si aplica
                IF i = 0 THEN
                    v_fecha_ini_lote := v_fecha_inicial;
                END IF;

                -- Validación de fecha_final opcional
                IF v_fecha_final_str IS NOT NULL THEN
                    BEGIN
                        v_fecha_final := TO_DATE(v_fecha_final_str, 'YYYY-MM-DD');
                    EXCEPTION
                        WHEN OTHERS THEN
                            RAISE_APPLICATION_ERROR(-20006, 'Formato inválido en fecha_final (' || v_fecha_final_str || '). Se espera YYYY-MM-DD.');
                    END;

                    IF v_fecha_final < v_fecha_inicial THEN
                        RAISE_APPLICATION_ERROR(-20007, 'La fecha final (' || v_fecha_final_str || ') no puede ser menor a la fecha inicial (' || v_fecha_inicial_str || ').');
                    END IF;
                ELSE
                    v_fecha_final := NULL;
                END IF;

                IF i = 0 THEN
                    v_fecha_fin_lote := v_fecha_final;
                END IF;

                -- Validación interna de no solapamiento con los demás rangos del payload para el mismo día
                FOR j IN (i + 1) .. v_arr_horarios.get_size - 1 LOOP
                    DECLARE
                        v_comp_elem     JSON_OBJECT_T := JSON_OBJECT_T(v_arr_horarios.get(j));
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
                            v_comp_ini := TO_DATE(v_comp_ini_str, 'YYYY-MM-DD');
                            IF v_comp_fin_str IS NOT NULL THEN
                                v_comp_fin := TO_DATE(v_comp_fin_str, 'YYYY-MM-DD');
                            ELSE
                                v_comp_fin := NULL;
                            END IF;

                            v_fin_eff_1 := NVL(v_fecha_final, TO_DATE('9999-12-31', 'YYYY-MM-DD'));
                            v_fin_eff_2 := NVL(v_comp_fin, TO_DATE('9999-12-31', 'YYYY-MM-DD'));

                            -- Se solapan si las vigencias de fechas coinciden Y las horas coinciden
                            IF (v_fecha_inicial <= v_fin_eff_2 AND v_fin_eff_1 >= v_comp_ini)
                               AND (v_hora_desde < v_comp_hasta AND v_hora_hasta > v_comp_desde) THEN
                                RAISE_APPLICATION_ERROR(
                                    -20008,
                                    'Existe cruce de horarios para el día '
                                    || f_nombre_dia_semana(v_dia_semana)
                                    || ': el turno de ' || v_hora_desde || ' a ' || v_hora_hasta
                                    || ' se traslapa con el turno de ' || v_comp_desde || ' a ' || v_comp_hasta
                                    || ' en la vigencia del ' || v_fecha_inicial_str
                                    || CASE 
                                           WHEN v_fecha_final_str IS NOT NULL THEN ' al ' || v_fecha_final_str 
                                           ELSE ' en adelante (indefinida)'
                                       END || '. Por favor ajuste las horas para que no se superpongan.'
                                );
                            END IF;
                        END IF;
                    END;
                END LOOP;

            END LOOP;
        END IF;

        -- Fase 2: Borrado previo controlado según el alcance de la operación
        -- 1. Si es reemplazo completo de todo el profesional:
        IF v_reemplazar_todo = 1 THEN
            pkgca_tkr_horarios_profesional.p_borrar_x_profesional(
                p_id_usuario => v_id_usuario
            );
        -- 2. Si se está modificando una vigencia origen específica:
        ELSIF v_tiene_orig THEN
            pkgca_tkr_horarios_profesional.p_borrar_x_rango_fechas(
                p_id_usuario    => v_id_usuario,
                p_fecha_inicial => v_fecha_ini_orig,
                p_fecha_final   => v_fecha_fin_orig
            );
        -- 3. Si se solicita reemplazo de la vigencia del lote:
        ELSIF v_reemplazar_vigencia = 1 AND v_fecha_ini_lote IS NOT NULL THEN
            pkgca_tkr_horarios_profesional.p_borrar_x_rango_fechas(
                p_id_usuario    => v_id_usuario,
                p_fecha_inicial => v_fecha_ini_lote,
                p_fecha_final   => v_fecha_fin_lote
            );
        END IF;

        -- Fase 3: Validación contra los horarios restantes en base de datos (garantiza no solapamiento)
        -- 3.1 Unicidad de Horario Base: Solo se permite un único registro con fecha_final nula por profesional
        IF v_reemplazar_todo = 0 AND v_fecha_fin_lote IS NULL THEN
            IF pkgca_tkr_horarios_profesional.f_existe_horario_base(v_id_usuario) = 1 THEN
                RAISE_APPLICATION_ERROR(
                    -20011,
                    'El profesional ya cuenta con un Horario Base registrado (sin fecha final). Solo se permite un único Horario Base por profesional; debe modificar el existente o asignarle una fecha final para registrarlo como Horario Personalizado.'
                );
            END IF;
        END IF;

        -- 3.2 Validación contra los horarios restantes en BD: solo aplica para Horarios Personalizados (con fecha final)
        -- Los horarios sin fecha final (Horario Base) no realizan validaciones contra horarios con fecha final
        IF v_reemplazar_todo = 0 AND v_fecha_fin_lote IS NOT NULL AND v_arr_horarios IS NOT NULL THEN
            FOR i IN 0 .. v_arr_horarios.get_size - 1 LOOP
                v_elem_horario      := JSON_OBJECT_T(v_arr_horarios.get(i));
                v_dia_semana        := UPPER(TRIM(v_elem_horario.get_string('dia_semana')));
                v_hora_desde        := TRIM(v_elem_horario.get_string('hora_desde'));
                v_hora_hasta        := TRIM(v_elem_horario.get_string('hora_hasta'));
                v_fecha_inicial_str := TRIM(v_elem_horario.get_string('fecha_inicial'));
                v_fecha_final_str   := TRIM(v_elem_horario.get_string('fecha_final'));
                v_fecha_inicial     := TO_DATE(v_fecha_inicial_str, 'YYYY-MM-DD');
                IF v_fecha_final_str IS NOT NULL THEN
                    v_fecha_final := TO_DATE(v_fecha_final_str, 'YYYY-MM-DD');
                ELSE
                    v_fecha_final := NULL;
                END IF;

                IF PKGCN_HORARIOS.f_existe_traslape_horario(
                       p_id_usuario    => v_id_usuario,
                       p_dia_semana    => v_dia_semana,
                       p_hora_desde    => v_hora_desde,
                       p_hora_hasta    => v_hora_hasta,
                       p_fecha_inicial => v_fecha_inicial,
                       p_fecha_final   => v_fecha_final
                   ) THEN
                    RAISE_APPLICATION_ERROR(
                        -20009,
                        'El horario para el día ' || f_nombre_dia_semana(v_dia_semana)
                        || ' (' || v_hora_desde || ' a ' || v_hora_hasta
                        || ') se cruza con un horario previamente registrado en la base de datos para ese rango de fechas.'
                    );
                END IF;
            END LOOP;
        END IF;

        -- Fase 4: Inserción de los nuevos rangos horarios vía PKGCN (desestructuración JSON_TABLE con fechas)
        IF v_arr_horarios IS NOT NULL AND v_arr_horarios.get_size > 0 THEN
            PKGCN_HORARIOS.p_guardar_horarios_profesional(
                p_id_usuario    => v_id_usuario,
                p_json_horarios => p_json_entrada
            );
        END IF;

        -- Fase 5: Confirmación transaccional controlada
        p_do_commit('PKGLN_HORARIOS.p_guardar_horarios');

        -- Fase 6: Construcción de respuesta JSON
        v_resp_obj := JSON_OBJECT_T();
        v_resp_obj.put('codigo', 0);
        v_resp_obj.put('mensaje', 'Horarios del profesional guardados exitosamente.');
        v_resp_obj.put('id_usuario', v_id_usuario);
        p_json_salida := v_resp_obj.to_clob();

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            IF SQLCODE BETWEEN -20999 AND -20001 THEN
                RAISE;
            END IF;

            vro_error.tipo            := 'E';
            vro_error.nombre_programa := 'PKGLN_HORARIOS';
            vro_error.nombre_metodo   := 'p_guardar_horarios';
            vro_error.parametros      := p_json_entrada;
            vro_error.codigo_error    := TO_CHAR(SQLCODE);
            vro_error.texto_error     := DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
            vro_error.mensaje_error   := SUBSTR(SQLERRM, 1, 4000);

            uti_ge_excepciones_pkg.p_grabar_log(vro_error);

            RAISE_APPLICATION_ERROR(
                -20000,
                'Se presento un error comunicarse con soporte. Número error: '
                || vro_error.id
                || ' - '
                || SQLERRM
            );
    END p_guardar_horarios;

    -- 3. Consultar agenda completa de un profesional
    PROCEDURE p_consultar_agenda (
        p_json_entrada IN  CLOB,
        p_json_salida  OUT CLOB
    ) IS
        v_obj_in     JSON_OBJECT_T;
        v_id_usuario NUMBER(12);
    BEGIN
        IF p_json_entrada IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'El payload de entrada no puede ser nulo.');
        END IF;

        v_obj_in     := JSON_OBJECT_T.parse(p_json_entrada);
        v_id_usuario := v_obj_in.get_number('id_usuario');

        IF v_id_usuario IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'El identificador del profesional es obligatorio.');
        END IF;

        -- Consulta consolidada
        PKGCN_HORARIOS.p_consultar_agenda_profesional_json(
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
            vro_error.nombre_programa := 'PKGLN_HORARIOS';
            vro_error.nombre_metodo   := 'p_consultar_agenda';
            vro_error.parametros      := p_json_entrada;
            vro_error.codigo_error    := TO_CHAR(SQLCODE);
            vro_error.texto_error     := DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
            vro_error.mensaje_error   := SUBSTR(SQLERRM, 1, 4000);

            uti_ge_excepciones_pkg.p_grabar_log(vro_error);

            RAISE_APPLICATION_ERROR(
                -20000,
                'Se presento un error comunicarse con soporte. Número error: '
                || vro_error.id
                || ' - '
                || SQLERRM
            );
    END p_consultar_agenda;

    -- 4. Registrar ausencia de profesional
    PROCEDURE p_registrar_ausencia (
        p_json_entrada IN  CLOB,
        p_json_salida  OUT CLOB
    ) IS
        v_obj_in        JSON_OBJECT_T;
        v_id_usuario    NUMBER(12);
        v_str_inicio    VARCHAR2(50);
        v_str_fin       VARCHAR2(50);
        v_fecha_inicial DATE;
        v_fecha_final   DATE;
        vro_ausencia    tkr_ausencias_profesional%ROWTYPE;
        v_resp_obj      JSON_OBJECT_T;
    BEGIN
        IF p_json_entrada IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'El payload de entrada JSON no puede ser nulo.');
        END IF;

        v_obj_in     := JSON_OBJECT_T.parse(p_json_entrada);
        v_id_usuario := v_obj_in.get_number('id_usuario');
        v_str_inicio := v_obj_in.get_string('fecha_inicial');
        v_str_fin    := v_obj_in.get_string('fecha_final');

        IF v_id_usuario IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'El identificador del profesional (id_usuario) es obligatorio.');
        END IF;

        IF v_str_inicio IS NULL OR v_str_fin IS NULL THEN
            RAISE_APPLICATION_ERROR(-20002, 'Las fechas inicial y final son obligatorias.');
        END IF;

        v_fecha_inicial := f_parsear_fecha(v_str_inicio);
        v_fecha_final   := f_parsear_fecha(v_str_fin);

        IF v_fecha_inicial IS NULL OR v_fecha_final IS NULL THEN
            RAISE_APPLICATION_ERROR(-20003, 'Formato de fecha inválido. Utilice YYYY-MM-DD.');
        END IF;

        IF v_fecha_inicial > v_fecha_final THEN
            RAISE_APPLICATION_ERROR(-20004, 'La fecha inicial (' || TO_CHAR(v_fecha_inicial, 'YYYY-MM-DD') || ') no puede ser superior a la final (' || TO_CHAR(v_fecha_final, 'YYYY-MM-DD') || ').');
        END IF;

        -- Validación de existencia previa (no duplicar ausencia si el día ya está cubierto)
        IF pkgca_tkr_ausencias_profesional.f_existe_ausencia(v_id_usuario, v_fecha_inicial, v_fecha_final) THEN
            v_resp_obj := JSON_OBJECT_T();
            v_resp_obj.put('codigo', 0);
            v_resp_obj.put('mensaje', 'El rango o día de ausencia ya se encuentra registrado previamente.');
            v_resp_obj.put('id_usuario', v_id_usuario);
            v_resp_obj.put('fecha_inicial', TO_CHAR(v_fecha_inicial, 'YYYY-MM-DD'));
            v_resp_obj.put('fecha_final', TO_CHAR(v_fecha_final, 'YYYY-MM-DD'));
            p_json_salida := v_resp_obj.to_clob();
            RETURN;
        END IF;

        -- Persistencia delegada al DAO
        vro_ausencia.id             := NULL;
        vro_ausencia.id_usuario     := v_id_usuario;
        vro_ausencia.fecha_inicial  := v_fecha_inicial;
        vro_ausencia.fecha_final    := v_fecha_final;
        vro_ausencia.fecha_creacion := SYSDATE;

        PKGTKR_AUSENCIAS_PROFESIONAL_DAO.p_insertar(vro_ausencia);

        -- Confirmación transaccional
        p_do_commit('PKGLN_HORARIOS.p_registrar_ausencia');

        -- Respuesta
        v_resp_obj := JSON_OBJECT_T();
        v_resp_obj.put('codigo', 0);
        v_resp_obj.put('mensaje', 'Ausencia del profesional registrada exitosamente.');
        v_resp_obj.put('id_usuario', v_id_usuario);
        v_resp_obj.put('fecha_inicial', TO_CHAR(v_fecha_inicial, 'YYYY-MM-DD'));
        v_resp_obj.put('fecha_final', TO_CHAR(v_fecha_final, 'YYYY-MM-DD'));
        p_json_salida := v_resp_obj.to_clob();

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            IF SQLCODE BETWEEN -20999 AND -20001 THEN
                RAISE;
            END IF;

            vro_error.tipo            := 'E';
            vro_error.nombre_programa := 'PKGLN_HORARIOS';
            vro_error.nombre_metodo   := 'p_registrar_ausencia';
            vro_error.parametros      := p_json_entrada;
            vro_error.codigo_error    := TO_CHAR(SQLCODE);
            vro_error.texto_error     := DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
            vro_error.mensaje_error   := SUBSTR(SQLERRM, 1, 4000);

            uti_ge_excepciones_pkg.p_grabar_log(vro_error);

            RAISE_APPLICATION_ERROR(
                -20000,
                'Se presento un error comunicarse con soporte. Número error: '
                || vro_error.id
                || ' - '
                || SQLERRM
            );
    END p_registrar_ausencia;

    -- 5. Consultar ausencias
    PROCEDURE p_consultar_ausencias (
        p_json_entrada IN  CLOB,
        p_json_salida  OUT CLOB
    ) IS
    BEGIN
        PKGCN_HORARIOS.pr_consultar_ausencias_json(
            p_json      => p_json_entrada,
            p_resultado => p_json_salida
        );
    END p_consultar_ausencias;

    -- 6. Eliminar ausencia
    PROCEDURE p_eliminar_ausencia (
        p_json_entrada IN  CLOB,
        p_json_salida  OUT CLOB
    ) IS
        v_obj_in    JSON_OBJECT_T;
        v_id        NUMBER(12);
        v_resp_obj  JSON_OBJECT_T;
    BEGIN
        IF p_json_entrada IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'El payload de entrada no puede ser nulo.');
        END IF;

        v_obj_in := JSON_OBJECT_T.parse(p_json_entrada);
        v_id     := v_obj_in.get_number('id');

        IF v_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'El identificador de la ausencia (id) es obligatorio.');
        END IF;

        IF NOT PKGTKR_AUSENCIAS_PROFESIONAL_DAO.f_existe(v_id) THEN
            RAISE_APPLICATION_ERROR(-20002, 'La ausencia con ID ' || v_id || ' no existe.');
        END IF;

        PKGTKR_AUSENCIAS_PROFESIONAL_DAO.p_eliminar(v_id);

        p_do_commit('PKGLN_HORARIOS.p_eliminar_ausencia');

        v_resp_obj := JSON_OBJECT_T();
        v_resp_obj.put('codigo', 0);
        v_resp_obj.put('mensaje', 'Ausencia eliminada exitosamente.');
        v_resp_obj.put('id', v_id);
        p_json_salida := v_resp_obj.to_clob();

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            IF SQLCODE BETWEEN -20999 AND -20001 THEN
                RAISE;
            END IF;

            vro_error.tipo            := 'E';
            vro_error.nombre_programa := 'PKGLN_HORARIOS';
            vro_error.nombre_metodo   := 'p_eliminar_ausencia';
            vro_error.parametros      := p_json_entrada;
            vro_error.codigo_error    := TO_CHAR(SQLCODE);
            vro_error.texto_error     := DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
            vro_error.mensaje_error   := SUBSTR(SQLERRM, 1, 4000);

            uti_ge_excepciones_pkg.p_grabar_log(vro_error);

            RAISE_APPLICATION_ERROR(
                -20000,
                'Se presento un error comunicarse con soporte. Número error: '
                || vro_error.id
                || ' - '
                || SQLERRM
            );
    END p_eliminar_ausencia;

    -- 7. Eliminar horarios de una vigencia específica
    PROCEDURE p_eliminar_horarios_vigencia (
        p_json_entrada IN  CLOB,
        p_json_salida  OUT CLOB
    ) IS
        v_obj_in           JSON_OBJECT_T;
        v_id_usuario       NUMBER(12);
        v_str_ini          VARCHAR2(50);
        v_str_fin          VARCHAR2(50);
        v_trabaja_festivos VARCHAR2(10);
        v_fecha_inicial    DATE;
        v_fecha_final      DATE;
        v_resp_obj         JSON_OBJECT_T;
    BEGIN
        IF p_json_entrada IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'El payload de entrada no puede ser nulo.');
        END IF;

        v_obj_in           := JSON_OBJECT_T.parse(p_json_entrada);
        v_id_usuario       := v_obj_in.get_number('id_usuario');
        v_str_ini          := v_obj_in.get_string('fecha_inicial');
        v_str_fin          := v_obj_in.get_string('fecha_final');
        v_trabaja_festivos := v_obj_in.get_string('trabaja_festivos');

        IF v_id_usuario IS NULL OR v_str_ini IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'El id_usuario y fecha_inicial son obligatorios.');
        END IF;

        IF v_trabaja_festivos IS NULL THEN
            v_trabaja_festivos := pkgca_tkr_usuarios.f_trabaja_festivos(v_id_usuario);
        END IF;

        v_fecha_inicial := f_parsear_fecha(v_str_ini);
        IF v_str_fin IS NOT NULL THEN
            v_fecha_final := f_parsear_fecha(v_str_fin);
        ELSE
            v_fecha_final := NULL;
        END IF;

        -- Si es un horario personalizado y el usuario no labora festivos, borrar festivos de ausencias no solapados
        IF v_fecha_final IS NOT NULL AND UPPER(TRIM(v_trabaja_festivos)) = 'N' THEN
            PKGCN_HORARIOS.p_eliminar_ausencias_festivos_vigencia(
                p_id_usuario    => v_id_usuario,
                p_fecha_inicial => v_fecha_inicial,
                p_fecha_final   => v_fecha_final
            );
        END IF;

        -- Delegación a pkgca_tkr_horarios_profesional
        pkgca_tkr_horarios_profesional.p_borrar_x_rango_fechas(
            p_id_usuario    => v_id_usuario,
            p_fecha_inicial => v_fecha_inicial,
            p_fecha_final   => v_fecha_final
        );

        p_do_commit('PKGLN_HORARIOS.p_eliminar_horarios_vigencia');

        v_resp_obj := JSON_OBJECT_T();
        v_resp_obj.put('codigo', 0);
        v_resp_obj.put('mensaje', 'Horarios de la vigencia eliminados exitosamente.');
        v_resp_obj.put('id_usuario', v_id_usuario);
        p_json_salida := v_resp_obj.to_clob();

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            IF SQLCODE BETWEEN -20999 AND -20001 THEN
                RAISE;
            END IF;

            vro_error.tipo            := 'E';
            vro_error.nombre_programa := 'PKGLN_HORARIOS';
            vro_error.nombre_metodo   := 'p_eliminar_horarios_vigencia';
            vro_error.parametros      := p_json_entrada;
            vro_error.codigo_error    := TO_CHAR(SQLCODE);
            vro_error.texto_error     := DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
            vro_error.mensaje_error   := SUBSTR(SQLERRM, 1, 4000);

            uti_ge_excepciones_pkg.p_grabar_log(vro_error);

            RAISE_APPLICATION_ERROR(
                -20000,
                'Se presento un error comunicarse con soporte. Número error: '
                || vro_error.id
                || ' - '
                || SQLERRM
            );
    END p_eliminar_horarios_vigencia;

    -- 8. Actualizar trabaja_festivos de un profesional y limpiar domingos si aplica
    PROCEDURE p_actualizar_trabaja_festivos (
        p_json_entrada IN  CLOB,
        p_json_salida  OUT CLOB
    ) IS
        v_obj_in           JSON_OBJECT_T;
        v_id_usuario       NUMBER(12);
        v_trabaja_festivos VARCHAR2(10);
        v_borrar_domingos  NUMBER(1) := 0;
        v_resp_obj         JSON_OBJECT_T;
    BEGIN
        IF p_json_entrada IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'El payload de entrada no puede ser nulo.');
        END IF;

        v_obj_in           := JSON_OBJECT_T.parse(p_json_entrada);
        v_id_usuario       := v_obj_in.get_number('id_usuario');
        v_trabaja_festivos := UPPER(TRIM(v_obj_in.get_string('trabaja_festivos')));

        IF v_obj_in.has('borrar_domingos') THEN
            v_borrar_domingos := v_obj_in.get_number('borrar_domingos');
        END IF;

        IF v_id_usuario IS NULL OR v_trabaja_festivos IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'El id_usuario y trabaja_festivos son obligatorios.');
        END IF;

        IF v_trabaja_festivos NOT IN ('S', 'N') THEN
            RAISE_APPLICATION_ERROR(-20002, 'El valor de trabaja_festivos debe ser S o N.');
        END IF;

        -- 1. Actualiza el indicador en tkr_usuarios vía pkgca_tkr_usuarios
        pkgca_tkr_usuarios.p_actualizar_trabaja_festivos(
            p_id_usuario       => v_id_usuario,
            p_trabaja_festivos => v_trabaja_festivos
        );

        -- 2. Si no trabaja festivos y se confirmó borrar domingos, elimina los horarios de día DO
        IF v_trabaja_festivos = 'N' AND v_borrar_domingos = 1 THEN
            pkgca_tkr_horarios_profesional.p_borrar_x_dia_semana(
                p_id_usuario => v_id_usuario,
                p_dia_semana => 'DO'
            );
        END IF;

        -- 3. Confirmación atómica
        p_do_commit('PKGLN_HORARIOS.p_actualizar_trabaja_festivos');

        v_resp_obj := JSON_OBJECT_T();
        v_resp_obj.put('codigo', 0);
        v_resp_obj.put('mensaje', 'Configuración de trabaja_festivos actualizada exitosamente.');
        v_resp_obj.put('id_usuario', v_id_usuario);
        v_resp_obj.put('trabaja_festivos', v_trabaja_festivos);
        p_json_salida := v_resp_obj.to_clob();

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            IF SQLCODE BETWEEN -20999 AND -20001 THEN
                RAISE;
            END IF;

            vro_error.tipo            := 'E';
            vro_error.nombre_programa := 'PKGLN_HORARIOS';
            vro_error.nombre_metodo   := 'p_actualizar_trabaja_festivos';
            vro_error.parametros      := p_json_entrada;
            vro_error.codigo_error    := TO_CHAR(SQLCODE);
            vro_error.texto_error     := DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
            vro_error.mensaje_error   := SUBSTR(SQLERRM, 1, 4000);

            uti_ge_excepciones_pkg.p_grabar_log(vro_error);

            RAISE_APPLICATION_ERROR(
                -20000,
                'Se presento un error comunicarse con soporte. Número error: '
                || vro_error.id
                || ' - '
                || SQLERRM
            );
    END p_actualizar_trabaja_festivos;

    -- =========================================================================
    -- ALIAS DE COMPATIBILIDAD
    -- =========================================================================
    PROCEDURE pr_registrar_ausencia (
        p_json      IN  CLOB,
        p_resultado OUT CLOB
    ) IS
    BEGIN
        p_registrar_ausencia(p_json, p_resultado);
    END pr_registrar_ausencia;

    PROCEDURE pr_actualizar_ausencia (
        p_json      IN  CLOB,
        p_resultado OUT CLOB
    ) IS
        v_obj_in        JSON_OBJECT_T;
        v_id            NUMBER;
        v_id_usuario    NUMBER;
        v_str_inicio    VARCHAR2(50);
        v_str_fin       VARCHAR2(50);
        v_fecha_inicial DATE;
        v_fecha_final   DATE;
        vro_ausencia    tkr_ausencias_profesional%ROWTYPE;
        v_resp_obj      JSON_OBJECT_T;
    BEGIN
        v_obj_in        := JSON_OBJECT_T.parse(p_json);
        v_id            := v_obj_in.get_number('id');
        v_id_usuario    := v_obj_in.get_number('id_usuario');
        v_str_inicio    := v_obj_in.get_string('fecha_inicial');
        v_str_fin       := v_obj_in.get_string('fecha_final');

        IF v_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'El ID de la ausencia es obligatorio.');
        END IF;

        IF NOT PKGTKR_AUSENCIAS_PROFESIONAL_DAO.f_existe(v_id, vro_ausencia) THEN
            RAISE_APPLICATION_ERROR(-20002, 'La ausencia no existe.');
        END IF;

        IF v_id_usuario IS NOT NULL THEN
            vro_ausencia.id_usuario := v_id_usuario;
        END IF;

        IF v_str_inicio IS NOT NULL THEN
            v_fecha_inicial := f_parsear_fecha(v_str_inicio);
            vro_ausencia.fecha_inicial := v_fecha_inicial;
        END IF;

        IF v_str_fin IS NOT NULL THEN
            v_fecha_final := f_parsear_fecha(v_str_fin);
            vro_ausencia.fecha_final := v_fecha_final;
        END IF;

        IF vro_ausencia.fecha_inicial > vro_ausencia.fecha_final THEN
            RAISE_APPLICATION_ERROR(-20003, 'La fecha inicial no puede ser superior a la fecha final.');
        END IF;

        PKGTKR_AUSENCIAS_PROFESIONAL_DAO.p_actualizar(vro_ausencia);

        p_do_commit('PKGLN_HORARIOS.pr_actualizar_ausencia');

        v_resp_obj := JSON_OBJECT_T();
        v_resp_obj.put('success', TRUE);
        v_resp_obj.put('message', 'Ausencia actualizada exitosamente.');
        p_resultado := v_resp_obj.to_clob();

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            IF SQLCODE BETWEEN -20999 AND -20001 THEN
                RAISE;
            END IF;
            vro_error.tipo            := 'E';
            vro_error.nombre_programa := 'PKGLN_HORARIOS';
            vro_error.nombre_metodo   := 'pr_actualizar_ausencia';
            vro_error.parametros      := p_json;
            vro_error.codigo_error    := TO_CHAR(SQLCODE);
            vro_error.texto_error     := DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
            vro_error.mensaje_error   := SUBSTR(SQLERRM, 1, 4000);
            uti_ge_excepciones_pkg.p_grabar_log(vro_error);
            RAISE_APPLICATION_ERROR(
                -20000,
                'Se presento un error comunicarse con soporte. Número error: '
                || vro_error.id || ' - ' || SQLERRM
            );
    END pr_actualizar_ausencia;

    PROCEDURE pr_obtener_ausencias (
        p_json      IN  CLOB,
        p_resultado OUT CLOB
    ) IS
    BEGIN
        p_consultar_ausencias(p_json, p_resultado);
    END pr_obtener_ausencias;

    PROCEDURE pr_eliminar_ausencia (
        p_json      IN  CLOB,
        p_resultado OUT CLOB
    ) IS
    BEGIN
        p_eliminar_ausencia(p_json, p_resultado);
    END pr_eliminar_ausencia;

END PKGLN_HORARIOS;
/
