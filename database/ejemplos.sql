-- =============================================================================
-- ARCHIVO: ejemplos.sql
-- PROPÓSITO: Bloques anónimos PL/SQL de ejemplo para cada método de PKGLN_HORARIOS
-- =============================================================================
SET SERVEROUTPUT ON SIZE UNLIMITED;

-- =============================================================================
-- 1. PKGLN_HORARIOS.p_listar_profesionales
-- =============================================================================
DECLARE
    v_json_entrada CLOB;
    v_json_salida  CLOB;
BEGIN
    v_json_entrada := '{
        "filtro": ""
    }';

    PKGLN_HORARIOS.p_listar_profesionales(
        p_json_entrada => v_json_entrada,
        p_json_salida  => v_json_salida
    );

    DBMS_OUTPUT.PUT_LINE('1. p_listar_profesionales -> ' || SUBSTR(v_json_salida, 1, 4000));
END;
/

-- =============================================================================
-- 2. PKGLN_HORARIOS.p_guardar_horarios
-- =============================================================================
DECLARE
    v_json_entrada CLOB;
    v_json_salida  CLOB;
BEGIN
    v_json_entrada := '{
        "id_usuario": 47,
        "reemplazar_todo": 0,
        "reemplazar_vigencia": 1,
        "horarios": [
            {
                "dia_semana": "LU",
                "hora_desde": "08:00",
                "hora_hasta": "12:00",
                "fecha_inicial": "2026-11-01",
                "fecha_final": "2026-11-30",
                "id_convenio": null
            },
            {
                "dia_semana": "LU",
                "hora_desde": "14:00",
                "hora_hasta": "18:00",
                "fecha_inicial": "2026-11-01",
                "fecha_final": "2026-11-30",
                "id_convenio": null
            }
        ],
        "festivos_no_laborables": []
    }';

    PKGLN_HORARIOS.p_guardar_horarios(
        p_json_entrada => v_json_entrada,
        p_json_salida  => v_json_salida
    );

    DBMS_OUTPUT.PUT_LINE('2. p_guardar_horarios -> ' || v_json_salida);
END;
/

-- =============================================================================
-- 3. PKGLN_HORARIOS.p_consultar_agenda
-- =============================================================================
DECLARE
    v_json_entrada CLOB;
    v_json_salida  CLOB;
BEGIN
    v_json_entrada := '{
        "id_usuario": 47
    }';

    PKGLN_HORARIOS.p_consultar_agenda(
        p_json_entrada => v_json_entrada,
        p_json_salida  => v_json_salida
    );

    DBMS_OUTPUT.PUT_LINE('3. p_consultar_agenda -> ' || SUBSTR(v_json_salida, 1, 4000));
END;
/

-- =============================================================================
-- 4. PKGLN_HORARIOS.p_registrar_ausencia
-- =============================================================================
DECLARE
    v_json_entrada CLOB;
    v_json_salida  CLOB;
BEGIN
    v_json_entrada := '{
        "id_usuario": 47,
        "fecha_inicial": "2026-11-15",
        "fecha_final": "2026-11-16"
    }';

    PKGLN_HORARIOS.p_registrar_ausencia(
        p_json_entrada => v_json_entrada,
        p_json_salida  => v_json_salida
    );

    DBMS_OUTPUT.PUT_LINE('4. p_registrar_ausencia -> ' || v_json_salida);
END;
/

-- =============================================================================
-- 5. PKGLN_HORARIOS.p_consultar_ausencias
-- =============================================================================
DECLARE
    v_json_entrada CLOB;
    v_json_salida  CLOB;
BEGIN
    v_json_entrada := '{
        "id_usuario": 47,
        "fecha_inicial": "2026-11-01",
        "fecha_final": "2026-11-30"
    }';

    PKGLN_HORARIOS.p_consultar_ausencias(
        p_json_entrada => v_json_entrada,
        p_json_salida  => v_json_salida
    );

    DBMS_OUTPUT.PUT_LINE('5. p_consultar_ausencias -> ' || v_json_salida);
END;
/

-- =============================================================================
-- 6. PKGLN_HORARIOS.p_eliminar_ausencia
-- =============================================================================
DECLARE
    v_json_entrada CLOB;
    v_json_salida  CLOB;
BEGIN
    v_json_entrada := '{
        "id": 1
    }';

    PKGLN_HORARIOS.p_eliminar_ausencia(
        p_json_entrada => v_json_entrada,
        p_json_salida  => v_json_salida
    );

    DBMS_OUTPUT.PUT_LINE('6. p_eliminar_ausencia -> ' || v_json_salida);
END;
/

-- =============================================================================
-- 7. PKGLN_HORARIOS.p_eliminar_horarios_vigencia
-- =============================================================================
DECLARE
    v_json_entrada CLOB;
    v_json_salida  CLOB;
