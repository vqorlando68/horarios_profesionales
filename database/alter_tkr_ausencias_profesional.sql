-- =============================================================================
-- PROYECTO: horario-profesionales
-- ARTEFACTO: alter_tkr_ausencias_profesional.sql
-- BASE DE DATOS: Oracle Database (TEKER)
-- FECHA: 20/10/2026
-- DESCRIPCIÓN: Agrega las columnas origen y motivo a tkr_ausencias_profesional
--              para identificar el tipo de bloqueo (FESTIVO, MANUAL, etc.) y su descripción.
-- =============================================================================

ALTER TABLE tkr_ausencias_profesional ADD (
    origen VARCHAR2(50),
    motivo VARCHAR2(250)
);

COMMENT ON COLUMN tkr_ausencias_profesional.origen IS 'Origen del bloqueo de ausencia (ej: FESTIVO, MANUAL, VACACIONES, etc.)';
COMMENT ON COLUMN tkr_ausencias_profesional.motivo IS 'Motivo descriptivo o nombre del festivo asociado a la ausencia';
