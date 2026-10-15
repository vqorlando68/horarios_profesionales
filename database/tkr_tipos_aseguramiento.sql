-- =============================================================================
-- PROYECTO: horario-profesionales
-- ARTEFACTO: Script DDL para Creación de Tabla TKR_TIPOS_ASEGURAMIENTO
-- ESTÁNDAR: oracle-plsql-architecture
-- =============================================================================

CREATE TABLE tkr_tipos_aseguramiento
(
    id                    NUMBER NOT NULL,
    tipo_aseguramiento    VARCHAR2 (100) NOT NULL
);

COMMENT ON COLUMN tkr_tipos_aseguramiento.id IS 'Identificador unico del registro';

COMMENT ON COLUMN tkr_tipos_aseguramiento.tipo_aseguramiento IS 'TIpo de aseguramiento';

ALTER TABLE tkr_tipos_aseguramiento
    ADD CONSTRAINT tkr_tipos_aseguramiento_pk PRIMARY KEY (id);

CREATE SEQUENCE tkr_tipos_aseguramiento_seq START WITH 1 NOCACHE ORDER;

CREATE OR REPLACE TRIGGER trg_bi_tkr_tipos_aseguramiento
    BEFORE INSERT
    ON tkr_tipos_aseguramiento
    FOR EACH ROW
    WHEN (new.id IS NULL)
BEGIN
    :new.id := tkr_tipos_aseguramiento_seq.NEXTVAL;
END;
/

INSERT INTO tkr_tipos_aseguramiento (id, tipo_aseguramiento) VALUES (1, 'Voluntario');
INSERT INTO tkr_tipos_aseguramiento (id, tipo_aseguramiento) VALUES (2, 'Obligatorio');
COMMIT;