BEGIN
    v_json_entrada := '{
        "id_usuario": 47,
        "fecha_inicial": "2026-11-01",
        "fecha_final": "2026-11-30",
        "trabaja_festivos": "N"
    }';

    PKGLN_HORARIOS.p_eliminar_horarios_vigencia(
        p_json_entrada => v_json_entrada,
        p_json_salida  => v_json_salida
    );

    DBMS_OUTPUT.PUT_LINE('7. p_eliminar_horarios_vigencia -> ' || v_json_salida);
END;
/

-- =============================================================================
-- 8. PKGLN_HORARIOS.p_actualizar_trabaja_festivos
-- =============================================================================
DECLARE
    v_json_entrada CLOB;
    v_json_salida  CLOB;
BEGIN
    v_json_entrada := '{
        "id_usuario": 47,
        "trabaja_festivos": "S",
        "borrar_domingos": 0
    }';

    PKGLN_HORARIOS.p_actualizar_trabaja_festivos(
        p_json_entrada => v_json_entrada,
        p_json_salida  => v_json_salida
    );

    DBMS_OUTPUT.PUT_LINE('8. p_actualizar_trabaja_festivos -> ' || v_json_salida);
END;
/

-- =============================================================================
-- 9A. PKGLN_HORARIOS.p_sincronizar_agenda (Por rango JSON desde f_fecha_actual)
-- =============================================================================
DECLARE
    v_json_entrada CLOB;
    v_json_salida  CLOB;
BEGIN
    v_json_entrada := '{
        "id_usuario": 47,
        "fecha_inicial": "2026-11-01",
        "fecha_final": "2026-11-30"
    }';

    PKGLN_HORARIOS.p_sincronizar_agenda(
        p_json_entrada => v_json_entrada,
        p_json_salida  => v_json_salida
    );

    DBMS_OUTPUT.PUT_LINE('9A. p_sincronizar_agenda (rango JSON) -> ' || v_json_salida);
END;
/

-- =============================================================================
-- 9B. PKGLN_HORARIOS.p_sincronizar_agenda (Por id_profesional y día específico en JSON)
-- =============================================================================
DECLARE
    v_json_entrada CLOB;
    v_json_salida  CLOB;
BEGIN
    v_json_entrada := '{
        "id_profesional": 47,
        "fecha": "2026-11-05"
    }';

    PKGLN_HORARIOS.p_sincronizar_agenda(
        p_json_entrada => v_json_entrada,
        p_json_salida  => v_json_salida
    );

    DBMS_OUTPUT.PUT_LINE('9B. p_sincronizar_agenda (día específico JSON) -> ' || v_json_salida);
END;
/

-- =============================================================================
-- 9C. PKGLN_HORARIOS.p_sincronizar_agenda (Sobrecarga directa con id_profesional y fecha DATE)
-- =============================================================================
BEGIN
    PKGLN_HORARIOS.p_sincronizar_agenda(
        p_id_profesional => 47,
        p_fecha          => TO_DATE('2026-11-05', 'YYYY-MM-DD')
    );

    DBMS_OUTPUT.PUT_LINE('9C. p_sincronizar_agenda (sobrecarga DATE) ejecutado.');
END;
/

-- =============================================================================
-- 10. PKGLN_HORARIOS.p_actualizar_ausencia
-- =============================================================================
DECLARE
    v_json_entrada CLOB;
    v_json_salida  CLOB;
BEGIN
    v_json_entrada := '{
        "id": 1,
        "id_usuario": 47,
        "fecha_inicial": "2026-11-18",
        "fecha_final": "2026-11-19"
    }';

    PKGLN_HORARIOS.p_actualizar_ausencia(
        p_json      => v_json_entrada,
        p_resultado => v_json_salida
    );

    DBMS_OUTPUT.PUT_LINE('10. p_actualizar_ausencia -> ' || v_json_salida);
END;
/

-- =============================================================================
-- 11. PKGLN_HORARIOS.p_obtener_ausencias
-- =============================================================================
DECLARE
    v_json_entrada CLOB;
    v_json_salida  CLOB;
BEGIN
    v_json_entrada := '{
        "id_usuario": 47,
        "fecha_inicial": "2026-11-01",
        "fecha_final": "2026-11-30"
    }';

    PKGLN_HORARIOS.p_obtener_ausencias(
        p_json      => v_json_entrada,
        p_resultado => v_json_salida
    );

    DBMS_OUTPUT.PUT_LINE('11. p_obtener_ausencias -> ' || v_json_salida);
END;
/

-- =============================================================================
-- 12. PKGLN_HORARIOS.p_actualizar_agenda
-- =============================================================================
BEGIN
    PKGLN_HORARIOS.p_actualizar_agenda;
    DBMS_OUTPUT.PUT_LINE('12. p_actualizar_agenda ejecutado.');
END;
/

