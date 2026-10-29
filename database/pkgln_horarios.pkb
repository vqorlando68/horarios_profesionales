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

    -- Función utilitaria interna para parsear fechas estándar YYYY-MM-DD
    FUNCTION f_parsear_fecha (
        p_str_fecha IN VARCHAR2
    ) RETURN DATE IS
        v_limpia VARCHAR2(50);
    BEGIN
        IF p_str_fecha IS NULL OR TRIM(p_str_fecha) = '' OR TRIM(p_str_fecha) = 'null' OR TRIM(p_str_fecha) = 'undefined' THEN
            RETURN NULL;
        END IF;

        v_limpia := TRIM(p_str_fecha);

        BEGIN
            RETURN TRUNC(TO_DATE(v_limpia, 'YYYY-MM-DD'));
        EXCEPTION
            WHEN OTHERS THEN
                RAISE_APPLICATION_ERROR(-20005, 'Formato de fecha inválido (' || p_str_fecha || '). Se espera YYYY-MM-DD.');
        END;
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

    -- Función utilitaria interna para limpiar y formatear mensajes de error para el usuario final
    FUNCTION f_limpiar_mensaje_error (
        p_sqlerrm IN VARCHAR2
    ) RETURN VARCHAR2 IS
        v_limpio VARCHAR2(4000);
    BEGIN
        v_limpio := NVL(p_sqlerrm, 'Error al procesar la operación.');
        v_limpio := REGEXP_REPLACE(v_limpio, '^ORA-[0-9]{5}:\s*', '');
        v_limpio := TRIM(v_limpio);
        RETURN v_limpio;
    END f_limpiar_mensaje_error;

    -- Función utilitaria interna para construir JSON de error seguro para PL/SQL
    FUNCTION f_formatear_error_json (
        p_codigo  IN NUMBER,
        p_sqlerrm IN VARCHAR2
    ) RETURN CLOB IS
        v_obj JSON_OBJECT_T;
    BEGIN
        v_obj := JSON_OBJECT_T();
        v_obj.put('codigo', p_codigo);
        v_obj.put('mensaje', f_limpiar_mensaje_error(p_sqlerrm));
        RETURN v_obj.to_clob();
    END f_formatear_error_json;

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
                p_json_salida := f_formatear_error_json(SQLCODE, SQLERRM);
                RETURN;
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
        v_arr_festivos          JSON_ARRAY_T;
        v_elem_fest             JSON_OBJECT_T;
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
        v_id_convenio           NUMBER;
        v_fecha_inicial_str     VARCHAR2(30);
        v_fecha_final_str       VARCHAR2(30);
        v_fecha_inicial         DATE;
        v_fecha_final           DATE;
        v_fecha_ini_lote        DATE;
        v_fecha_fin_lote        DATE;
        v_fin_lote_eff          DATE;
        v_fecha_fest_str        VARCHAR2(30);
        v_nombre_fest           VARCHAR2(250);
        v_fecha_fest            DATE;
        v_ausencias_creadas     NUMBER := 0;
        v_ausencias_existentes  NUMBER := 0;
        vro_ausencia            tkr_ausencias_profesional%ROWTYPE;
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
                    RAISE_APPLICATION_ERROR(-20005, 'Formato inválido en fecha_inicial_origen (' || v_fecha_ini_orig_str || '). Se espera YYYY-MM-DD.');
            END;

            IF v_fecha_fin_orig_str IS NOT NULL AND v_fecha_fin_orig_str <> 'null' AND v_fecha_fin_orig_str <> 'undefined' THEN
                BEGIN
                    v_fecha_fin_orig := TO_DATE(v_fecha_fin_orig_str, 'YYYY-MM-DD');
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE_APPLICATION_ERROR(-20006, 'Formato inválido en fecha_final_origen (' || v_fecha_fin_orig_str || '). Se espera YYYY-MM-DD.');
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
                v_id_convenio       := NULL;
                IF v_elem_horario.has('id_convenio') AND NOT v_elem_horario.get('id_convenio').is_null THEN
                    v_id_convenio := v_elem_horario.get_number('id_convenio');
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
                        v_comp_conv     NUMBER        := NULL;
                        v_comp_ini      DATE;
                        v_comp_fin      DATE;
                        v_fin_eff_1     DATE;
                        v_fin_eff_2     DATE;
                    BEGIN
                        IF v_comp_elem.has('id_convenio') AND NOT v_comp_elem.get('id_convenio').is_null THEN
                            v_comp_conv := v_comp_elem.get_number('id_convenio');
                        END IF;

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
                                -- Prioridad de convenio: una franja con id_convenio prevalece sobre null.
                                -- Solo hay conflicto si ambos son específicos o ambos son generales.
                                IF (v_id_convenio IS NULL AND v_comp_conv IS NULL)
                                   OR (v_id_convenio IS NOT NULL AND v_comp_conv IS NOT NULL) THEN
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
                        END IF;
                    END;
                END LOOP;

            END LOOP;
        END IF;

        -- Fase 1.1: Validación de festivos_no_laborables si viene informado en el payload
        IF v_obj_in.has('festivos_no_laborables') THEN
            v_arr_festivos := v_obj_in.get_array('festivos_no_laborables');
            IF v_arr_festivos IS NOT NULL AND v_arr_festivos.get_size > 0 THEN
                v_fin_lote_eff := NVL(v_fecha_fin_lote, TO_DATE('9999-12-31', 'YYYY-MM-DD'));
                FOR k IN 0 .. v_arr_festivos.get_size - 1 LOOP
                    v_elem_fest      := JSON_OBJECT_T(v_arr_festivos.get(k));
                    v_fecha_fest_str := TRIM(v_elem_fest.get_string('fecha'));
                    v_nombre_fest    := TRIM(v_elem_fest.get_string('nombre'));

                    BEGIN
                        v_fecha_fest := TO_DATE(v_fecha_fest_str, 'YYYY-MM-DD');
                    EXCEPTION
                        WHEN OTHERS THEN
                            RAISE_APPLICATION_ERROR(-20012, 'La fecha ' || v_fecha_fest_str || ' no es un festivo dentro del rango del horario.');
                    END;

                    -- Regla: No se aceptan domingos en el arreglo (los domingos se manejan en la grilla semanal)
                    IF TO_CHAR(v_fecha_fest, 'DY', 'NLS_DATE_LANGUAGE=ENGLISH') = 'SUN' THEN
                        RAISE_APPLICATION_ERROR(-20013, 'Los domingos no se registran como festivo no laborable.');
                    END IF;

                    -- Regla: Cada fecha debe estar dentro de [fecha_inicial, fecha_final] del lote
                    IF v_fecha_ini_lote IS NULL OR (v_fecha_fest < v_fecha_ini_lote OR v_fecha_fest > v_fin_lote_eff) THEN
                        RAISE_APPLICATION_ERROR(-20012, 'La fecha ' || v_fecha_fest_str || ' no es un festivo dentro del rango del horario.');
                    END IF;

                    -- Regla: Debe existir en tkr_festivos con id_pais = 1
                    IF NOT pkgca_tkr_festivos.f_es_festivo(p_fecha => v_fecha_fest, p_id_pais => 1) THEN
                        RAISE_APPLICATION_ERROR(-20012, 'La fecha ' || v_fecha_fest_str || ' no es un festivo dentro del rango del horario.');
                    END IF;
                END LOOP;
            END IF;
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

                v_id_convenio := NULL;
                IF v_elem_horario.has('id_convenio') AND NOT v_elem_horario.get('id_convenio').is_null THEN
                    v_id_convenio := v_elem_horario.get_number('id_convenio');
                END IF;

                IF PKGCN_HORARIOS.f_existe_traslape_horario(
                       p_id_usuario    => v_id_usuario,
                       p_dia_semana    => v_dia_semana,
                       p_hora_desde    => v_hora_desde,
                       p_hora_hasta    => v_hora_hasta,
                       p_fecha_inicial => v_fecha_inicial,
                       p_fecha_final   => v_fecha_final,
                       p_id_convenio   => v_id_convenio
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

        -- Fase 4.1: Inserción de ausencias para festivos_no_laborables en la misma transacción
        IF v_arr_festivos IS NOT NULL AND v_arr_festivos.get_size > 0 THEN
            FOR k IN 0 .. v_arr_festivos.get_size - 1 LOOP
                v_elem_fest      := JSON_OBJECT_T(v_arr_festivos.get(k));
                v_fecha_fest_str := TRIM(v_elem_fest.get_string('fecha'));
                v_nombre_fest    := TRIM(v_elem_fest.get_string('nombre'));
                v_fecha_fest     := TO_DATE(v_fecha_fest_str, 'YYYY-MM-DD');

                -- Validar si ya está cubierta por una ausencia existente (no duplicar)
                IF pkgca_tkr_ausencias_profesional.f_existe_ausencia(
                       p_id_usuario    => v_id_usuario,
                       p_fecha_inicial => v_fecha_fest,
                       p_fecha_final   => v_fecha_fest
                   ) THEN
                    v_ausencias_existentes := v_ausencias_existentes + 1;
                ELSE
                    vro_ausencia.id             := NULL;
                    vro_ausencia.id_usuario     := v_id_usuario;
                    vro_ausencia.fecha_inicial  := v_fecha_fest;
                    vro_ausencia.fecha_final    := v_fecha_fest;
                    vro_ausencia.fecha_creacion := SYSDATE;

                    PKGTKR_AUSENCIAS_PROFESIONAL_DAO.p_insertar(vro_ausencia);
                    v_ausencias_creadas := v_ausencias_creadas + 1;
                END IF;
            END LOOP;
        END IF;

        -- Fase 4.2: Sincronización de slots de agenda considerando citas ocupadas en tkr_citas (id_estado_cita IN (2,3))
        DECLARE
            v_json_sync_in  JSON_OBJECT_T := JSON_OBJECT_T();
            v_json_sync_out CLOB;
        BEGIN
            v_json_sync_in.put('id_usuario', v_id_usuario);
            IF v_tiene_orig AND v_fecha_ini_orig IS NOT NULL THEN
                v_json_sync_in.put('fecha_inicial', TO_CHAR(LEAST(NVL(v_fecha_ini_lote, v_fecha_ini_orig), v_fecha_ini_orig), 'YYYY-MM-DD'));
            ELSIF v_fecha_ini_lote IS NOT NULL THEN
                v_json_sync_in.put('fecha_inicial', TO_CHAR(v_fecha_ini_lote, 'YYYY-MM-DD'));
            END IF;
            IF v_tiene_orig AND v_fecha_fin_orig IS NOT NULL AND v_fecha_fin_lote IS NOT NULL THEN
                v_json_sync_in.put('fecha_final', TO_CHAR(GREATEST(v_fecha_fin_lote, v_fecha_fin_orig), 'YYYY-MM-DD'));
            ELSIF v_fecha_fin_lote IS NOT NULL THEN
                v_json_sync_in.put('fecha_final', TO_CHAR(v_fecha_fin_lote, 'YYYY-MM-DD'));
            END IF;
            p_sincornizar_agenda(
                p_json_entrada => v_json_sync_in.to_clob(),
                p_json_salida  => v_json_sync_out
            );
        END;

        -- Fase 5: Confirmación transaccional controlada
        p_do_commit('PKGLN_HORARIOS.p_guardar_horarios');

        -- Fase 6: Construcción de respuesta JSON
        v_resp_obj := JSON_OBJECT_T();
        v_resp_obj.put('codigo', 0);
        v_resp_obj.put('mensaje', 'Horarios del profesional guardados exitosamente.');
        v_resp_obj.put('id_usuario', v_id_usuario);
        v_resp_obj.put('ausencias_creadas', v_ausencias_creadas);
        v_resp_obj.put('ausencias_existentes', v_ausencias_existentes);
        p_json_salida := v_resp_obj.to_clob();

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;

            -- Devolver error de negocio controlado (-20001 a -20999) en p_json_salida con texto limpio
            IF SQLCODE BETWEEN -20999 AND -20001 THEN
                v_resp_obj := JSON_OBJECT_T();
                v_resp_obj.put('codigo', SQLCODE);
                v_resp_obj.put('mensaje', f_limpiar_mensaje_error(SQLERRM));
                v_resp_obj.put('id_usuario', v_id_usuario);
                v_resp_obj.put('ausencias_creadas', 0);
                v_resp_obj.put('ausencias_existentes', 0);
                p_json_salida := v_resp_obj.to_clob();
                RETURN;
            END IF;

            vro_error.tipo            := 'E';
            vro_error.nombre_programa := 'PKGLN_HORARIOS';
            vro_error.nombre_metodo   := 'p_guardar_horarios';
            vro_error.parametros      := p_json_entrada;
            vro_error.codigo_error    := TO_CHAR(SQLCODE);
            vro_error.texto_error     := DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
            vro_error.mensaje_error   := SUBSTR(SQLERRM, 1, 4000);

            uti_ge_excepciones_pkg.p_grabar_log(vro_error);

            v_resp_obj := JSON_OBJECT_T();
            v_resp_obj.put('codigo', -20000);
            v_resp_obj.put(
                'mensaje',
                'Se presento un error comunicarse con soporte. Número error: '
                || vro_error.id
            );
            v_resp_obj.put('id_usuario', v_id_usuario);
            p_json_salida := v_resp_obj.to_clob();
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

        v_obj_in := JSON_OBJECT_T.parse(p_json_entrada);
        IF v_obj_in.has('id_usuario') AND NOT v_obj_in.get('id_usuario').is_null THEN
            v_id_usuario := v_obj_in.get_number('id_usuario');
        ELSIF v_obj_in.has('id_profesional') AND NOT v_obj_in.get('id_profesional').is_null THEN
            v_id_usuario := v_obj_in.get_number('id_profesional');
        END IF;

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
                p_json_salida := f_formatear_error_json(SQLCODE, SQLERRM);
                RETURN;
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

        v_obj_in := JSON_OBJECT_T.parse(p_json_entrada);
        IF v_obj_in.has('id_usuario') AND NOT v_obj_in.get('id_usuario').is_null THEN
            v_id_usuario := v_obj_in.get_number('id_usuario');
        ELSIF v_obj_in.has('id_profesional') AND NOT v_obj_in.get('id_profesional').is_null THEN
            v_id_usuario := v_obj_in.get_number('id_profesional');
        END IF;
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
                v_resp_obj := JSON_OBJECT_T();
                v_resp_obj.put('codigo', SQLCODE);
                v_resp_obj.put('mensaje', f_limpiar_mensaje_error(SQLERRM));
                v_resp_obj.put('id_usuario', v_id_usuario);
                p_json_salida := v_resp_obj.to_clob();
                RETURN;
            END IF;

            vro_error.tipo            := 'E';
            vro_error.nombre_programa := 'PKGLN_HORARIOS';
            vro_error.nombre_metodo   := 'p_registrar_ausencia';
            vro_error.parametros      := p_json_entrada;
            vro_error.codigo_error    := TO_CHAR(SQLCODE);
            vro_error.texto_error     := DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
            vro_error.mensaje_error   := SUBSTR(SQLERRM, 1, 4000);

            uti_ge_excepciones_pkg.p_grabar_log(vro_error);

            v_resp_obj := JSON_OBJECT_T();
            v_resp_obj.put('codigo', -20000);
            v_resp_obj.put(
                'mensaje',
                'Se presento un error comunicarse con soporte. Número error: '
                || vro_error.id
            );
            v_resp_obj.put('id_usuario', v_id_usuario);
            p_json_salida := v_resp_obj.to_clob();
    END p_registrar_ausencia;

    -- 5. Consultar ausencias
    PROCEDURE p_consultar_ausencias (
        p_json_entrada IN  CLOB,
        p_json_salida  OUT CLOB
    ) IS
    BEGIN
        PKGCN_HORARIOS.p_consultar_ausencias_json(
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
                p_json_salida := f_formatear_error_json(SQLCODE, SQLERRM);
                RETURN;
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
        v_cant_ausencias   NUMBER := 0;
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

        -- Verificar si existen ausencias registradas para ese periodo para informar al usuario
        v_cant_ausencias := pkgca_tkr_ausencias_profesional.f_contar_ausencias_rango(
            p_id_usuario    => v_id_usuario,
            p_fecha_inicial => v_fecha_inicial,
            p_fecha_final   => v_fecha_final
        );

        -- Delegación del borrado de horarios a pkgca_tkr_horarios_profesional
        pkgca_tkr_horarios_profesional.p_borrar_x_rango_fechas(
            p_id_usuario    => v_id_usuario,
            p_fecha_inicial => v_fecha_inicial,
            p_fecha_final   => v_fecha_final
        );

        DECLARE
            v_json_sync_in  JSON_OBJECT_T := JSON_OBJECT_T();
            v_json_sync_out CLOB;
        BEGIN
            v_json_sync_in.put('id_usuario', v_id_usuario);
            v_json_sync_in.put('fecha_inicial', TO_CHAR(v_fecha_inicial, 'YYYY-MM-DD'));
            IF v_fecha_final IS NOT NULL THEN
                v_json_sync_in.put('fecha_final', TO_CHAR(v_fecha_final, 'YYYY-MM-DD'));
            END IF;
            p_sincornizar_agenda(
                p_json_entrada => v_json_sync_in.to_clob(),
                p_json_salida  => v_json_sync_out
            );
        END;

        p_do_commit('PKGLN_HORARIOS.p_eliminar_horarios_vigencia');

        v_resp_obj := JSON_OBJECT_T();
        v_resp_obj.put('codigo', 0);
        IF v_cant_ausencias > 0 THEN
            v_resp_obj.put('tiene_ausencias', 1);
            v_resp_obj.put('cantidad_ausencias', v_cant_ausencias);
            v_resp_obj.put(
                'mensaje',
                'Horarios de la vigencia eliminados exitosamente. Tenga en cuenta que existen '
                || v_cant_ausencias
                || ' ausencia(s) registrada(s) para este período; por favor verifique si amerita eliminarlas.'
            );
        ELSE
            v_resp_obj.put('tiene_ausencias', 0);
            v_resp_obj.put('cantidad_ausencias', 0);
            v_resp_obj.put('mensaje', 'Horarios de la vigencia eliminados exitosamente.');
        END IF;
        v_resp_obj.put('id_usuario', v_id_usuario);
        p_json_salida := v_resp_obj.to_clob();

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            IF SQLCODE BETWEEN -20999 AND -20001 THEN
                v_resp_obj := JSON_OBJECT_T();
                v_resp_obj.put('codigo', SQLCODE);
                v_resp_obj.put('mensaje', f_limpiar_mensaje_error(SQLERRM));
                v_resp_obj.put('id_usuario', v_id_usuario);
                p_json_salida := v_resp_obj.to_clob();
                RETURN;
            END IF;

            vro_error.tipo            := 'E';
            vro_error.nombre_programa := 'PKGLN_HORARIOS';
            vro_error.nombre_metodo   := 'p_eliminar_horarios_vigencia';
            vro_error.parametros      := p_json_entrada;
            vro_error.codigo_error    := TO_CHAR(SQLCODE);
            vro_error.texto_error     := DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
            vro_error.mensaje_error   := SUBSTR(SQLERRM, 1, 4000);

            uti_ge_excepciones_pkg.p_grabar_log(vro_error);

            v_resp_obj := JSON_OBJECT_T();
            v_resp_obj.put('codigo', -20000);
            v_resp_obj.put(
                'mensaje',
                'Se presento un error comunicarse con soporte. Número error: '
                || vro_error.id
            );
            v_resp_obj.put('id_usuario', v_id_usuario);
            p_json_salida := v_resp_obj.to_clob();
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

        DECLARE
            v_json_sync_in  JSON_OBJECT_T := JSON_OBJECT_T();
            v_json_sync_out CLOB;
        BEGIN
            v_json_sync_in.put('id_usuario', v_id_usuario);
            p_sincornizar_agenda(
                p_json_entrada => v_json_sync_in.to_clob(),
                p_json_salida  => v_json_sync_out
            );
        END;

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
                p_json_salida := f_formatear_error_json(SQLCODE, SQLERRM);
                RETURN;
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

    -- 9. Sincronizar agenda y slots considerando citas ocupadas en tkr_citas (id_estado_cita IN (2,3))
    PROCEDURE p_sincornizar_agenda (
        p_json_entrada IN  CLOB,
        p_json_salida  OUT CLOB
    ) IS
        v_obj_in                JSON_OBJECT_T;
        v_id_usuario            NUMBER(12);
        v_id_usuario_ejecutor   NUMBER(12);
        v_codigo_traza          VARCHAR2(100);
        v_ip_origen             VARCHAR2(50);
        v_fecha_ini_str         VARCHAR2(30);
        v_fecha_fin_str         VARCHAR2(30);
        v_fecha_esp_str         VARCHAR2(30);
        v_fecha_hoy             DATE;
        v_fecha_inicial         DATE;
        v_fecha_final           DATE;
        v_dias_sincronizados    NUMBER := 0;
        v_citas_ocupadas        NUMBER := 0;
        v_resp_obj              JSON_OBJECT_T;

        -- Variables de Telemetría (uti_manejo_trazas_pkg)
        v_traza_activa          BOOLEAN := FALSE;
        v_id_config_traza       NUMBER(12) := NULL;
        v_id_traza_ejecucion    NUMBER(12) := NULL;
        v_nivel_detalle_traza   VARCHAR2(30) := 'COMPLETO';
        v_grabar_payloads_traza NUMBER(1) := 1;
        v_fecha_inicio_traza    TIMESTAMP := SYSTIMESTAMP;

        -- Variables de Orquestación y Lógica de Negocio
        vro_parametro           tkr_parametros%ROWTYPE;
        v_dias_parametro        NUMBER := 60;
        v_f_ini                 DATE;
        v_f_fin                 DATE;
        v_f_cur                 DATE;
        v_dia_semana            VARCHAR2(10);
        v_trabaja_festivos      VARCHAR2(1) := 'N';
        v_es_festivo            BOOLEAN := FALSE;
        v_es_domingo            BOOLEAN := FALSE;
        v_tiene_ausencia        BOOLEAN := FALSE;
        v_tiene_por_dia         BOOLEAN := FALSE;
        v_tiene_personaliz      BOOLEAN := FALSE;
        v_tiene_base            BOOLEAN := FALSE;
        v_jerarquia_aplica      VARCHAR2(20) := 'NINGUNO';
        v_bitmap_ocupado        VARCHAR2(288);
        v_bitmap_disponible     VARCHAR2(288);
        v_slots_disponibles     NUMBER := 0;
        v_duracion_min          NUMBER := 20;
        v_min_ini               NUMBER;
        v_min_fin               NUMBER;
        v_idx_ini               NUMBER;
        v_idx_fin               NUMBER;
        v_actual                NUMBER;
        v_slot_fin              NUMBER;
        v_slot_ocupado          BOOLEAN;
        v_json_tiempo           JSON_OBJECT_T;

        -- Cursores y colecciones en memoria para citas y horarios
        v_cur_citas             SYS_REFCURSOR;
        v_cita_id               NUMBER;
        v_cita_ini              DATE;
        v_cita_fin              DATE;

        TYPE t_cita_rec IS RECORD (
            id                NUMBER,
            fecha_inicio_cita DATE,
            fecha_final_cita  DATE
        );
        TYPE t_citas_tab IS TABLE OF t_cita_rec INDEX BY BINARY_INTEGER;
        vta_citas               t_citas_tab;
        v_idx_c                 PLS_INTEGER := 0;

        v_cur_horarios          SYS_REFCURSOR;
        v_hor_id                NUMBER;
        v_hor_id_usu            NUMBER;
        v_hor_dia               VARCHAR2(10);
        v_hor_desde             VARCHAR2(10);
        v_hor_hasta             VARCHAR2(10);
        v_hor_f_ini_str         VARCHAR2(20);
        v_hor_f_fin_str         VARCHAR2(20);
        v_hor_aseg              NUMBER;
        v_hor_activo            NUMBER;

        TYPE t_hor_rec IS RECORD (
            id                    NUMBER,
            dia_semana            VARCHAR2(10),
            hora_desde            VARCHAR2(10),
            hora_hasta            VARCHAR2(10),
            fecha_inicial         DATE,
            fecha_final           DATE,
            id_tipo_aseguramiento NUMBER,
            tipo_vigencia         VARCHAR2(20)
        );
        TYPE t_hor_tab IS TABLE OF t_hor_rec INDEX BY BINARY_INTEGER;
        vta_horarios_dia        t_hor_tab;
        v_idx_h                 PLS_INTEGER := 0;

        FUNCTION f_hora_a_min (p_hora IN VARCHAR2) RETURN NUMBER IS
            v_h NUMBER;
            v_m NUMBER;
        BEGIN
            IF p_hora IS NULL OR INSTR(p_hora, ':') = 0 THEN
                RETURN 0;
            END IF;
            v_h := TO_NUMBER(SUBSTR(p_hora, 1, INSTR(p_hora, ':') - 1));
            v_m := TO_NUMBER(SUBSTR(p_hora, INSTR(p_hora, ':') + 1));
            RETURN (v_h * 60) + v_m;
        EXCEPTION
            WHEN OTHERS THEN
                RETURN 0;
        END f_hora_a_min;

        FUNCTION f_dia_semana_cod (p_fecha IN DATE) RETURN VARCHAR2 IS
            v_d VARCHAR2(20);
        BEGIN
            v_d := UPPER(SUBSTR(TRIM(TO_CHAR(p_fecha, 'DY', 'NLS_DATE_LANGUAGE=SPANISH')), 1, 2));
            CASE v_d
                WHEN 'LU' THEN RETURN 'LU';
                WHEN 'MA' THEN RETURN 'MA';
                WHEN 'MI' THEN RETURN 'MI';
                WHEN 'JU' THEN RETURN 'JU';
                WHEN 'VI' THEN RETURN 'VI';
                WHEN 'SÁ' THEN RETURN 'SA';
                WHEN 'SA' THEN RETURN 'SA';
                WHEN 'DO' THEN RETURN 'DO';
                ELSE RETURN 'LU';
            END CASE;
        END f_dia_semana_cod;
    BEGIN
        IF p_json_entrada IS NULL OR DBMS_LOB.GETLENGTH(p_json_entrada) = 0 THEN
            v_resp_obj := JSON_OBJECT_T();
            v_resp_obj.put('codigo', -20001);
            v_resp_obj.put('error', -20001);
            v_resp_obj.put('mensaje', 'El payload de entrada JSON no puede ser nulo.');
            p_json_salida := v_resp_obj.to_clob();
            RETURN;
        END IF;

        v_obj_in := JSON_OBJECT_T.parse(p_json_entrada);
        IF v_obj_in.has('id_usuario') AND NOT v_obj_in.get('id_usuario').is_null THEN
            v_id_usuario := v_obj_in.get_number('id_usuario');
        ELSIF v_obj_in.has('id_profesional') AND NOT v_obj_in.get('id_profesional').is_null THEN
            v_id_usuario := v_obj_in.get_number('id_profesional');
        END IF;

        IF v_id_usuario IS NULL THEN
            v_resp_obj := JSON_OBJECT_T();
            v_resp_obj.put('codigo', -20001);
            v_resp_obj.put('error', -20001);
            v_resp_obj.put('mensaje', 'El identificador del profesional (id_usuario) es obligatorio.');
            p_json_salida := v_resp_obj.to_clob();
            RETURN;
        END IF;

        IF v_obj_in.has('id_usuario_ejecutor') THEN
            v_id_usuario_ejecutor := v_obj_in.get_number('id_usuario_ejecutor');
        ELSE
            v_id_usuario_ejecutor := v_id_usuario;
        END IF;

        IF v_obj_in.has('codigo_traza') THEN
            v_codigo_traza := v_obj_in.get_string('codigo_traza');
        ELSE
            v_codigo_traza := RAWTOHEX(SYS_GUID());
        END IF;

        IF v_obj_in.has('ip_origen') THEN
            v_ip_origen := v_obj_in.get_string('ip_origen');
        ELSE
            v_ip_origen := SYS_CONTEXT('USERENV', 'IP_ADDRESS');
        END IF;

        IF v_obj_in.has('fecha') AND NOT v_obj_in.get('fecha').is_null THEN
            v_fecha_esp_str := TRIM(v_obj_in.get_string('fecha'));
            IF v_fecha_esp_str IS NOT NULL AND v_fecha_esp_str NOT IN ('null', 'undefined') THEN
                BEGIN
                    v_fecha_inicial := TO_DATE(v_fecha_esp_str, 'YYYY-MM-DD');
                    v_fecha_final   := v_fecha_inicial;
                EXCEPTION
                    WHEN OTHERS THEN
                        v_resp_obj := JSON_OBJECT_T();
                        v_resp_obj.put('codigo', -20005);
                        v_resp_obj.put('error', -20005);
                        v_resp_obj.put('mensaje', 'Formato de fecha inválido (' || v_fecha_esp_str || '). Se espera YYYY-MM-DD.');
                        p_json_salida := v_resp_obj.to_clob();
                        RETURN;
                END;
            END IF;
        END IF;

        IF v_obj_in.has('fecha_inicial') AND NOT v_obj_in.get('fecha_inicial').is_null THEN
            v_fecha_ini_str := TRIM(v_obj_in.get_string('fecha_inicial'));
            IF v_fecha_ini_str IS NOT NULL AND v_fecha_ini_str NOT IN ('null', 'undefined') THEN
                BEGIN
                    v_fecha_inicial := TO_DATE(v_fecha_ini_str, 'YYYY-MM-DD');
                EXCEPTION
                    WHEN OTHERS THEN
                        v_resp_obj := JSON_OBJECT_T();
                        v_resp_obj.put('codigo', -20005);
                        v_resp_obj.put('error', -20005);
                        v_resp_obj.put('mensaje', 'Formato de fecha_inicial inválido (' || v_fecha_ini_str || '). Se espera YYYY-MM-DD.');
                        p_json_salida := v_resp_obj.to_clob();
                        RETURN;
                END;
            END IF;
        END IF;

        IF v_obj_in.has('fecha_final') AND NOT v_obj_in.get('fecha_final').is_null THEN
            v_fecha_fin_str := TRIM(v_obj_in.get_string('fecha_final'));
            IF v_fecha_fin_str IS NOT NULL AND v_fecha_fin_str NOT IN ('null', 'undefined') THEN
                BEGIN
                    v_fecha_final := TO_DATE(v_fecha_fin_str, 'YYYY-MM-DD');
                EXCEPTION
                    WHEN OTHERS THEN
                        v_resp_obj := JSON_OBJECT_T();
                        v_resp_obj.put('codigo', -20005);
                        v_resp_obj.put('error', -20005);
                        v_resp_obj.put('mensaje', 'Formato de fecha_final inválido (' || v_fecha_fin_str || '). Se espera YYYY-MM-DD.');
                        p_json_salida := v_resp_obj.to_clob();
                        RETURN;
                END;
            END IF;
        END IF;

        -- PASO 1: Verificación obligatoria de trazabilidad
        v_traza_activa := uti_manejo_trazas_pkg.f_debe_trazar(
            p_nombre_paquete => 'PKGLN_HORARIOS',
            p_nombre_metodo  => 'p_sincornizar_agenda',
            p_id_usuario     => v_id_usuario_ejecutor,
            p_id_config_out  => v_id_config_traza,
            p_nivel_out      => v_nivel_detalle_traza,
            p_grabar_pay_out => v_grabar_payloads_traza
        );

        -- PASO 2: Apertura de traza si está habilitada
        IF v_traza_activa THEN
            uti_manejo_trazas_pkg.p_iniciar_traza(
                p_nombre_paquete   => 'PKGLN_HORARIOS',
                p_nombre_metodo    => 'p_sincornizar_agenda',
                p_id_config        => v_id_config_traza,
                p_id_usuario       => v_id_usuario_ejecutor,
                p_codigo_traza     => v_codigo_traza,
                p_ip_origen        => v_ip_origen,
                p_json_entrada     => p_json_entrada,
                p_grabar_payload   => v_grabar_payloads_traza,
                p_id_ejecucion_out => v_id_traza_ejecucion
            );
        END IF;

        -- PASO 3: Orquestación de negocio para sincronización de slots y citas ocupadas (desde f_fecha_actual en adelante)
        v_fecha_hoy := TRUNC(f_fecha_actual);
        v_f_ini     := GREATEST(v_fecha_hoy, TRUNC(NVL(v_fecha_inicial, v_fecha_hoy)));

        IF v_fecha_final IS NOT NULL THEN
            v_f_fin := TRUNC(v_fecha_final);
        ELSE
            v_dias_parametro := 60;
            IF pkgtkr_parametros_dao.f_existe(8, vro_parametro) THEN
                BEGIN
                    v_dias_parametro := NVL(TO_NUMBER(TRIM(vro_parametro.valor_parametro)), 60);
                EXCEPTION
                    WHEN OTHERS THEN
                        v_dias_parametro := 60;
                END;
            END IF;
            IF v_dias_parametro <= 0 THEN
                v_dias_parametro := 60;
            END IF;
            v_f_fin := v_f_ini + v_dias_parametro;
        END IF;

        v_trabaja_festivos := pkgca_tkr_usuarios.f_trabaja_festivos(v_id_usuario);

        v_json_tiempo := JSON_OBJECT_T();
        v_json_tiempo.put('id_usuario', v_id_usuario);
        v_json_tiempo.put('id_tipo_aseguramiento', 1);
        v_json_tiempo.put('modalidad', 'V');
        v_duracion_min := NVL(pkgca_tkr_tiempos_atencion.f_obtener_duracion_cita(v_json_tiempo.to_clob()), 20);
        IF v_duracion_min <= 0 THEN
            v_duracion_min := 20;
        END IF;

        -- Cargar citas ocupadas (id_estado_cita IN (2,3)) en el rango mediante PKGCN_HORARIOS
        v_cur_citas := PKGCN_HORARIOS.f_consultar_citas_ocupadas(
            p_id_usuario    => v_id_usuario,
            p_fecha_inicial => v_f_ini,
            p_fecha_final   => v_f_fin
        );
        LOOP
            FETCH v_cur_citas INTO v_cita_id, v_cita_ini, v_cita_fin;
            EXIT WHEN v_cur_citas%NOTFOUND;
            v_idx_c := v_idx_c + 1;
            vta_citas(v_idx_c).id                := v_cita_id;
            vta_citas(v_idx_c).fecha_inicio_cita := v_cita_ini;
            vta_citas(v_idx_c).fecha_final_cita  := NVL(v_cita_fin, v_cita_ini + (v_duracion_min / 1440));
        END LOOP;
        CLOSE v_cur_citas;

        v_f_cur := v_f_ini;
        WHILE v_f_cur <= v_f_fin LOOP
            v_bitmap_ocupado    := RPAD('0', 288, '0');
            v_bitmap_disponible := RPAD('0', 288, '0');
            v_slots_disponibles := 0;

            -- 3.1 Marcar slots ocupados según citas entre fecha_inicio_cita y fecha_final_cita
            FOR c IN 1 .. v_idx_c LOOP
                IF vta_citas(c).fecha_inicio_cita <= (v_f_cur + 1 - (1 / 86400))
                   AND vta_citas(c).fecha_final_cita >= v_f_cur THEN
                    v_citas_ocupadas := v_citas_ocupadas + 1;

                    IF TRUNC(vta_citas(c).fecha_inicio_cita) < v_f_cur THEN
                        v_min_ini := 0;
                    ELSE
                        v_min_ini := TO_NUMBER(TO_CHAR(vta_citas(c).fecha_inicio_cita, 'HH24')) * 60
                                   + TO_NUMBER(TO_CHAR(vta_citas(c).fecha_inicio_cita, 'MI'));
                    END IF;

                    IF TRUNC(vta_citas(c).fecha_final_cita) > v_f_cur THEN
                        v_min_fin := 1440;
                    ELSE
                        v_min_fin := TO_NUMBER(TO_CHAR(vta_citas(c).fecha_final_cita, 'HH24')) * 60
                                   + TO_NUMBER(TO_CHAR(vta_citas(c).fecha_final_cita, 'MI'));
                    END IF;

                    IF v_min_fin <= v_min_ini THEN
                        v_min_fin := v_min_ini + v_duracion_min;
                    END IF;

                    v_idx_ini := GREATEST(1, LEAST(288, TRUNC(v_min_ini / 5) + 1));
                    v_idx_fin := GREATEST(v_idx_ini, LEAST(288, TRUNC((v_min_fin + 4) / 5)));

                    FOR b_idx IN v_idx_ini .. v_idx_fin LOOP
                        v_bitmap_ocupado := SUBSTR(v_bitmap_ocupado, 1, b_idx - 1) || '1' || SUBSTR(v_bitmap_ocupado, b_idx + 1);
                    END LOOP;
                END IF;
            END LOOP;

            -- 3.2 Evaluar horarios vigentes de la fecha y generar slots libres
            v_dia_semana       := f_dia_semana_cod(v_f_cur);
            v_es_domingo       := (v_dia_semana = 'DO');
            v_es_festivo       := pkgca_tkr_festivos.f_es_festivo(v_f_cur, 1);
            v_tiene_ausencia   := pkgca_tkr_ausencias_profesional.f_existe_ausencia(v_id_usuario, v_f_cur, v_f_cur);
            v_tiene_por_dia    := FALSE;
            v_tiene_personaliz := FALSE;
            v_tiene_base       := FALSE;
            v_jerarquia_aplica := 'NINGUNO';
            vta_horarios_dia.DELETE;
            v_idx_h            := 0;

            IF NOT v_tiene_ausencia THEN
                v_cur_horarios := pkgca_tkr_horarios_profesional.f_consultar_vigentes_fecha(
                    p_id_usuario => v_id_usuario,
                    p_fecha      => v_f_cur
                );
                LOOP
                    FETCH v_cur_horarios INTO v_hor_id, v_hor_id_usu, v_hor_dia, v_hor_desde, v_hor_hasta, v_hor_f_ini_str, v_hor_f_fin_str, v_hor_aseg, v_hor_activo;
                    EXIT WHEN v_cur_horarios%NOTFOUND;

                    IF UPPER(TRIM(v_hor_dia)) = v_dia_semana THEN
                        v_idx_h := v_idx_h + 1;
                        vta_horarios_dia(v_idx_h).id                    := v_hor_id;
                        vta_horarios_dia(v_idx_h).dia_semana            := UPPER(TRIM(v_hor_dia));
                        vta_horarios_dia(v_idx_h).hora_desde            := v_hor_desde;
                        vta_horarios_dia(v_idx_h).hora_hasta            := v_hor_hasta;
                        vta_horarios_dia(v_idx_h).fecha_inicial         := TO_DATE(v_hor_f_ini_str, 'YYYY-MM-DD');
                        vta_horarios_dia(v_idx_h).id_tipo_aseguramiento := NVL(v_hor_aseg, 1);

                        IF v_hor_f_fin_str IS NOT NULL THEN
                            vta_horarios_dia(v_idx_h).fecha_final := TO_DATE(v_hor_f_fin_str, 'YYYY-MM-DD');
                            IF TRUNC(vta_horarios_dia(v_idx_h).fecha_inicial) = TRUNC(vta_horarios_dia(v_idx_h).fecha_final) THEN
                                vta_horarios_dia(v_idx_h).tipo_vigencia := 'POR_DIA';
                                v_tiene_por_dia := TRUE;
                            ELSE
                                vta_horarios_dia(v_idx_h).tipo_vigencia := 'PERSONALIZADO';
                                v_tiene_personaliz := TRUE;
                            END IF;
                        ELSE
                            vta_horarios_dia(v_idx_h).fecha_final   := NULL;
                            vta_horarios_dia(v_idx_h).tipo_vigencia := 'BASE';
                            v_tiene_base := TRUE;
                        END IF;
                    END IF;
                END LOOP;
                CLOSE v_cur_horarios;

                IF v_tiene_por_dia THEN
                    v_jerarquia_aplica := 'POR_DIA';
                ELSIF NOT ((v_es_domingo OR v_es_festivo) AND v_trabaja_festivos = 'N') THEN
                    IF v_tiene_personaliz THEN
                        v_jerarquia_aplica := 'PERSONALIZADO';
                    ELSIF v_tiene_base THEN
                        v_jerarquia_aplica := 'BASE';
                    END IF;
                END IF;

                IF v_jerarquia_aplica <> 'NINGUNO' THEN
                    FOR h IN 1 .. v_idx_h LOOP
                        IF vta_horarios_dia(h).tipo_vigencia = v_jerarquia_aplica THEN
                            v_min_ini := f_hora_a_min(vta_horarios_dia(h).hora_desde);
                            v_min_fin := f_hora_a_min(vta_horarios_dia(h).hora_hasta);
                            v_actual  := v_min_ini;

                            WHILE (v_actual + v_duracion_min) <= v_min_fin LOOP
                                v_slot_fin := v_actual + v_duracion_min;
                                v_idx_ini  := GREATEST(1, LEAST(288, TRUNC(v_actual / 5) + 1));
                                v_idx_fin  := GREATEST(v_idx_ini, LEAST(288, TRUNC(v_slot_fin / 5)));

                                v_slot_ocupado := FALSE;
                                FOR b_idx IN v_idx_ini .. v_idx_fin LOOP
                                    IF SUBSTR(v_bitmap_ocupado, b_idx, 1) = '1' THEN
                                        v_slot_ocupado := TRUE;
                                        EXIT;
                                    END IF;
                                END LOOP;

                                IF NOT v_slot_ocupado THEN
                                    FOR b_idx IN v_idx_ini .. v_idx_fin LOOP
                                        v_bitmap_disponible := SUBSTR(v_bitmap_disponible, 1, b_idx - 1) || '1' || SUBSTR(v_bitmap_disponible, b_idx + 1);
                                    END LOOP;
                                    v_slots_disponibles := v_slots_disponibles + 1;
                                END IF;

                                v_actual := v_slot_fin;
                            END LOOP;
                        END IF;
                    END LOOP;
                END IF;
            END IF;

            -- 3.3 Invocar método DML de única instrucción en PKGCN_HORARIOS
            PKGCN_HORARIOS.p_sincronizar_agenda_slots(
                p_id_usuario            => v_id_usuario,
                p_fecha                 => v_f_cur,
                p_id_convenio           => NULL,
                p_id_tipo_aseguramiento => 1,
                p_modalidad             => 'V',
                p_bitmap_disponible     => v_bitmap_disponible,
                p_bitmap_ocupado        => v_bitmap_ocupado,
                p_slots_disponibles     => v_slots_disponibles
            );

            v_dias_sincronizados := v_dias_sincronizados + 1;
            v_f_cur              := v_f_cur + 1;
        END LOOP;

        -- PASO 4: Confirmación controlada de transacción
        p_do_commit('PKGLN_HORARIOS.p_sincornizar_agenda');

        v_resp_obj := JSON_OBJECT_T();
        v_resp_obj.put('codigo', 0);
        v_resp_obj.put('mensaje', 'Agenda y slots sincronizados exitosamente.');
        v_resp_obj.put('id_usuario', v_id_usuario);
        v_resp_obj.put('dias_sincronizados', v_dias_sincronizados);
        v_resp_obj.put('citas_ocupadas', v_citas_ocupadas);
        p_json_salida := v_resp_obj.to_clob();

        -- PASO 5: Cierre exitoso de la traza
        IF v_traza_activa AND v_id_traza_ejecucion IS NOT NULL THEN
            uti_manejo_trazas_pkg.p_finalizar_traza(
                p_id_ejecucion   => v_id_traza_ejecucion,
                p_fecha_inicio   => v_fecha_inicio_traza,
                p_json_salida    => p_json_salida,
                p_grabar_payload => v_grabar_payloads_traza
            );
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;

            IF v_traza_activa AND v_id_traza_ejecucion IS NOT NULL THEN
                uti_manejo_trazas_pkg.p_finalizar_traza_error(
                    p_id_ejecucion  => v_id_traza_ejecucion,
                    p_fecha_inicio  => v_fecha_inicio_traza,
                    p_codigo_error  => SQLCODE,
                    p_mensaje_error => SQLERRM
                );
            END IF;

            vro_error.tipo            := 'E';
            vro_error.nombre_programa := 'PKGLN_HORARIOS';
            vro_error.nombre_metodo   := 'p_sincornizar_agenda';
            vro_error.parametros      := p_json_entrada;
            vro_error.codigo_error    := TO_CHAR(SQLCODE);
            vro_error.texto_error     := DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
            vro_error.mensaje_error   := SUBSTR(SQLERRM, 1, 4000);

            uti_ge_excepciones_pkg.p_grabar_log(vro_error);

            v_resp_obj := JSON_OBJECT_T();
            v_resp_obj.put('codigo', -20000);
            v_resp_obj.put('error', -20000);
            v_resp_obj.put(
                'mensaje',
                'Se presento un error comunicarse con soporte. Número error: '
                || vro_error.id
            );
            v_resp_obj.put('id_usuario', v_id_usuario);
            p_json_salida := v_resp_obj.to_clob();
    END p_sincornizar_agenda;

    PROCEDURE p_sincornizar_agenda (
        p_id_profesional IN NUMBER,
        p_fecha          IN DATE DEFAULT NULL
    ) IS
        v_json_in  JSON_OBJECT_T := JSON_OBJECT_T();
        v_json_out CLOB;
    BEGIN
        v_json_in.put('id_profesional', p_id_profesional);
        IF p_fecha IS NOT NULL THEN
            v_json_in.put('fecha', TO_CHAR(TRUNC(p_fecha), 'YYYY-MM-DD'));
        END IF;
        p_sincornizar_agenda(
            p_json_entrada => v_json_in.to_clob(),
            p_json_salida  => v_json_out
        );
    END p_sincornizar_agenda;

    PROCEDURE p_sincronizar_agenda (
        p_json_entrada IN  CLOB,
        p_json_salida  OUT CLOB
    ) IS
    BEGIN
        p_sincornizar_agenda(
            p_json_entrada => p_json_entrada,
            p_json_salida  => p_json_salida
        );
    END p_sincronizar_agenda;

    PROCEDURE p_sincronizar_agenda (
        p_id_profesional IN NUMBER,
        p_fecha          IN DATE DEFAULT NULL
    ) IS
    BEGIN
        p_sincornizar_agenda(
            p_id_profesional => p_id_profesional,
            p_fecha          => p_fecha
        );
    END p_sincronizar_agenda;

    -- =========================================================================
    -- ALIAS DE COMPATIBILIDAD
    -- =========================================================================
    PROCEDURE p_actualizar_ausencia (
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

        p_do_commit('PKGLN_HORARIOS.p_actualizar_ausencia');

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
            vro_error.nombre_metodo   := 'p_actualizar_ausencia';
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
    END p_actualizar_ausencia;

    PROCEDURE p_obtener_ausencias (
        p_json      IN  CLOB,
        p_resultado OUT CLOB
    ) IS
    BEGIN
        p_consultar_ausencias(p_json, p_resultado);
    END p_obtener_ausencias;

END PKGLN_HORARIOS;
/
