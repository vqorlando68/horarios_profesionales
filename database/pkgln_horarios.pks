CREATE OR REPLACE PACKAGE PKGLN_HORARIOS
AS
    /*
    || =========================================================================
    || Paquete: PKGLN_HORARIOS
    || Propósito: Orquestador transaccional expuesto al Frontend / API para la
    ||            gestión de profesionales, horarios multi-rango y ausencias.
    || Estándar: oracle-plsql-architecture
    || Reglas:
    ||   - Firma obligatoria externa: (p_json_entrada IN CLOB, p_json_salida OUT CLOB).
    ||   - PROHIBICIÓN TOTAL DE SENTENCIAS SQL DIRECTAS: Cero SELECT, INSERT, UPDATE, DELETE.
    ||   - Verificación de telemetría obligatoria con uti_manejo_trazas_pkg.
    ||   - Confirmación transaccional obligatoria y exclusiva con p_do_commit.
    ||   - Manejo forense de excepciones con uti_ge_excepciones_pkg.p_grabar_log y -20000.
    ||   - Documentación obligatoria de flujo en pkgln_horarios.md para app de grafos.
    || =========================================================================
    */

    /**
     * =========================================================================
     * Objeto    : p_listar_profesionales
     * Propósito : Consulta la lista de profesionales habilitados (rol=4, estado=1)
     *             con nombre completo concatenado y URL de foto.
     * =========================================================================
     */
    PROCEDURE p_listar_profesionales (
        p_json_entrada IN  CLOB,
        p_json_salida  OUT CLOB
    );

    /**
     * =========================================================================
     * Objeto    : p_guardar_horarios
     * Propósito : Guarda y sincroniza los rangos de horario de un profesional,
     *             permitiendo varios rangos para el mismo día de la semana.
     *             Opcionalmente recibe festivos_no_laborables para crear las
     *             ausencias correspondientes en la misma transacción atómica.
     * 
     * Estructura JSON Entrada:
     *   {
     *     "id_usuario": NUMBER (Obligatorio),
     *     "reemplazar_todo": NUMBER (Opcional, defecto 1),
     *     "reemplazar_vigencia": NUMBER (Opcional, defecto 0),
     *     "fecha_inicial_origen": VARCHAR2 (Opcional, YYYY-MM-DD),
     *     "fecha_final_origen": VARCHAR2 (Opcional, YYYY-MM-DD),
     *     "horarios": [ { "dia_semana": "LU", "hora_desde": "08:00", "hora_hasta": "12:00",
     *                     "fecha_inicial": "2026-12-01", "fecha_final": "2026-12-11",
     *                     "id_convenio": NUMBER (Opcional, NULL = aplica para todos los convenios) } ],
     *     "festivos_no_laborables": [ { "fecha": "2026-12-08", "nombre": "Inmaculada Concepción" } ] (Opcional)
     *   }
     * 
     * Estructura JSON Salida:
     *   {
     *     "codigo": NUMBER (0 = Éxito, < 0 = Error de negocio o inesperado),
     *     "mensaje": VARCHAR2 (Texto legible para el usuario final),
     *     "id_usuario": NUMBER,
     *     "ausencias_creadas": NUMBER,
     *     "ausencias_existentes": NUMBER
     *   }
     * =========================================================================
     */
    PROCEDURE p_guardar_horarios (
        p_json_entrada IN  CLOB,
        p_json_salida  OUT CLOB
    );

    /**
     * =========================================================================
     * Objeto    : p_consultar_agenda
     * Propósito : Retorna la agenda integral del profesional: datos, foto,
     *             horarios multi-rango y ausencias registradas.
     * =========================================================================
     */
    PROCEDURE p_consultar_agenda (
        p_json_entrada IN  CLOB,
        p_json_salida  OUT CLOB
    );

    /**
     * =========================================================================
     * Objeto    : p_registrar_ausencia
     * Propósito : Registra un rango de fechas en que el profesional no va a
     *             trabajar en TKR_AUSENCIAS_PROFESIONAL.
     * =========================================================================
     */
    PROCEDURE p_registrar_ausencia (
        p_json_entrada IN  CLOB,
        p_json_salida  OUT CLOB
    );

    /**
     * =========================================================================
     * Objeto    : p_consultar_ausencias
     * Propósito : Retorna las ausencias registradas por profesional o rango.
     * =========================================================================
     */
    PROCEDURE p_consultar_ausencias (
        p_json_entrada IN  CLOB,
        p_json_salida  OUT CLOB
    );

    /**
     * =========================================================================
     * Objeto    : p_eliminar_ausencia
     * Propósito : Elimina una ausencia específica por su identificador.
     * =========================================================================
     */
    PROCEDURE p_eliminar_ausencia (
        p_json_entrada IN  CLOB,
        p_json_salida  OUT CLOB
    );

    /**
     * =========================================================================
     * Objeto    : p_eliminar_horarios_vigencia
     * Propósito : Elimina todos los horarios de un profesional asociados a un
     *             rango de vigencia de fechas específico. Informa en la respuesta
     *             si existen ausencias registradas para ese periodo a fin de que
     *             el usuario determine si amerita eliminarlas manualmente.
     * 
     * Estructura JSON Salida:
     *   {
     *     "codigo": 0,
     *     "mensaje": VARCHAR2,
     *     "id_usuario": NUMBER,
     *     "tiene_ausencias": NUMBER (1 = existen ausencias, 0 = no existen),
     *     "cantidad_ausencias": NUMBER
     *   }
     * =========================================================================
     */
    PROCEDURE p_eliminar_horarios_vigencia (
        p_json_entrada IN  CLOB,
        p_json_salida  OUT CLOB
    );

    /**
     * =========================================================================
     * Objeto    : p_actualizar_trabaja_festivos
     * Propósito : Actualiza el indicador trabaja_festivos ('S' o 'N') para el
     *             profesional en tkr_usuarios. Si se desmarca a 'N' y se solicita,
     *             elimina atómicamente todos los horarios registrados para el
     *             día domingo ('DO').
     * =========================================================================
     */
    PROCEDURE p_actualizar_trabaja_festivos (
        p_json_entrada IN  CLOB,
        p_json_salida  OUT CLOB
    );

    /**
     * =========================================================================
     * Objeto      : p_sincornizar_agenda
     * Propósito   : Sincroniza los slots y bitmaps de disponibilidad del profesional
     *               (tkr_disponibilidad_bitmap) a partir de los horarios vigentes,
     *               marcando como ocupados los slots comprendidos entre
     *               fecha_inicio_cita y fecha_final_cita en tkr_citas para
     *               id_estado_cita IN (2, 3).
     *
     * Estructura JSON Entrada (Schema):
     *   {
     *     "id_usuario": NUMBER (Obligatorio si no se envía id_profesional),
     *     "id_profesional": NUMBER (Opcional, alias de id_usuario),
     *     "fecha": VARCHAR2 (Opcional, YYYY-MM-DD para sincronizar un día específico),
     *     "fecha_inicial": VARCHAR2 (Opcional, YYYY-MM-DD),
     *     "fecha_final": VARCHAR2 (Opcional, YYYY-MM-DD)
     *   }
     *
     * Estructura JSON Salida (Schema):
     *   {
     *     "codigo": NUMBER (0 = Éxito, < 0 = Error),
     *     "mensaje": VARCHAR2,
     *     "id_usuario": NUMBER,
     *     "dias_sincronizados": NUMBER,
     *     "citas_ocupadas": NUMBER
     *   }
     *
     * Historial de Modificaciones:
     *   -----------------------------------------------------------------------
     *   FECHA       | AUTOR                  | DESCRIPCIÓN DEL CAMBIO
     *   -----------------------------------------------------------------------
     *   2026-10-29  | Orlando Valverde       | Creación de sincronización de slots con tkr_citas (estados 2,3).
     * =========================================================================
     */
    PROCEDURE p_sincornizar_agenda (
        p_json_entrada IN  CLOB,
        p_json_salida  OUT CLOB
    );

    PROCEDURE p_sincornizar_agenda (
        p_id_profesional IN NUMBER,
        p_fecha          IN DATE DEFAULT NULL
    );

    PROCEDURE p_sincronizar_agenda (
        p_json_entrada IN  CLOB,
        p_json_salida  OUT CLOB
    );

    PROCEDURE p_sincronizar_agenda (
        p_id_profesional IN NUMBER,
        p_fecha          IN DATE DEFAULT NULL
    );

    -- =========================================================================
    -- ALIAS PARA COMPATIBILIDAD CONTRATOS PREVIOS (p_*)
    -- =========================================================================
    PROCEDURE p_actualizar_ausencia (
        p_json      IN  CLOB,
        p_resultado OUT CLOB
    );

    PROCEDURE p_obtener_ausencias (
        p_json      IN  CLOB,
        p_resultado OUT CLOB
    );

END PKGLN_HORARIOS;
/
