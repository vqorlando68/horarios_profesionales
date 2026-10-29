-- =============================================================================
-- PROYECTO: horario-profesionales
-- ARTEFACTO: Script DDL para Creación de Tabla TKR_REFRESCAR_AGENDA
-- ESTÁNDAR: oracle-plsql-architecture
-- =============================================================================

CREATE TABLE tkr_refrescar_agenda (
    id              NUMBER(12)      NOT NULL,
    id_usuario      NUMBER(12)      NOT NULL,
    fecha           DATE            NOT NULL,
    comentarios     VARCHAR2(4000),
    CONSTRAINT pk_tkr_refrescar_agenda PRIMARY KEY (id),
    CONSTRAINT fk_tkr_refrescar_agenda_usu FOREIGN KEY (id_usuario)
        REFERENCES tkr_usuarios (id)
);

COMMENT ON TABLE tkr_refrescar_agenda IS
    'Cola de solicitudes pendientes para refrescar y sincronizar la agenda de un profesional en una fecha específica mediante job.';
COMMENT ON COLUMN tkr_refrescar_agenda.id IS 'Identificador único del registro en la cola.';
COMMENT ON COLUMN tkr_refrescar_agenda.id_usuario IS 'Identificador del profesional (tkr_usuarios.id).';
COMMENT ON COLUMN tkr_refrescar_agenda.fecha IS 'Fecha específica de la agenda que se debe refrescar.';
COMMENT ON COLUMN tkr_refrescar_agenda.comentarios IS 'Detalle o respuesta JSON en caso de error durante la sincronización.';

CREATE SEQUENCE tkr_refrescar_agenda_seq
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

CREATE OR REPLACE TRIGGER trg_bi_tkr_refrescar_agenda
    BEFORE INSERT
    ON tkr_refrescar_agenda
    FOR EACH ROW
    WHEN (new.id IS NULL)
BEGIN
    :new.id := tkr_refrescar_agenda_seq.NEXTVAL;
END;
/

