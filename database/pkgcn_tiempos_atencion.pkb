CREATE OR REPLACE PACKAGE BODY pkgcn_tiempos_atencion AS
    /*
    || =========================================================================
    || Paquete: pkgcn_tiempos_atencion
    || Propósito: Capa de Casos de Negocio para la gestión de Tiempos de Atención
    ||            por profesional y tipo de aseguramiento.
    || Estándar: oracle-plsql-architecture
    || =========================================================================
    */

    -- 1. Consultar tiempos de atención de un profesional en formato JSON
    PROCEDURE p_consultar_tiempos_json (
        p_id_usuario  IN  NUMBER,
        p_json_salida OUT CLOB
    ) IS
    BEGIN
        SELECT JSON_OBJECT(
                   'codigo'  VALUE 0,
                   'mensaje' VALUE 'Tiempos de atención consultados exitosamente',
                   'tiempos' VALUE COALESCE(
                       JSON_ARRAYAGG(
                           JSON_OBJECT(
                               'id'                    VALUE ta.id,
                               'id_usuario'            VALUE p_id_usuario,
                               'id_tipo_aseguramiento' VALUE t.id,
                               'tipo_aseguramiento'    VALUE t.tipo_aseguramiento,
                               'duracion'              VALUE ta.duracion,
                               'duracion_domiciliaria' VALUE ta.duracion_domiciliaria,
                               'configurado'           VALUE CASE WHEN ta.id IS NOT NULL THEN 1 ELSE 0 END,
                               'activo'                VALUE NVL(ta.activo, 1)
                           )
                           ORDER BY t.id ASC
                       ),
                       JSON_ARRAY()
                   )
                   RETURNING CLOB
               )
          INTO p_json_salida
          FROM tkr_tipos_aseguramiento t
          LEFT JOIN tkr_tiempos_atencion ta
            ON ta.id_tipo_aseguramiento = t.id
           AND ta.id_usuario = p_id_usuario
           AND ta.activo = 1;
    END p_consultar_tiempos_json;

    -- 2. Guardar o actualizar (Merge) tiempos de atención para un profesional
    PROCEDURE p_guardar_tiempos_profesional (
        p_id_usuario   IN NUMBER,
        p_json_tiempos IN CLOB
    ) IS
    BEGIN
        MERGE INTO tkr_tiempos_atencion dest
        USING (
            SELECT p_id_usuario                 AS id_usuario,
                   jt.id_tipo_aseguramiento     AS id_tipo_aseguramiento,
                   jt.duracion                  AS duracion,
                   jt.duracion_domiciliaria     AS duracion_domiciliaria
              FROM JSON_TABLE(p_json_tiempos, '$.tiempos[*]'
                       COLUMNS (
                           id_tipo_aseguramiento NUMBER PATH '$.id_tipo_aseguramiento',
                           duracion              NUMBER PATH '$.duracion',
                           duracion_domiciliaria NUMBER PATH '$.duracion_domiciliaria'
                       )
                   ) jt
             WHERE jt.id_tipo_aseguramiento IS NOT NULL
               AND (
                   (jt.duracion IS NOT NULL AND jt.duracion > 0) OR
                   (jt.duracion_domiciliaria IS NOT NULL AND jt.duracion_domiciliaria > 0)
               )
        ) src
        ON (dest.id_usuario = src.id_usuario AND dest.id_tipo_aseguramiento = src.id_tipo_aseguramiento)
        WHEN MATCHED THEN
            UPDATE SET dest.duracion                = NVL(src.duracion, dest.duracion),
                       dest.duracion_domiciliaria   = src.duracion_domiciliaria,
                       dest.activo                  = 1,
                       dest.fecha_modificacion      = SYSDATE
        WHEN NOT MATCHED THEN
            INSERT (
                id,
                id_usuario,
                id_tipo_aseguramiento,
                duracion,
                duracion_domiciliaria,
                activo,
                fecha_creacion
            )
            VALUES (
                tkr_tiempos_atencion_seq.NEXTVAL,
                src.id_usuario,
                src.id_tipo_aseguramiento,
                NVL(src.duracion, 20),
                src.duracion_domiciliaria,
                1,
                SYSDATE
            );
    END p_guardar_tiempos_profesional;

    -- 3. Eliminar la configuración de tiempo de atención para un tipo de aseguramiento
    PROCEDURE p_eliminar_tiempo_profesional (
        p_id_usuario             IN NUMBER,
        p_id_tipo_aseguramiento IN NUMBER
    ) IS
    BEGIN
        DELETE FROM tkr_tiempos_atencion
         WHERE id_usuario = p_id_usuario
           AND id_tipo_aseguramiento = p_id_tipo_aseguramiento;
    END p_eliminar_tiempo_profesional;

END pkgcn_tiempos_atencion;
/
