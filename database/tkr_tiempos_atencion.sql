-- =============================================================================
-- PROYECTO: horario-profesionales
-- ARTEFACTO: Script DDL para Creación de Tabla TKR_TIEMPOS_ATENCION
-- ESTÁNDAR: oracle-plsql-architecture
-- =============================================================================

CREATE TABLE tkr_tiempos_atencion (
    id                      NUMBER(12)      NOT NULL,
    id_usuario              NUMBER(12)      NOT NULL,
    id_tipo_aseguramiento   NUMBER(12)      NOT NULL,
    duracion                NUMBER(4)       NOT NULL,
    duracion_domiciliaria   NUMBER(4),
    activo                  NUMBER(1)       DEFAULT 1 NOT NULL,
    fecha_creacion          DATE            DEFAULT (SYSTIMESTAMP AT TIME ZONE 'America/Bogota') NOT NULL,
    id_usuario_creacion     NUMBER(12),
    fecha_modificacion      DATE,
    id_usuario_modificacion NUMBER(12),
    CONSTRAINT tkr_tiempos_atencion_pk PRIMARY KEY (id),
    CONSTRAINT tkr_tiempos_atenc_usu_fk FOREIGN KEY (id_usuario)
        REFERENCES tkr_usuarios (id),
    CONSTRAINT tkr_tiempos_atenc_aseg_fk FOREIGN KEY (id_tipo_aseguramiento)
        REFERENCES tkr_tipos_aseguramiento (id),
    CONSTRAINT tkr_tiempos_atenc_uk UNIQUE (id_usuario, id_tipo_aseguramiento),
    CONSTRAINT tkr_tiempos_atenc_dur_ck CHECK (duracion > 0),
    CONSTRAINT tkr_tiempos_atenc_dur_dom_ck CHECK (duracion_domiciliaria IS NULL OR duracion_domiciliaria > 0)
);

COMMENT ON TABLE tkr_tiempos_atencion IS 'Configuración de tiempos de atención (duración en minutos) por profesional y tipo de aseguramiento';
COMMENT ON COLUMN tkr_tiempos_atencion.id IS 'Identificador único del registro';
COMMENT ON COLUMN tkr_tiempos_atencion.id_usuario IS 'Identificador del profesional (médico)';
COMMENT ON COLUMN tkr_tiempos_atencion.id_tipo_aseguramiento IS 'Identificador del tipo de aseguramiento';
COMMENT ON COLUMN tkr_tiempos_atencion.duracion IS 'Duración de la atención en minutos';

CREATE SEQUENCE tkr_tiempos_atencion_seq
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

CREATE OR REPLACE TRIGGER trg_bi_tkr_tiempos_atencion
    BEFORE INSERT
    ON tkr_tiempos_atencion
    FOR EACH ROW
    WHEN (new.id IS NULL)
BEGIN
    :new.id := tkr_tiempos_atencion_seq.NEXTVAL;
END;
/
