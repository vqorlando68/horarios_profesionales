CREATE OR REPLACE PACKAGE BODY pkgcn_franjas AS
    /*
    || =========================================================================
    || Paquete: pkgcn_franjas (BODY)
    || Propósito: Implementación de lógica de negocio para franjas de atención.
    || Estándar: oracle-plsql-architecture
    || =========================================================================
    */

    -- 1. Validar traslape entre franjas de atención
    FUNCTION f_existe_traslape_franja (
        p_id_usuario         IN NUMBER,
        p_dia_semana         IN VARCHAR2,
        p_hora_desde         IN VARCHAR2,
        p_hora_hasta         IN VARCHAR2,
        p_fecha_inicial      IN DATE,
        p_fecha_final        IN DATE DEFAULT NULL,
        p_id_franja_excluir  IN NUMBER DEFAULT NULL
    ) RETURN BOOLEAN IS
        v_conteo    NUMBER := 0;
        v_fin_nuevo DATE;
    BEGIN
        -- Regla de Negocio: Las franjas sin fecha_final (Franja Base) no realizan validaciones
        -- de traslape contra franjas con fecha_final. Solo se rigen por unicidad.
        IF p_fecha_final IS NULL THEN
            RETURN FALSE;
        END IF;

        v_fin_nuevo := p_fecha_final;

        -- Para franjas personalizadas (con fecha_final), solo se valida traslape contra otras franjas personalizadas
        SELECT COUNT(*)
          INTO v_conteo
          FROM tkr_franjas_profesional h
         WHERE h.id_usuario = p_id_usuario
           AND h.dia_semana = UPPER(TRIM(p_dia_semana))
           AND h.activo = 1
           AND (p_id_franja_excluir IS NULL OR h.id <> p_id_franja_excluir)
           AND h.fecha_final IS NOT NULL
           -- 1. Intersección de rangos de fechas (vigencia)
           AND p_fecha_inicial <= h.fecha_final
           AND v_fin_nuevo     >= h.fecha_inicial
           -- 2. Intersección de rangos de horas dentro del mismo día
           AND p_hora_desde < h.hora_hasta
           AND p_hora_hasta > h.hora_desde;

        RETURN (v_conteo > 0);
    END f_existe_traslape_franja;

    -- 2. Desestructuración e inserción masiva de franjas
    PROCEDURE p_guardar_franjas_profesional (
        p_id_usuario   IN NUMBER,
        p_json_franjas IN CLOB
    ) IS
    BEGIN
        INSERT INTO tkr_franjas_profesional (
            id,
            id_usuario,
            dia_semana,
            hora_desde,
            hora_hasta,
            fecha_inicial,
            fecha_final,
            id_tipo_aseguramiento,
            modalidad,
            activo,
            fecha_creacion
        )
        SELECT tkr_franjas_profesional_seq.NEXTVAL,
               p_id_usuario,
               UPPER(TRIM(jt.dia_semana)),
               TRIM(jt.hora_desde),
               TRIM(jt.hora_hasta),
               TO_DATE(TRIM(jt.fecha_inicial), 'YYYY-MM-DD'),
               CASE 
                   WHEN TRIM(jt.fecha_final) IS NOT NULL 
                   THEN TO_DATE(TRIM(jt.fecha_final), 'YYYY-MM-DD')
                   ELSE NULL
               END,
               NVL(jt.id_tipo_aseguramiento, CASE WHEN UPPER(TRIM(jt.tipo_atencion)) = 'O' THEN 2 ELSE 1 END),
               CASE 
                   WHEN UPPER(TRIM(jt.modalidad)) IN ('V', 'D') THEN UPPER(TRIM(jt.modalidad))
                   ELSE NULL
               END,
               1,
               SYSDATE
          FROM JSON_TABLE(p_json_franjas, '$.franjas[*]'
                   COLUMNS (
                       dia_semana    VARCHAR2(10) PATH '$.dia_semana',
                       hora_desde    VARCHAR2(10) PATH '$.hora_desde',
                       hora_hasta    VARCHAR2(10) PATH '$.hora_hasta',
                       fecha_inicial VARCHAR2(20) PATH '$.fecha_inicial',
                       fecha_final   VARCHAR2(20) PATH '$.fecha_final',
                       id_tipo_aseguramiento NUMBER       PATH '$.id_tipo_aseguramiento',
                       tipo_atencion         VARCHAR2(10) PATH '$.tipo_atencion',
                       modalidad             VARCHAR2(10) PATH '$.modalidad'
                   )
               ) jt;
    END p_guardar_franjas_profesional;

    -- 3. Consultar franjas de un profesional formateado en JSON CLOB
    PROCEDURE p_consultar_franjas_json (
        p_id_usuario  IN  NUMBER,
        p_json_salida OUT CLOB
    ) IS
    BEGIN
        SELECT JSON_OBJECT(
                   'codigo'  VALUE 0,
                   'mensaje' VALUE 'Franjas de atención consultadas exitosamente',
                   'franjas' VALUE COALESCE(
                       JSON_ARRAYAGG(
                           JSON_OBJECT(
                               'id'            VALUE h.id,
                               'dia_semana'    VALUE h.dia_semana,
                               'hora_desde'    VALUE h.hora_desde,
                               'hora_hasta'    VALUE h.hora_hasta,
                               'fecha_inicial' VALUE TO_CHAR(h.fecha_inicial, 'YYYY-MM-DD'),
                               'fecha_final'   VALUE TO_CHAR(h.fecha_final, 'YYYY-MM-DD'),
                               'id_tipo_aseguramiento' VALUE NVL(h.id_tipo_aseguramiento, 1),
                               'tipo_atencion'         VALUE (CASE WHEN NVL(h.id_tipo_aseguramiento, 1) = 2 THEN 'O' ELSE 'V' END),
                               'tipo_aseguramiento'    VALUE (CASE WHEN NVL(h.id_tipo_aseguramiento, 1) = 2 THEN 'Obligatorio' ELSE 'Voluntario' END),
                               'modalidad'             VALUE h.modalidad,
                               'activo'        VALUE h.activo
                           )
                           ORDER BY CASE h.dia_semana
                                        WHEN 'LU' THEN 1
                                        WHEN 'MA' THEN 2
                                        WHEN 'MI' THEN 3
                                        WHEN 'JU' THEN 4
                                        WHEN 'VI' THEN 5
                                        WHEN 'SA' THEN 6
                                        WHEN 'DO' THEN 7
                                        ELSE 8
                                    END,
                                    h.hora_desde
                       ),
                       JSON_ARRAY()
                   )
                   RETURNING CLOB
               )
          INTO p_json_salida
          FROM tkr_franjas_profesional h
         WHERE h.id_usuario = p_id_usuario
           AND h.activo = 1;
    END p_consultar_franjas_json;

END pkgcn_franjas;
/
