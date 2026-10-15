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
     *             rango de vigencia de fechas específico.
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

    -- =========================================================================
    -- ALIAS PARA COMPATIBILIDAD CONTRATOS PREVIOS (pr_*)
    -- =========================================================================
    PROCEDURE pr_registrar_ausencia (
        p_json      IN  CLOB,
        p_resultado OUT CLOB
    );

    PROCEDURE pr_actualizar_ausencia (
        p_json      IN  CLOB,
        p_resultado OUT CLOB
    );

    PROCEDURE pr_obtener_ausencias (
        p_json      IN  CLOB,
        p_resultado OUT CLOB
    );

    PROCEDURE pr_eliminar_ausencia (
        p_json      IN  CLOB,
        p_resultado OUT CLOB
    );

END PKGLN_HORARIOS;
/
