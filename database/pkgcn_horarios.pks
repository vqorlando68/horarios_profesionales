CREATE OR REPLACE PACKAGE PKGCN_HORARIOS
AS
    /*
    || =========================================================================
    || Paquete: PKGCN_HORARIOS
    || Propósito: Capa Multi-Tabla de Casos de Negocio para la gestión de 
    ||            horarios y ausencias de profesionales en TEKER.
    || Estándar: oracle-plsql-architecture
    || Responsabilidades:
    ||   - Consultas relacionales multi-tabla con sintaxis tradicional Oracle (+).
    ||   - Desestructuración de payloads JSON con JSON_TABLE para inserción multi-tabla.
    ||   - Generación de respuestas JSON estructuradas vía JSON_OBJECT/JSON_ARRAYAGG.
    ||   - Validación de reglas de negocio relacionales (traslapes de horarios por
    ||     día, rango de horas y rango de vigencia por fechas).
    ||   - CERO COMMIT / ROLLBACK (transacciones gobernadas por pkgln_horarios).
    || =========================================================================
    */

    -- 1. Consultar profesionales habilitados (rol 4, estado 1) mediante SYS_REFCURSOR
    FUNCTION f_consultar_profesionales (
        p_filtro_nombre IN VARCHAR2 DEFAULT NULL
    ) RETURN SYS_REFCURSOR;

    -- 2. Consultar profesionales habilitados formateado en JSON CLOB
    PROCEDURE p_consultar_profesionales_json (
        p_filtro_nombre IN  VARCHAR2,
        p_json_salida   OUT CLOB
    );

    -- 3. Validar si existe traslape de horario para un profesional evaluando día, horas y vigencia de fechas
    FUNCTION f_existe_traslape_horario (
        p_id_usuario         IN NUMBER,
        p_dia_semana         IN VARCHAR2,
        p_hora_desde         IN VARCHAR2,
        p_hora_hasta         IN VARCHAR2,
        p_fecha_inicial      IN DATE,
        p_fecha_final        IN DATE DEFAULT NULL,
        p_id_horario_excluir IN NUMBER DEFAULT NULL,
        p_id_convenio        IN NUMBER DEFAULT NULL
    ) RETURN BOOLEAN;

    -- 4. Desestructuración de JSON e inserción masiva de horarios con rango de fechas
    PROCEDURE p_guardar_horarios_profesional (
        p_id_usuario    IN NUMBER,
        p_json_horarios IN CLOB
    );

    -- 5. Consultar agenda integral de un profesional (horarios vigentes y ausencias) en JSON CLOB
    PROCEDURE p_consultar_agenda_profesional_json (
        p_id_usuario  IN  NUMBER,
        p_json_salida OUT CLOB
    );

    -- 6. Consultar ausencias en JSON (procedimiento de soporte y retrocompatibilidad)
    PROCEDURE p_consultar_ausencias_json (
        p_json      IN  CLOB,
        p_resultado OUT CLOB
    );

    -- 7. Eliminar ausencias de festivos de una vigencia personalizada si no solapa con otra vigencia personalizada
    PROCEDURE p_eliminar_ausencias_festivos_vigencia (
        p_id_usuario    IN NUMBER,
        p_fecha_inicial IN DATE,
        p_fecha_final   IN DATE
    );

    -- 8. Consultar citas ocupadas de un profesional en un rango de fechas (id_estado_cita IN (2,3))
    FUNCTION f_consultar_citas_ocupadas (
        p_id_usuario    IN NUMBER,
        p_fecha_inicial IN DATE,
        p_fecha_final   IN DATE
    ) RETURN SYS_REFCURSOR;

    -- 9. Persistir en una única instrucción DML el bitmap y slots sincronizados del día
    PROCEDURE p_sincronizar_agenda_slots (
        p_id_usuario            IN NUMBER,
        p_fecha                 IN DATE,
        p_id_convenio           IN NUMBER,
        p_id_tipo_aseguramiento IN NUMBER,
        p_modalidad             IN VARCHAR2,
        p_bitmap_disponible     IN VARCHAR2,
        p_bitmap_ocupado        IN VARCHAR2,
        p_slots_disponibles     IN NUMBER
    );

END PKGCN_HORARIOS;
/
