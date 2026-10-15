-- =============================================================================
-- PROYECTO: horario-profesionales
-- ARTEFACTO: Script DDL para Creación de Tabla TKR_HORARIOS_PROFESIONAL
-- ESTÁNDAR: oracle-plsql-architecture
-- AUTOR: Equipo TEKER
-- FECHA: 14/10/2026
-- DESCRIPCIÓN: Tabla de horarios de profesionales con rango de fechas de vigencia.
--              Si fecha_final está informada, el horario aplica solo en ese rango.
--              Si fecha_final es NULL, aplica indefinidamente desde fecha_inicial.
-- =============================================================================

-- 1. Secuencia
CREATE SEQUENCE tkr_horarios_profesional_seq
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;
/

-- 2. Tabla TKR_HORARIOS_PROFESIONAL
CREATE TABLE tkr_horarios_profesional (
    id                      NUMBER(12)      NOT NULL,
    id_usuario              NUMBER(12)      NOT NULL,
    dia_semana              VARCHAR2(2)     NOT NULL,
    hora_desde              VARCHAR2(5)     NOT NULL,
    hora_hasta              VARCHAR2(5)     NOT NULL,
    fecha_inicial           DATE            NOT NULL,
    fecha_final             DATE,
    activo                  NUMBER(1)       DEFAULT 1 NOT NULL,
    fecha_creacion          DATE            DEFAULT (SYSTIMESTAMP AT TIME ZONE 'America/Bogota') NOT NULL,
    id_usuario_creacion     NUMBER(12),
    fecha_modificacion      DATE,
    id_usuario_modificacion NUMBER(12),
    CONSTRAINT tkr_horarios_profesional_pk PRIMARY KEY (id),
    CONSTRAINT tkr_horarios_prof_usu_fk FOREIGN KEY (id_usuario) 
        REFERENCES tkr_usuarios (id),
    CONSTRAINT tkr_horarios_prof_dia_ck CHECK (
        dia_semana IN ('LU', 'MA', 'MI', 'JU', 'VI', 'SA', 'DO')
    ),
    CONSTRAINT tkr_horarios_prof_horas_ck CHECK (
        hora_desde < hora_hasta
    ),
    CONSTRAINT tkr_horarios_prof_fechas_ck CHECK (
        fecha_final IS NULL OR fecha_inicial <= fecha_final
    )
);
/

-- 3. Índices de optimización
CREATE INDEX tkr_horarios_prof_usu_idx 
    ON tkr_horarios_profesional (id_usuario, dia_semana, fecha_inicial, fecha_final, activo);
/

CREATE INDEX tkr_horarios_prof_fechas_idx 
    ON tkr_horarios_profesional (fecha_inicial, fecha_final, activo);
/

-- 4. Comentarios de tabla y columnas
COMMENT ON TABLE tkr_horarios_profesional IS 'Horarios y rangos de atención configurados por cada profesional de salud en TEKER con vigencia por fechas';
COMMENT ON COLUMN tkr_horarios_profesional.id IS 'Identificador único autonumérico del horario';
COMMENT ON COLUMN tkr_horarios_profesional.id_usuario IS 'Identificador del profesional (FK a tkr_usuarios.id con rol profesional = 4)';
COMMENT ON COLUMN tkr_horarios_profesional.dia_semana IS 'Código del día de la semana: LU, MA, MI, JU, VI, SA, DO';
COMMENT ON COLUMN tkr_horarios_profesional.hora_desde IS 'Hora inicial del rango de atención en formato HH24:MI (ej: 08:00, 14:00)';
COMMENT ON COLUMN tkr_horarios_profesional.hora_hasta IS 'Hora final del rango de atención en formato HH24:MI (ej: 12:00, 18:00)';
COMMENT ON COLUMN tkr_horarios_profesional.fecha_inicial IS 'Fecha de inicio de vigencia del horario (obligatoria)';
COMMENT ON COLUMN tkr_horarios_profesional.fecha_final IS 'Fecha de fin de vigencia del horario (opcional: si es NULL, aplica indefinidamente)';
COMMENT ON COLUMN tkr_horarios_profesional.activo IS 'Estado del rango horario: 1 = Activo, 0 = Inactivo';
COMMENT ON COLUMN tkr_horarios_profesional.fecha_creacion IS 'Fecha y hora de creación del registro con zona horaria America/Bogota';
COMMENT ON COLUMN tkr_horarios_profesional.id_usuario_creacion IS 'Usuario que registró el horario';
COMMENT ON COLUMN tkr_horarios_profesional.fecha_modificacion IS 'Fecha de última modificación del registro';
COMMENT ON COLUMN tkr_horarios_profesional.id_usuario_modificacion IS 'Usuario que realizó la última modificación';

-- 5. Trigger Before Insert para asignación automática de ID
CREATE OR REPLACE TRIGGER trg_bi_tkr_horarios_prof
    BEFORE INSERT ON tkr_horarios_profesional
    FOR EACH ROW
BEGIN
    IF :NEW.id IS NULL THEN
        :NEW.id := tkr_horarios_profesional_seq.NEXTVAL;
    END IF;
END;
/
