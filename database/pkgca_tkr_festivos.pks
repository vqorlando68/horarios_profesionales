CREATE OR REPLACE PACKAGE pkgca_tkr_festivos
AS
    /*
    || =========================================================================
    || Paquete     : pkgca_tkr_festivos
    || Propósito   : Capa de Acceso y Consultas Mono-Tabla No-PK sobre TKR_FESTIVOS.
    || Estándar    : oracle-plsql-architecture
    || Reglas      :
    ||   - Exclusivamente sobre la tabla física tkr_festivos (CERO JOINs).
    ||   - Prohibido COMMIT / ROLLBACK (gobernado por pkgln_).
    ||   - Subprogramas obligatorios con prefijo f_ (funciones) o p_ (procedimientos).
    || =========================================================================
    */

    /**
     * Valida si una fecha específica corresponde a un día festivo nacional.
     * @param p_fecha   Fecha a consultar
     * @param p_id_pais Identificador del país (por defecto 1 = Colombia)
     * @return BOOLEAN  TRUE si existe el festivo, FALSE en caso contrario
     */
    FUNCTION f_es_festivo (
        p_fecha   IN DATE,
        p_id_pais IN tkr_festivos.id_pais%TYPE DEFAULT 1
    ) RETURN BOOLEAN;

    /**
     * Obtiene el nombre descriptivo de un día festivo si la fecha es festiva.
     * @param p_fecha   Fecha a consultar
     * @param p_id_pais Identificador del país (por defecto 1)
     * @return VARCHAR2 Nombre del festivo o NULL si no existe
     */
    FUNCTION f_obtener_nombre_festivo (
        p_fecha   IN DATE,
        p_id_pais IN tkr_festivos.id_pais%TYPE DEFAULT 1
    ) RETURN VARCHAR2;

    /**
     * Retorna un cursor con los días festivos de un país específico.
     * @param p_id_pais Identificador del país
     * @return SYS_REFCURSOR Conjunto de registros de festivos
     */
    FUNCTION f_consultar_festivos_pais (
        p_id_pais IN tkr_festivos.id_pais%TYPE DEFAULT 1
    ) RETURN SYS_REFCURSOR;

END pkgca_tkr_festivos;
/
