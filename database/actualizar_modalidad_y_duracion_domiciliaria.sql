-- =============================================================================
-- PROYECTO: horario-profesionales
-- ARTEFACTO: Script DDL para Adición de Campos:
--            1. duracion_domiciliaria en TKR_TIEMPOS_ATENCION
--            2. modalidad en TKR_FRANJAS_PROFESIONAL
-- ESTÁNDAR: oracle-plsql-architecture
-- =============================================================================

-- 1. Modificaciones en TKR_TIEMPOS_ATENCION
--    Adición del campo para la atención domiciliaria y ajuste de comentarios.
ALTER TABLE tkr_tiempos_atencion 
    ADD (duracion_domiciliaria NUMBER(4));

ALTER TABLE tkr_tiempos_atencion 
    ADD CONSTRAINT tkr_tiempos_atenc_dur_dom_ck 
    CHECK (duracion_domiciliaria IS NULL OR duracion_domiciliaria > 0);

COMMENT ON COLUMN tkr_tiempos_atencion.duracion IS 'Duración de la consulta virtual o estándar en minutos';
COMMENT ON COLUMN tkr_tiempos_atencion.duracion_domiciliaria IS 'Duración de la atención médica domiciliaria en minutos';

-- 2. Modificaciones en TKR_FRANJAS_PROFESIONAL
--    Adición del campo modalidad para distinguir Virtual (V), Domiciliaria (D) o Ambas (NULL/vacío).
ALTER TABLE tkr_franjas_profesional 
    ADD (modalidad VARCHAR2(1));

ALTER TABLE tkr_franjas_profesional 
    ADD CONSTRAINT tkr_franjas_prof_mod_ck 
    CHECK (modalidad IN ('V', 'D') OR modalidad IS NULL);

COMMENT ON COLUMN tkr_franjas_profesional.modalidad IS 'Modalidad de atención: V = Virtual, D = Domiciliaria, NULL = Aplica para ambas (Virtual y Domiciliaria)';

-- Fin del script
