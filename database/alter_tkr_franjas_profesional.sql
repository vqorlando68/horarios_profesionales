-- =============================================================================
-- PROYECTO: horario-profesionales
-- ARTEFACTO: Script DDL para Adición de id_convenio en TKR_FRANJAS_PROFESIONAL
-- ESTÁNDAR: oracle-plsql-architecture
-- =============================================================================

ALTER TABLE tkr_franjas_profesional 
    ADD (id_convenio NUMBER(12));

ALTER TABLE tkr_franjas_profesional 
    ADD CONSTRAINT fk_tkr_franjas_prof_conv 
    FOREIGN KEY (id_convenio) 
    REFERENCES tkr_convenios (id);

COMMENT ON COLUMN tkr_franjas_profesional.id_convenio IS 'ID del convenio (tkr_convenios.id). NULL = Aplica para todos los convenios.';
