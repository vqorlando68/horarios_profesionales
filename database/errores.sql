SQL> SET FEEDBACK ON
SQL> SET DEFINE OFF
SQL> PROMPT =========================================================================
=========================================================================
SQL> PROMPT 1. CREANDO TABLA, SECUENCIA, INDICES Y TRIGGER: tkr_horarios_profesional
1. CREANDO TABLA, SECUENCIA, INDICES Y TRIGGER: tkr_horarios_profesional
SQL> PROMPT =========================================================================
=========================================================================
SQL> @@tkr_horarios_profesional.sql
SQL> -- =============================================================================
SQL> -- PROYECTO: horario-profesionales
SQL> -- ARTEFACTO: Script DDL para Creación de Tabla TKR_HORARIOS_PROFESIONAL
SQL> -- ESTÁNDAR: oracle-plsql-architecture
SQL> -- AUTOR: Equipo TEKER
SQL> -- FECHA: 14/10/2026
SQL> -- DESCRIPCIÓN: Tabla de horarios de profesionales con rango de fechas de vigencia.
SQL> --              Si fecha_final está informada, el horario aplica solo en ese rango.
SQL> --              Si fecha_final es NULL, aplica indefinidamente desde fecha_inicial.
SQL> -- =============================================================================
SQL> -- 1. Secuencia
SQL> CREATE SEQUENCE tkr_horarios_profesional_seq
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE
Sequence created.
SQL> /
SQL> -- 2. Tabla TKR_HORARIOS_PROFESIONAL
SQL> CREATE TABLE tkr_horarios_profesional (
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
)
Table created.
SQL> /
SQL> -- 3. Índices de optimización
SQL> CREATE INDEX tkr_horarios_prof_usu_idx 
    ON tkr_horarios_profesional (id_usuario, dia_semana, fecha_inicial, fecha_final, activo)
Index created.
SQL> /
SQL> CREATE INDEX tkr_horarios_prof_fechas_idx 
    ON tkr_horarios_profesional (fecha_inicial, fecha_final, activo)
Index created.
SQL> /
SQL> -- 4. Comentarios de tabla y columnas
SQL> COMMENT ON TABLE tkr_horarios_profesional IS 'Horarios y rangos de atención configurados por cada profesional de salud en TEKER con vigencia por fechas'
Comment created.
SQL> COMMENT ON COLUMN tkr_horarios_profesional.id IS 'Identificador único autonumérico del horario'
Comment created.
SQL> COMMENT ON COLUMN tkr_horarios_profesional.id_usuario IS 'Identificador del profesional (FK a tkr_usuarios.id con rol profesional = 4)'
Comment created.
SQL> COMMENT ON COLUMN tkr_horarios_profesional.dia_semana IS 'Código del día de la semana: LU, MA, MI, JU, VI, SA, DO'
Comment created.
SQL> COMMENT ON COLUMN tkr_horarios_profesional.hora_desde IS 'Hora inicial del rango de atención en formato HH24:MI (ej: 08:00, 14:00)'
Comment created.
SQL> COMMENT ON COLUMN tkr_horarios_profesional.hora_hasta IS 'Hora final del rango de atención en formato HH24:MI (ej: 12:00, 18:00)'
Comment created.
SQL> COMMENT ON COLUMN tkr_horarios_profesional.fecha_inicial IS 'Fecha de inicio de vigencia del horario (obligatoria)'
Comment created.
SQL> COMMENT ON COLUMN tkr_horarios_profesional.fecha_final IS 'Fecha de fin de vigencia del horario (opcional: si es NULL, aplica indefinidamente)'
Comment created.
SQL> COMMENT ON COLUMN tkr_horarios_profesional.activo IS 'Estado del rango horario: 1 = Activo, 0 = Inactivo'
Comment created.
SQL> COMMENT ON COLUMN tkr_horarios_profesional.fecha_creacion IS 'Fecha y hora de creación del registro con zona horaria America/Bogota'
Comment created.
SQL> COMMENT ON COLUMN tkr_horarios_profesional.id_usuario_creacion IS 'Usuario que registró el horario'
Comment created.
SQL> COMMENT ON COLUMN tkr_horarios_profesional.fecha_modificacion IS 'Fecha de última modificación del registro'
Comment created.
SQL> COMMENT ON COLUMN tkr_horarios_profesional.id_usuario_modificacion IS 'Usuario que realizó la última modificación'
Comment created.
SQL> -- 5. Trigger Before Insert para asignación automática de ID
SQL> CREATE OR REPLACE TRIGGER trg_bi_tkr_horarios_prof
    BEFORE INSERT ON tkr_horarios_profesional
    FOR EACH ROW
BEGIN
    IF :NEW.id IS NULL THEN
        :NEW.id := tkr_horarios_profesional_seq.NEXTVAL;
    END IF;
END;
Trigger created.
SQL> PROMPT =========================================================================
=========================================================================
SQL> PROMPT 2. COMPILANDO ESPECIFICACION DAO: PKGTKR_HORARIOS_PROFESIONAL_DAO
2. COMPILANDO ESPECIFICACION DAO: PKGTKR_HORARIOS_PROFESIONAL_DAO
SQL> PROMPT =========================================================================
=========================================================================
SQL> @@pkgtkr_horarios_profesional_dao.pks
SQL> CREATE OR REPLACE PACKAGE PKGTKR_HORARIOS_PROFESIONAL_DAO
AS
    /*
    || =========================================================================
    || Paquete: PKGTKR_HORARIOS_PROFESIONAL_DAO
    || Propósito: Acceso a datos y persistencia atómica para la tabla 
    ||            TKR_HORARIOS_PROFESIONAL.
    || Estándar: oracle-plsql-architecture (Plantilla Oficial de 20 Métodos)
    || Reglas:
    ||   - Acceso exclusivo a la tabla TKR_HORARIOS_PROFESIONAL por PK o ROWID.
    ||   - CERO lógica de negocio.
    ||   - PROHIBIDO COMMIT o ROLLBACK en este paquete.
    || =========================================================================
    */

    -- Tipo colección para manejo en memoria de registros
    TYPE t_tkr_horarios_profesional IS TABLE OF tkr_horarios_profesional%ROWTYPE
        INDEX BY BINARY_INTEGER;

    -- 1. Insertar registro unitario
    PROCEDURE p_insertar (
        pro_tkr_horarios_profesional IN tkr_horarios_profesional%ROWTYPE
    );

    -- 2. Insertar colección masiva mediante FORALL
    PROCEDURE p_insertar_con_tabla (
        pta_tkr_horarios_profesional IN PKGTKR_HORARIOS_PROFESIONAL_DAO.t_tkr_horarios_profesional
    );

    -- 3. Traer registro por PK
    FUNCTION f_traer (
        pty_id IN tkr_horarios_profesional.id%TYPE
    ) RETURN tkr_horarios_profesional%ROWTYPE;

    -- 4. Consultar todos los registros
    PROCEDURE p_consultar_registros (
        pta_tkr_horarios_profesional OUT PKGTKR_HORARIOS_PROFESIONAL_DAO.t_tkr_horarios_profesional
    );

    -- 5. Eliminar registro por ROWID
    PROCEDURE p_eliminar_rowid (
        p_rowid IN VARCHAR2
    );

    -- 6. Eliminar registro por PK
    PROCEDURE p_eliminar (
        pty_id IN tkr_horarios_profesional.id%TYPE
    );

    -- 7. Eliminar todos los registros
    PROCEDURE p_eliminar_registros;

    -- 8. Verificar existencia por PK
    FUNCTION f_existe (
        pty_id IN tkr_horarios_profesional.id%TYPE
    ) RETURN BOOLEAN;

    -- 9. Verificar existencia y retornar registro
    FUNCTION f_existe (
        pty_id                       IN  tkr_horarios_profesional.id%TYPE,
        pro_tkr_horarios_profesional OUT tkr_horarios_profesional%ROWTYPE
    ) RETURN BOOLEAN;

    -- 10. Verificar existencia, retornar registro y ROWID
    FUNCTION f_existe (
        pty_id                       IN  tkr_horarios_profesional.id%TYPE,
        pro_tkr_horarios_profesional OUT tkr_horarios_profesional%ROWTYPE,
        p_rowid                      OUT VARCHAR2
    ) RETURN BOOLEAN;

    -- 11. Verificar existencia por ROWID
    FUNCTION f_existe_rowid (
        p_rowid IN VARCHAR2
    ) RETURN BOOLEAN;

    -- 12. Verificar existencia por ROWID y retornar registro
    FUNCTION f_existe_rowid (
        p_rowid                      IN  VARCHAR2,
        pro_tkr_horarios_profesional OUT tkr_horarios_profesional%ROWTYPE
    ) RETURN BOOLEAN;

    -- 13. Actualizar registro completo por PK en ROWTYPE
    PROCEDURE p_actualizar (
        pro_tkr_horarios_profesional IN tkr_horarios_profesional%ROWTYPE
    );

    -- 14. Actualizar indicando PK explícita
    PROCEDURE p_actualizar (
        pro_tkr_horarios_profesional IN tkr_horarios_profesional%ROWTYPE,
        pty_id                       IN tkr_horarios_profesional.id%TYPE
    );

    -- 15. Actualizar por ROWID
    PROCEDURE p_actualizar_rowid (
        pro_tkr_horarios_profesional IN tkr_horarios_profesional%ROWTYPE,
        p_rowid                      IN VARCHAR2
    );

    -- 16. Actualizar todos los registros
    PROCEDURE p_actualizar_registros (
        pro_tkr_horarios_profesional IN tkr_horarios_profesional%ROWTYPE
    );

    -- 17. Obtener valores por defecto
    PROCEDURE p_valores_defecto (
        pro_tkr_horarios_profesional IN OUT tkr_horarios_profesional%ROWTYPE
    );

    -- 18. Verificar existencia y retornar JSON CLOB
    FUNCTION f_existe_json (
        p_id                             IN  tkr_horarios_profesional.id%TYPE,
        p_json_tkr_horarios_profesional  OUT CLOB
    ) RETURN NUMBER;

    -- 19. Obtener JSON por PK
    FUNCTION f_json (
        p_id IN tkr_horarios_profesional.id%TYPE
    ) RETURN VARCHAR2;

    -- 20. Paginación: Calcular total de páginas
    FUNCTION f_total_paginas (
        p_json_entrada IN CLOB
    ) RETURN NUMBER;

    -- 21. Paginación: Consultar registros paginados retornando JSON
    FUNCTION f_consultar_paginado (
        p_pagina    IN NUMBER,
        p_registros IN NUMBER
    ) RETURN CLOB;

END PKGTKR_HORARIOS_PROFESIONAL_DAO;
Package created.
SQL> PROMPT =========================================================================
=========================================================================
SQL> PROMPT 3. COMPILANDO CUERPO DAO: PKGTKR_HORARIOS_PROFESIONAL_DAO
3. COMPILANDO CUERPO DAO: PKGTKR_HORARIOS_PROFESIONAL_DAO
SQL> PROMPT =========================================================================
=========================================================================
SQL> @@pkgtkr_horarios_profesional_dao.pkb
SQL> CREATE OR REPLACE PACKAGE BODY PKGTKR_HORARIOS_PROFESIONAL_DAO
AS
    /*
    || =========================================================================
    || Paquete: PKGTKR_HORARIOS_PROFESIONAL_DAO (Body)
    || Propósito: Implementación oficial inalterable de los métodos CRUD para
    ||            TKR_HORARIOS_PROFESIONAL.
    || Estándar: oracle-plsql-architecture
    || =========================================================================
    */

    -- 1. Insertar registro unitario
    PROCEDURE p_insertar (
        pro_tkr_horarios_profesional IN tkr_horarios_profesional%ROWTYPE
    ) IS
    BEGIN
        INSERT INTO tkr_horarios_profesional VALUES pro_tkr_horarios_profesional;
    END p_insertar;

    -- 2. Insertar colección masiva mediante FORALL
    PROCEDURE p_insertar_con_tabla (
        pta_tkr_horarios_profesional IN PKGTKR_HORARIOS_PROFESIONAL_DAO.t_tkr_horarios_profesional
    ) IS
    BEGIN
        FORALL i IN pta_tkr_horarios_profesional.FIRST .. pta_tkr_horarios_profesional.LAST
            INSERT INTO tkr_horarios_profesional VALUES pta_tkr_horarios_profesional(i);
    END p_insertar_con_tabla;

    -- 3. Traer registro por PK
    FUNCTION f_traer (
        pty_id IN tkr_horarios_profesional.id%TYPE
    ) RETURN tkr_horarios_profesional%ROWTYPE IS
        vro_registro tkr_horarios_profesional%ROWTYPE;
    BEGIN
        SELECT *
          INTO vro_registro
          FROM tkr_horarios_profesional
         WHERE id = pty_id;
        RETURN vro_registro;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END f_traer;

    -- 4. Consultar todos los registros
    PROCEDURE p_consultar_registros (
        pta_tkr_horarios_profesional OUT PKGTKR_HORARIOS_PROFESIONAL_DAO.t_tkr_horarios_profesional
    ) IS
    BEGIN
        SELECT *
          BULK COLLECT INTO pta_tkr_horarios_profesional
          FROM tkr_horarios_profesional;
    END p_consultar_registros;

    -- 5. Eliminar registro por ROWID
    PROCEDURE p_eliminar_rowid (
        p_rowid IN VARCHAR2
    ) IS
    BEGIN
        DELETE FROM tkr_horarios_profesional WHERE ROWID = p_rowid;
    END p_eliminar_rowid;

    -- 6. Eliminar registro por PK
    PROCEDURE p_eliminar (
        pty_id IN tkr_horarios_profesional.id%TYPE
    ) IS
    BEGIN
        DELETE FROM tkr_horarios_profesional WHERE id = pty_id;
    END p_eliminar;

    -- 7. Eliminar todos los registros
    PROCEDURE p_eliminar_registros IS
    BEGIN
        DELETE FROM tkr_horarios_profesional;
    END p_eliminar_registros;

    -- 8. Verificar existencia por PK
    FUNCTION f_existe (
        pty_id IN tkr_horarios_profesional.id%TYPE
    ) RETURN BOOLEAN IS
        v_dummy NUMBER;
    BEGIN
        SELECT 1
          INTO v_dummy
          FROM tkr_horarios_profesional
         WHERE id = pty_id;
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN FALSE;
    END f_existe;

    -- 9. Verificar existencia y retornar registro
    FUNCTION f_existe (
        pty_id                       IN  tkr_horarios_profesional.id%TYPE,
        pro_tkr_horarios_profesional OUT tkr_horarios_profesional%ROWTYPE
    ) RETURN BOOLEAN IS
    BEGIN
        SELECT *
          INTO pro_tkr_horarios_profesional
          FROM tkr_horarios_profesional
         WHERE id = pty_id;
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN FALSE;
    END f_existe;

    -- 10. Verificar existencia, retornar registro y ROWID
    FUNCTION f_existe (
        pty_id                       IN  tkr_horarios_profesional.id%TYPE,
        pro_tkr_horarios_profesional OUT tkr_horarios_profesional%ROWTYPE,
        p_rowid                      OUT VARCHAR2
    ) RETURN BOOLEAN IS
    BEGIN
        SELECT t.*, ROWID
          INTO pro_tkr_horarios_profesional, p_rowid
          FROM tkr_horarios_profesional t
         WHERE id = pty_id;
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_rowid := NULL;
            RETURN FALSE;
    END f_existe;

    -- 11. Verificar existencia por ROWID
    FUNCTION f_existe_rowid (
        p_rowid IN VARCHAR2
    ) RETURN BOOLEAN IS
        v_dummy NUMBER;
    BEGIN
        SELECT 1
          INTO v_dummy
          FROM tkr_horarios_profesional
         WHERE ROWID = p_rowid;
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN FALSE;
    END f_existe_rowid;

    -- 12. Verificar existencia por ROWID y retornar registro
    FUNCTION f_existe_rowid (
        p_rowid                      IN  VARCHAR2,
        pro_tkr_horarios_profesional OUT tkr_horarios_profesional%ROWTYPE
    ) RETURN BOOLEAN IS
    BEGIN
        SELECT *
          INTO pro_tkr_horarios_profesional
          FROM tkr_horarios_profesional
         WHERE ROWID = p_rowid;
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN FALSE;
    END f_existe_rowid;

    -- 13. Actualizar registro completo por PK en ROWTYPE
    PROCEDURE p_actualizar (
        pro_tkr_horarios_profesional IN tkr_horarios_profesional%ROWTYPE
    ) IS
    BEGIN
        UPDATE tkr_horarios_profesional
           SET ROW = pro_tkr_horarios_profesional
         WHERE id = pro_tkr_horarios_profesional.id;
    END p_actualizar;

    -- 14. Actualizar indicando PK explícita
    PROCEDURE p_actualizar (
        pro_tkr_horarios_profesional IN tkr_horarios_profesional%ROWTYPE,
        pty_id                       IN tkr_horarios_profesional.id%TYPE
    ) IS
    BEGIN
        UPDATE tkr_horarios_profesional
           SET ROW = pro_tkr_horarios_profesional
         WHERE id = pty_id;
    END p_actualizar;

    -- 15. Actualizar por ROWID
    PROCEDURE p_actualizar_rowid (
        pro_tkr_horarios_profesional IN tkr_horarios_profesional%ROWTYPE,
        p_rowid                      IN VARCHAR2
    ) IS
    BEGIN
        UPDATE tkr_horarios_profesional
           SET ROW = pro_tkr_horarios_profesional
         WHERE ROWID = p_rowid;
    END p_actualizar_rowid;

    -- 16. Actualizar todos los registros
    PROCEDURE p_actualizar_registros (
        pro_tkr_horarios_profesional IN tkr_horarios_profesional%ROWTYPE
    ) IS
    BEGIN
        UPDATE tkr_horarios_profesional
           SET ROW = pro_tkr_horarios_profesional;
    END p_actualizar_registros;

    -- 17. Obtener valores por defecto
    PROCEDURE p_valores_defecto (
        pro_tkr_horarios_profesional IN OUT tkr_horarios_profesional%ROWTYPE
    ) IS
    BEGIN
        pro_tkr_horarios_profesional.fecha_inicial  := TRUNC(SYSDATE);
        pro_tkr_horarios_profesional.fecha_final    := NULL;
        pro_tkr_horarios_profesional.activo         := 1;
        pro_tkr_horarios_profesional.fecha_creacion := SYSDATE;
    END p_valores_defecto;

    -- 18. Verificar existencia y retornar JSON CLOB
    FUNCTION f_existe_json (
        p_id                             IN  tkr_horarios_profesional.id%TYPE,
        p_json_tkr_horarios_profesional  OUT CLOB
    ) RETURN NUMBER IS
        v_existe NUMBER := 0;
    BEGIN
        SELECT 1,
               JSON_OBJECT(
                   'id'                      VALUE t.id,
                   'id_usuario'              VALUE t.id_usuario,
                   'dia_semana'              VALUE t.dia_semana,
                   'hora_desde'              VALUE t.hora_desde,
                   'hora_hasta'              VALUE t.hora_hasta,
                   'fecha_inicial'           VALUE TO_CHAR(t.fecha_inicial, 'YYYY-MM-DD'),
                   'fecha_final'             VALUE TO_CHAR(t.fecha_final, 'YYYY-MM-DD'),
                   'activo'                  VALUE t.activo,
                   'fecha_creacion'          VALUE TO_CHAR(t.fecha_creacion, 'YYYY-MM-DD"T"HH24:MI:SS')
                   RETURNING CLOB
               )
          INTO v_existe, p_json_tkr_horarios_profesional
          FROM tkr_horarios_profesional t
         WHERE t.id = p_id;
        RETURN v_existe;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_json_tkr_horarios_profesional := NULL;
            RETURN 0;
    END f_existe_json;

    -- 19. Obtener JSON por PK
    FUNCTION f_json (
        p_id IN tkr_horarios_profesional.id%TYPE
    ) RETURN VARCHAR2 IS
        v_json VARCHAR2(4000);
    BEGIN
        SELECT JSON_OBJECT(
                   'id'            VALUE t.id,
                   'id_usuario'    VALUE t.id_usuario,
                   'dia_semana'    VALUE t.dia_semana,
                   'hora_desde'    VALUE t.hora_desde,
                   'hora_hasta'    VALUE t.hora_hasta,
                   'fecha_inicial' VALUE TO_CHAR(t.fecha_inicial, 'YYYY-MM-DD'),
                   'fecha_final'   VALUE TO_CHAR(t.fecha_final, 'YYYY-MM-DD'),
                   'activo'        VALUE t.activo
               )
          INTO v_json
          FROM tkr_horarios_profesional t
         WHERE t.id = p_id;
        RETURN v_json;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END f_json;

    -- 20. Paginación: Calcular total de páginas
    FUNCTION f_total_paginas (
        p_json_entrada IN CLOB
    ) RETURN NUMBER IS
        v_obj_in    JSON_OBJECT_T;
        v_registros NUMBER := 10;
        v_total_reg NUMBER := 0;
    BEGIN
        IF p_json_entrada IS NOT NULL THEN
            v_obj_in    := JSON_OBJECT_T.parse(p_json_entrada);
            v_registros := NVL(v_obj_in.get_number('registros_por_pagina'), 10);
        END IF;

        SELECT COUNT(*)
          INTO v_total_reg
          FROM tkr_horarios_profesional;

        RETURN CEIL(v_total_reg / v_registros);
    END f_total_paginas;

    -- 21. Paginación: Consultar registros paginados retornando JSON
    FUNCTION f_consultar_paginado (
        p_pagina    IN NUMBER,
        p_registros IN NUMBER
    ) RETURN CLOB IS
        v_offset NUMBER;
        v_json   CLOB;
    BEGIN
        v_offset := (NVL(p_pagina, 1) - 1) * NVL(p_registros, 10);

        SELECT JSON_OBJECT(
                   'pagina'             VALUE p_pagina,
                   'registros_solicitados' VALUE p_registros,
                   'datos'              VALUE COALESCE(
                       JSON_ARRAYAGG(
                           JSON_OBJECT(
                               'id'            VALUE t.id,
                               'id_usuario'    VALUE t.id_usuario,
                               'dia_semana'    VALUE t.dia_semana,
                               'hora_desde'    VALUE t.hora_desde,
                               'hora_hasta'    VALUE t.hora_hasta,
                               'fecha_inicial' VALUE TO_CHAR(t.fecha_inicial, 'YYYY-MM-DD'),
                               'fecha_final'   VALUE TO_CHAR(t.fecha_final, 'YYYY-MM-DD'),
                               'activo'        VALUE t.activo
                           )
                           ORDER BY t.dia_semana, t.hora_desde
                       ),
                       JSON_ARRAY()
                   )
                   RETURNING CLOB
               )
          INTO v_json
          FROM (
               SELECT *
                 FROM tkr_horarios_profesional
                ORDER BY id
               OFFSET v_offset ROWS FETCH NEXT p_registros ROWS ONLY
          ) t;

        RETURN v_json;
    END f_consultar_paginado;

END PKGTKR_HORARIOS_PROFESIONAL_DAO;
Warning: compiled but with compilation errors
SQL> PROMPT =========================================================================
=========================================================================
SQL> PROMPT 4. COMPILANDO ESPECIFICACION MONO-TABLA: pkgca_tkr_horarios_profesional
4. COMPILANDO ESPECIFICACION MONO-TABLA: pkgca_tkr_horarios_profesional
SQL> PROMPT =========================================================================
=========================================================================
SQL> @@pkgca_tkr_horarios_profesional.pks
SQL> CREATE OR REPLACE PACKAGE pkgca_tkr_horarios_profesional AS
    /*
    || =========================================================================
    || Paquete: pkgca_tkr_horarios_profesional
    || Propósito: Capa de Acceso No-PK y DML Mono-Tabla para la entidad física
    ||            TKR_HORARIOS_PROFESIONAL.
    || Estándar: oracle-plsql-architecture
    || Reglas:
    ||   - Acceso y DML EXCLUSIVAMENTE sobre la tabla TKR_HORARIOS_PROFESIONAL.
    ||   - PROHIBIDO realizar JOINs o interactuar con múltiples tablas en esta capa.
    ||   - Retorno de cursores con SYS_REFCURSOR.
    ||   - PROHIBIDO COMMIT o ROLLBACK en este paquete.
    || =========================================================================
    */

    -- Eliminar todos los horarios asociados a un profesional
    PROCEDURE p_borrar_x_profesional (
        p_id_usuario IN tkr_horarios_profesional.id_usuario%TYPE
    );

    -- Eliminar horarios de un profesional dentro de un rango de vigencia específico
    PROCEDURE p_borrar_x_rango_fechas (
        p_id_usuario    IN tkr_horarios_profesional.id_usuario%TYPE,
        p_fecha_inicial IN tkr_horarios_profesional.fecha_inicial%TYPE,
        p_fecha_final   IN tkr_horarios_profesional.fecha_final%TYPE
    );

    -- Inactivar lógicamente todos los horarios de un profesional
    PROCEDURE p_inactivar_x_profesional (
        p_id_usuario IN tkr_horarios_profesional.id_usuario%TYPE
    );

    -- Consultar horarios registrados para un profesional (solo tabla tkr_horarios_profesional)
    FUNCTION f_consultar_x_profesional (
        p_id_usuario IN tkr_horarios_profesional.id_usuario%TYPE
    ) RETURN SYS_REFCURSOR;

    -- Consultar horarios activos de un profesional vigentes para una fecha de referencia
    FUNCTION f_consultar_vigentes_fecha (
        p_id_usuario IN tkr_horarios_profesional.id_usuario%TYPE,
        p_fecha      IN DATE
    ) RETURN SYS_REFCURSOR;

END pkgca_tkr_horarios_profesional;
Package created.
SQL> PROMPT =========================================================================
=========================================================================
SQL> PROMPT 5. COMPILANDO CUERPO MONO-TABLA: pkgca_tkr_horarios_profesional
5. COMPILANDO CUERPO MONO-TABLA: pkgca_tkr_horarios_profesional
SQL> PROMPT =========================================================================
=========================================================================
SQL> @@pkgca_tkr_horarios_profesional.pkb
SQL> CREATE OR REPLACE PACKAGE BODY pkgca_tkr_horarios_profesional AS
    /*
    || =========================================================================
    || Paquete: pkgca_tkr_horarios_profesional (BODY)
    || Propósito: Implementación de operaciones DML y consultas mono-tabla sobre
    ||            TKR_HORARIOS_PROFESIONAL.
    || Estándar: oracle-plsql-architecture
    || =========================================================================
    */

    -- Eliminar todos los horarios asociados a un profesional
    PROCEDURE p_borrar_x_profesional (
        p_id_usuario IN tkr_horarios_profesional.id_usuario%TYPE
    ) IS
    BEGIN
        DELETE FROM tkr_horarios_profesional
         WHERE id_usuario = p_id_usuario;
    END p_borrar_x_profesional;

    -- Eliminar horarios de un profesional dentro de un rango de vigencia específico
    PROCEDURE p_borrar_x_rango_fechas (
        p_id_usuario    IN tkr_horarios_profesional.id_usuario%TYPE,
        p_fecha_inicial IN tkr_horarios_profesional.fecha_inicial%TYPE,
        p_fecha_final   IN tkr_horarios_profesional.fecha_final%TYPE
    ) IS
    BEGIN
        DELETE FROM tkr_horarios_profesional
         WHERE id_usuario = p_id_usuario
           AND fecha_inicial = p_fecha_inicial
           AND ( (fecha_final IS NULL AND p_fecha_final IS NULL)
                 OR (fecha_final = p_fecha_final) );
    END p_borrar_x_rango_fechas;

    -- Inactivar lógicamente todos los horarios de un profesional
    PROCEDURE p_inactivar_x_profesional (
        p_id_usuario IN tkr_horarios_profesional.id_usuario%TYPE
    ) IS
    BEGIN
        UPDATE tkr_horarios_profesional
           SET activo                  = 0,
               fecha_modificacion      = SYSDATE
         WHERE id_usuario = p_id_usuario
           AND activo     = 1;
    END p_inactivar_x_profesional;

    -- Consultar horarios registrados para un profesional (solo tabla tkr_horarios_profesional)
    FUNCTION f_consultar_x_profesional (
        p_id_usuario IN tkr_horarios_profesional.id_usuario%TYPE
    ) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT id,
                   id_usuario,
                   dia_semana,
                   hora_desde,
                   hora_hasta,
                   fecha_inicial,
                   fecha_final,
                   activo,
                   fecha_creacion
              FROM tkr_horarios_profesional
             WHERE id_usuario = p_id_usuario
             ORDER BY fecha_inicial DESC, dia_semana ASC, hora_desde ASC;
        RETURN v_cursor;
    END f_consultar_x_profesional;

    -- Consultar horarios activos de un profesional vigentes para una fecha de referencia
    FUNCTION f_consultar_vigentes_fecha (
        p_id_usuario IN tkr_horarios_profesional.id_usuario%TYPE,
        p_fecha      IN DATE
    ) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
        v_fecha  DATE := TRUNC(NVL(p_fecha, SYSDATE));
    BEGIN
        OPEN v_cursor FOR
            SELECT id,
                   id_usuario,
                   dia_semana,
                   hora_desde,
                   hora_hasta,
                   fecha_inicial,
                   fecha_final,
                   activo
              FROM tkr_horarios_profesional
             WHERE id_usuario = p_id_usuario
               AND activo = 1
               AND fecha_inicial <= v_fecha
               AND (fecha_final IS NULL OR fecha_final >= v_fecha)
             ORDER BY dia_semana ASC, hora_desde ASC;
        RETURN v_cursor;
    END f_consultar_vigentes_fecha;

END pkgca_tkr_horarios_profesional;
Package body created.
SQL> PROMPT =========================================================================
=========================================================================
SQL> PROMPT 6. COMPILANDO ESPECIFICACION CASOS DE NEGOCIO: PKGCN_HORARIOS
6. COMPILANDO ESPECIFICACION CASOS DE NEGOCIO: PKGCN_HORARIOS
SQL> PROMPT =========================================================================
=========================================================================
SQL> @@pkgcn_horarios.pks
SQL> CREATE OR REPLACE PACKAGE PKGCN_HORARIOS
AS
    /*
    || =========================================================================
    || Paquete: PKGCN_HORARIOS
    || Propósito: Capa Multi-Tabla de Casos de Negocio para la gestión de 
    ||            horarios y ausencias de profesionales en TEKER.
    || Estándar: oracle-plsql-architecture
    || Responsabilidades:
    ||   - Consultas relacionales multi-tabla con sintaxis tradicional Oracle (+).
    ||   - Desestructuración de payloads JSON con JSON_TABLE para inserción multi-tabla.
    ||   - Generación de respuestas JSON estructuradas vía JSON_OBJECT/JSON_ARRAYAGG.
    ||   - Validación de reglas de negocio relacionales (traslapes de horarios por
    ||     día, rango de horas y rango de vigencia por fechas).
    ||   - CERO COMMIT / ROLLBACK (transacciones gobernadas por pkgln_horarios).
    || =========================================================================
    */

    -- 1. Consultar profesionales habilitados (rol 4, estado 1) mediante SYS_REFCURSOR
    FUNCTION f_consultar_profesionales (
        p_filtro_nombre IN VARCHAR2 DEFAULT NULL
    ) RETURN SYS_REFCURSOR;

    -- 2. Consultar profesionales habilitados formateado en JSON CLOB
    PROCEDURE p_consultar_profesionales_json (
        p_filtro_nombre IN  VARCHAR2,
        p_json_salida   OUT CLOB
    );

    -- 3. Validar si existe traslape de horario para un profesional evaluando día, horas y vigencia de fechas
    FUNCTION f_existe_traslape_horario (
        p_id_usuario         IN NUMBER,
        p_dia_semana         IN VARCHAR2,
        p_hora_desde         IN VARCHAR2,
        p_hora_hasta         IN VARCHAR2,
        p_fecha_inicial      IN DATE,
        p_fecha_final        IN DATE DEFAULT NULL,
        p_id_horario_excluir IN NUMBER DEFAULT NULL
    ) RETURN BOOLEAN;

    -- 4. Desestructuración de JSON e inserción masiva de horarios con rango de fechas
    PROCEDURE p_guardar_horarios_profesional (
        p_id_usuario    IN NUMBER,
        p_json_horarios IN CLOB
    );

    -- 5. Consultar agenda integral de un profesional (horarios vigentes y ausencias) en JSON CLOB
    PROCEDURE p_consultar_agenda_profesional_json (
        p_id_usuario  IN  NUMBER,
        p_json_salida OUT CLOB
    );

    -- 6. Consultar ausencias en JSON (procedimiento de soporte y retrocompatibilidad)
    PROCEDURE pr_consultar_ausencias_json (
        p_json      IN  CLOB,
        p_resultado OUT CLOB
    );

END PKGCN_HORARIOS;
Package created.
SQL> PROMPT =========================================================================
=========================================================================
SQL> PROMPT 7. COMPILANDO CUERPO CASOS DE NEGOCIO: PKGCN_HORARIOS
7. COMPILANDO CUERPO CASOS DE NEGOCIO: PKGCN_HORARIOS
SQL> PROMPT =========================================================================
=========================================================================
SQL> @@pkgcn_horarios.pkb
SQL> CREATE OR REPLACE PACKAGE BODY PKGCN_HORARIOS
AS
    /*
    || =========================================================================
    || Paquete: PKGCN_HORARIOS (Body)
    || Propósito: Implementación de la capa multi-tabla de casos de negocio para
    ||            horarios y ausencias de profesionales.
    || Estándar: oracle-plsql-architecture
    || =========================================================================
    */

    -- 1. Consultar profesionales habilitados mediante SYS_REFCURSOR
    FUNCTION f_consultar_profesionales (
        p_filtro_nombre IN VARCHAR2 DEFAULT NULL
    ) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT u.id,
                   TRIM(u.nombres || ' ' || u.apellidos) AS nombre_completo,
                   u.nombres,
                   u.apellidos,
                   u.correo_electronico,
                   pkgcn_profesionales.f_url_foto_profesional(u.id) AS url_foto
              FROM tkr_usuarios      u,
                   tkr_roles_usuario ru
             WHERE ru.id_usuario = u.id
               AND ru.id_rol = 4
               AND u.id_estado_usuario = 1
               AND (
                   p_filtro_nombre IS NULL
                   OR UPPER(u.nombres || ' ' || u.apellidos) LIKE '%' || UPPER(TRIM(p_filtro_nombre)) || '%'
                   OR UPPER(u.correo_electronico) LIKE '%' || UPPER(TRIM(p_filtro_nombre)) || '%'
               )
             ORDER BY u.nombres ASC, u.apellidos ASC;
        RETURN v_cursor;
    END f_consultar_profesionales;

    -- 2. Consultar profesionales habilitados formateado en JSON CLOB
    PROCEDURE p_consultar_profesionales_json (
        p_filtro_nombre IN  VARCHAR2,
        p_json_salida   OUT CLOB
    ) IS
    BEGIN
        SELECT JSON_OBJECT(
                   'codigo'  VALUE 0,
                   'mensaje' VALUE 'Profesionales consultados exitosamente',
                   'datos'   VALUE COALESCE(
                       JSON_ARRAYAGG(
                           JSON_OBJECT(
                               'id_usuario'       VALUE u.id,
                               'nombre_completo'  VALUE TRIM(u.nombres || ' ' || u.apellidos),
                               'nombres'          VALUE u.nombres,
                               'apellidos'        VALUE u.apellidos,
                               'correo'           VALUE u.correo_electronico,
                               'url_foto'         VALUE pkgcn_profesionales.f_url_foto_profesional(u.id)
                           )
                           ORDER BY u.nombres, u.apellidos
                       ),
                       JSON_ARRAY()
                   )
                   RETURNING CLOB
               )
          INTO p_json_salida
          FROM tkr_usuarios      u,
               tkr_roles_usuario ru
         WHERE ru.id_usuario = u.id
           AND ru.id_rol = 4
           AND u.id_estado_usuario = 1
           AND (
               p_filtro_nombre IS NULL
               OR UPPER(u.nombres || ' ' || u.apellidos) LIKE '%' || UPPER(TRIM(p_filtro_nombre)) || '%'
               OR UPPER(u.correo_electronico) LIKE '%' || UPPER(TRIM(p_filtro_nombre)) || '%'
           );
    END p_consultar_profesionales_json;

    -- 3. Validar si existe traslape de horario para un profesional evaluando día, horas y vigencia de fechas
    FUNCTION f_existe_traslape_horario (
        p_id_usuario         IN NUMBER,
        p_dia_semana         IN VARCHAR2,
        p_hora_desde         IN VARCHAR2,
        p_hora_hasta         IN VARCHAR2,
        p_fecha_inicial      IN DATE,
        p_fecha_final        IN DATE DEFAULT NULL,
        p_id_horario_excluir IN NUMBER DEFAULT NULL
    ) RETURN BOOLEAN IS
        v_conteo    NUMBER := 0;
        v_fin_nuevo DATE   := NVL(p_fecha_final, TO_DATE('9999-12-31', 'YYYY-MM-DD'));
    BEGIN
        SELECT COUNT(*)
          INTO v_conteo
          FROM tkr_horarios_profesional h
         WHERE h.id_usuario = p_id_usuario
           AND h.dia_semana = UPPER(TRIM(p_dia_semana))
           AND h.activo = 1
           AND (p_id_horario_excluir IS NULL OR h.id <> p_id_horario_excluir)
           -- 1. Intersección de rangos de fechas (vigencia)
           AND p_fecha_inicial <= NVL(h.fecha_final, TO_DATE('9999-12-31', 'YYYY-MM-DD'))
           AND v_fin_nuevo     >= h.fecha_inicial
           -- 2. Intersección de rangos de horas dentro del mismo día
           AND p_hora_desde < h.hora_hasta
           AND p_hora_hasta > h.hora_desde;

        RETURN (v_conteo > 0);
    END f_existe_traslape_horario;

    -- 4. Desestructuración de JSON e inserción masiva de horarios con rango de fechas
    PROCEDURE p_guardar_horarios_profesional (
        p_id_usuario    IN NUMBER,
        p_json_horarios IN CLOB
    ) IS
    BEGIN
        INSERT INTO tkr_horarios_profesional (
            id,
            id_usuario,
            dia_semana,
            hora_desde,
            hora_hasta,
            fecha_inicial,
            fecha_final,
            activo,
            fecha_creacion
        )
        SELECT tkr_horarios_profesional_seq.NEXTVAL,
               p_id_usuario,
               UPPER(TRIM(jt.dia_semana)),
               TRIM(jt.hora_desde),
               TRIM(jt.hora_hasta),
               TO_DATE(TRIM(jt.fecha_inicial), 'YYYY-MM-DD'),
               CASE 
                   WHEN TRIM(jt.fecha_final) IS NOT NULL AND TRIM(jt.fecha_final) <> '' 
                   THEN TO_DATE(TRIM(jt.fecha_final), 'YYYY-MM-DD')
                   ELSE NULL
               END,
               1,
               SYSDATE
          FROM JSON_TABLE(p_json_horarios, '$.horarios[*]'
                   COLUMNS (
                       dia_semana    VARCHAR2(10) PATH '$.dia_semana',
                       hora_desde    VARCHAR2(10) PATH '$.hora_desde',
                       hora_hasta    VARCHAR2(10) PATH '$.hora_hasta',
                       fecha_inicial VARCHAR2(20) PATH '$.fecha_inicial',
                       fecha_final   VARCHAR2(20) PATH '$.fecha_final'
                   )
               ) jt;
    END p_guardar_horarios_profesional;

    -- 5. Consultar agenda integral de un profesional (horarios vigentes y ausencias) en JSON CLOB
    PROCEDURE p_consultar_agenda_profesional_json (
        p_id_usuario  IN  NUMBER,
        p_json_salida OUT CLOB
    ) IS
        v_json_profesional CLOB;
        v_json_horarios    CLOB;
        v_json_ausencias   CLOB;
    BEGIN
        -- A. Datos de cabecera del profesional (multi-tabla)
        SELECT JSON_OBJECT(
                   'id_usuario'      VALUE u.id,
                   'nombre_completo' VALUE TRIM(u.nombres || ' ' || u.apellidos),
                   'nombres'         VALUE u.nombres,
                   'apellidos'       VALUE u.apellidos,
                   'correo'          VALUE u.correo_electronico,
                   'url_foto'        VALUE pkgcn_profesionales.f_url_foto_profesional(u.id)
                   RETURNING CLOB
               )
          INTO v_json_profesional
          FROM tkr_usuarios      u,
               tkr_roles_usuario ru
         WHERE ru.id_usuario = u.id
           AND ru.id_rol = 4
           AND u.id = p_id_usuario;

        -- B. Horarios registrados del profesional con su rango de vigencia
        SELECT COALESCE(
                   JSON_ARRAYAGG(
                       JSON_OBJECT(
                           'id'            VALUE h.id,
                           'dia_semana'    VALUE h.dia_semana,
                           'hora_desde'    VALUE h.hora_desde,
                           'hora_hasta'    VALUE h.hora_hasta,
                           'fecha_inicial' VALUE TO_CHAR(h.fecha_inicial, 'YYYY-MM-DD'),
                           'fecha_final'   VALUE TO_CHAR(h.fecha_final, 'YYYY-MM-DD'),
                           'activo'        VALUE h.activo
                       )
                       ORDER BY CASE h.dia_semana
                                    WHEN 'LU' THEN 1
                                    WHEN 'MA' THEN 2
                                    WHEN 'MI' THEN 3
                                    WHEN 'JU' THEN 4
                                    WHEN 'VI' THEN 5
                                    WHEN 'SA' THEN 6
                                    WHEN 'DO' THEN 7
                                    ELSE 8
                                END,
                                h.hora_desde
                   ),
                   JSON_ARRAY()
               )
          INTO v_json_horarios
          FROM tkr_horarios_profesional h
         WHERE h.id_usuario = p_id_usuario
           AND h.activo = 1;

        -- C. Ausencias programadas del profesional
        SELECT COALESCE(
                   JSON_ARRAYAGG(
                       JSON_OBJECT(
                           'id'           VALUE a.id,
                           'id_usuario'   VALUE a.id_usuario,
                           'fecha_inicio' VALUE TO_CHAR(a.fecha_inicio, 'YYYY-MM-DD"T"HH24:MI:SS'),
                           'fecha_fin'    VALUE TO_CHAR(a.fecha_fin, 'YYYY-MM-DD"T"HH24:MI:SS'),
                           'motivo'       VALUE a.motivo
                       )
                       ORDER BY a.fecha_inicio ASC
                   ),
                   JSON_ARRAY()
               )
          INTO v_json_ausencias
          FROM tkr_ausencias_profesional a
         WHERE a.id_usuario = p_id_usuario;

        -- D. Consolidación de respuesta JSON
        p_json_salida := JSON_OBJECT(
                             'codigo'      VALUE 0,
                             'mensaje'     VALUE 'Agenda de profesional recuperada con éxito',
                             'profesional' VALUE JSON(v_json_profesional),
                             'horarios'    VALUE JSON(v_json_horarios),
                             'ausencias'   VALUE JSON(v_json_ausencias)
                             RETURNING CLOB
                         );
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_json_salida := JSON_OBJECT(
                                 'codigo'  VALUE -20002,
                                 'mensaje' VALUE 'Profesional no encontrado o no activo con rol médico',
                                 'datos'   VALUE NULL
                                 RETURNING CLOB
                             );
    END p_consultar_agenda_profesional_json;

    -- 6. Consultar ausencias en JSON (soporte y retrocompatibilidad)
    PROCEDURE pr_consultar_ausencias_json (
        p_json      IN  CLOB,
        p_resultado OUT CLOB
    ) IS
        v_cursor        SYS_REFCURSOR;
        v_id_usuario    NUMBER;
        v_fecha_inicio  DATE;
        v_fecha_fin     DATE;
    BEGIN
        SELECT jt.id_usuario,
               TO_DATE(jt.fecha_inicio, 'YYYY-MM-DD'),
               TO_DATE(jt.fecha_fin, 'YYYY-MM-DD')
          INTO v_id_usuario,
               v_fecha_inicio,
               v_fecha_fin
          FROM JSON_TABLE(p_json, '$'
                   COLUMNS (
                       id_usuario   NUMBER       PATH '$.id_usuario',
                       fecha_inicio VARCHAR2(20) PATH '$.fecha_inicio',
                       fecha_fin    VARCHAR2(20) PATH '$.fecha_fin'
                   )
               ) jt;

        v_cursor := pkgca_tkr_ausencias_profesional.fn_consultar_ausencias(
                        p_id_usuario   => v_id_usuario,
                        p_fecha_inicio => v_fecha_inicio,
                        p_fecha_fin    => v_fecha_fin
                    );

        SELECT JSON_OBJECT(
                   'codigo'  VALUE 0,
                   'mensaje' VALUE 'Ausencias consultadas exitosamente',
                   'datos'   VALUE COALESCE(
                       JSON_ARRAYAGG(
                           JSON_OBJECT(
                               'id'           VALUE a.id,
                               'id_usuario'   VALUE a.id_usuario,
                               'fecha_inicio' VALUE TO_CHAR(a.fecha_inicio, 'YYYY-MM-DD"T"HH24:MI:SS'),
                               'fecha_fin'    VALUE TO_CHAR(a.fecha_fin, 'YYYY-MM-DD"T"HH24:MI:SS'),
                               'motivo'       VALUE a.motivo
                           )
                       ),
                       JSON_ARRAY()
                   )
                   RETURNING CLOB
               )
          INTO p_resultado
          FROM tkr_ausencias_profesional a
         WHERE a.id_usuario = v_id_usuario
           AND (v_fecha_inicio IS NULL OR a.fecha_fin >= v_fecha_inicio)
           AND (v_fecha_fin IS NULL OR a.fecha_inicio <= v_fecha_fin);

        IF v_cursor%ISOPEN THEN
            CLOSE v_cursor;
        END IF;
    END pr_consultar_ausencias_json;

END PKGCN_HORARIOS;
Warning: compiled but with compilation errors
SQL> PROMPT =========================================================================
=========================================================================
SQL> PROMPT 8. COMPILANDO ESPECIFICACION ORQUESTADOR TRANSACCIONAL: PKGLN_HORARIOS
8. COMPILANDO ESPECIFICACION ORQUESTADOR TRANSACCIONAL: PKGLN_HORARIOS
SQL> PROMPT =========================================================================
=========================================================================
SQL> @@pkgln_horarios.pks
SQL> CREATE OR REPLACE PACKAGE PKGLN_HORARIOS
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
Package created.
SQL> PROMPT =========================================================================
=========================================================================
SQL> PROMPT 9. COMPILANDO CUERPO ORQUESTADOR TRANSACCIONAL: PKGLN_HORARIOS
9. COMPILANDO CUERPO ORQUESTADOR TRANSACCIONAL: PKGLN_HORARIOS
SQL> PROMPT =========================================================================
=========================================================================
SQL> @@pkgln_horarios.pkb
SQL> CREATE OR REPLACE PACKAGE BODY PKGLN_HORARIOS
AS
    /*
    || =========================================================================
    || Paquete: PKGLN_HORARIOS (Body)
    || Propósito: Orquestación transaccional para horarios y ausencias de profesionales
    || Estándar: oracle-plsql-architecture
    || Reglas:
    ||   - PROHIBIDO: Cero SQL directo (SELECT, INSERT, UPDATE, DELETE).
    ||   - Delegación estricta a pkgca_, pkgcn_ y DAOs.
    ||   - Transaccionalidad mediante p_do_commit('<paquete>.<metodo>').
    ||   - Telemetría centralizada con uti_manejo_trazas_pkg.
    ||   - Manejo forense de excepciones con uti_ge_excepciones_pkg.p_grabar_log.
    || =========================================================================
    */

    vro_error tkr_errores%ROWTYPE;

    -- Función utilitaria interna para parsear fechas ISO
    FUNCTION f_parsear_fecha (
        p_str_fecha IN VARCHAR2
    ) RETURN DATE IS
        v_fecha  DATE;
        v_limpia VARCHAR2(50);
    BEGIN
        IF p_str_fecha IS NULL THEN
            RETURN NULL;
        END IF;

        v_limpia := SUBSTR(TRIM(p_str_fecha), 1, 10);

        BEGIN
            v_fecha := TO_DATE(v_limpia, 'YYYY-MM-DD');
        EXCEPTION
            WHEN OTHERS THEN
                BEGIN
                    v_fecha := TO_DATE(SUBSTR(TRIM(p_str_fecha), 1, 19), 'YYYY-MM-DD"T"HH24:MI:SS');
                EXCEPTION
                    WHEN OTHERS THEN
                        v_fecha := TO_DATE(SUBSTR(TRIM(p_str_fecha), 1, 19), 'YYYY-MM-DD HH24:MI:SS');
                END;
        END;

        RETURN TRUNC(v_fecha);
    END f_parsear_fecha;

    -- 1. Listar profesionales habilitados
    PROCEDURE p_listar_profesionales (
        p_json_entrada IN  CLOB,
        p_json_salida  OUT CLOB
    ) IS
        v_obj_in                JSON_OBJECT_T;
        v_filtro                VARCHAR2(200);
        v_id_usuario_ejecutor   NUMBER(12);
        v_codigo_traza          VARCHAR2(100);
        v_ip_origen             VARCHAR2(50);
        
        -- Telemetría
        v_traza_activa          BOOLEAN := FALSE;
        v_id_config_traza       NUMBER(12);
        v_id_traza_ejecucion    NUMBER(12);
        v_nivel_detalle_traza   VARCHAR2(30) := 'COMPLETO';
        v_grabar_payloads_traza NUMBER(1) := 1;
        v_fecha_inicio_traza    TIMESTAMP := SYSTIMESTAMP;
    BEGIN
        -- Parseo de payload
        IF p_json_entrada IS NOT NULL THEN
            BEGIN
                v_obj_in              := JSON_OBJECT_T.parse(p_json_entrada);
                v_filtro              := v_obj_in.get_string('filtro');
                v_id_usuario_ejecutor := v_obj_in.get_number('id_usuario_ejecutor');
                v_codigo_traza        := v_obj_in.get_string('codigo_traza');
                v_ip_origen           := v_obj_in.get_string('ip_origen');
            EXCEPTION
                WHEN OTHERS THEN
                    NULL;
            END;
        END IF;

        -- Telemetría
        v_traza_activa := uti_manejo_trazas_pkg.f_debe_trazar(
            p_nombre_paquete => 'PKGLN_HORARIOS',
            p_nombre_metodo  => 'p_listar_profesionales',
            p_id_usuario     => v_id_usuario_ejecutor,
            p_id_config_out  => v_id_config_traza,
            p_nivel_out      => v_nivel_detalle_traza,
            p_grabar_pay_out => v_grabar_payloads_traza
        );

        IF v_traza_activa THEN
            uti_manejo_trazas_pkg.p_iniciar_traza(
                p_nombre_paquete   => 'PKGLN_HORARIOS',
                p_nombre_metodo    => 'p_listar_profesionales',
                p_id_config        => v_id_config_traza,
                p_id_usuario       => v_id_usuario_ejecutor,
                p_codigo_traza     => v_codigo_traza,
                p_ip_origen        => v_ip_origen,
                p_json_entrada     => p_json_entrada,
                p_grabar_payload   => v_grabar_payloads_traza,
                p_id_ejecucion_out => v_id_traza_ejecucion
            );
        END IF;

        -- Delegación a caso de negocio JSON
        PKGCN_HORARIOS.p_consultar_profesionales_json(
            p_filtro_nombre => v_filtro,
            p_json_salida   => p_json_salida
        );

        -- Cierre de traza
        IF v_traza_activa AND v_id_traza_ejecucion IS NOT NULL THEN
            uti_manejo_trazas_pkg.p_finalizar_traza(
                p_id_ejecucion   => v_id_traza_ejecucion,
                p_fecha_inicio   => v_fecha_inicio_traza,
                p_json_salida    => p_json_salida,
                p_grabar_payload => v_grabar_payloads_traza
            );
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            IF v_traza_activa AND v_id_traza_ejecucion IS NOT NULL THEN
                uti_manejo_trazas_pkg.p_finalizar_traza_error(
                    p_id_ejecucion  => v_id_traza_ejecucion,
                    p_fecha_inicio  => v_fecha_inicio_traza,
                    p_codigo_error  => SQLCODE,
                    p_mensaje_error => SQLERRM
                );
            END IF;

            vro_error.id_usuario      := v_id_usuario_ejecutor;
            vro_error.codigo_traza    := v_codigo_traza;
            vro_error.nombre_programa := 'PKGLN_HORARIOS';
            vro_error.nombre_metodo   := 'p_listar_profesionales';
            vro_error.codigo_error    := SQLCODE;
            vro_error.mensaje_error   := SUBSTR(SQLERRM, 1, 4000);
            vro_error.traza_error     := DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
            vro_error.pila_llamadas   := DBMS_UTILITY.FORMAT_CALL_STACK;
            vro_error.payload_entrada := p_json_entrada;
            vro_error.direccion_ip    := v_ip_origen;

            uti_ge_excepciones_pkg.p_grabar_log(vro_error);

            RAISE_APPLICATION_ERROR(
                -20000,
                'Se presento un error comunicarse con soporte. Número error: '
                || vro_error.id
                || ' - '
                || SQLERRM
            );
    END p_listar_profesionales;

    -- 2. Guardar y sincronizar horarios multi-rango
    PROCEDURE p_guardar_horarios (
        p_json_entrada IN  CLOB,
        p_json_salida  OUT CLOB
    ) IS
        v_obj_in                JSON_OBJECT_T;
        v_arr_horarios          JSON_ARRAY_T;
        v_elem_horario          JSON_OBJECT_T;
        v_id_usuario            NUMBER(12);
        v_reemplazar_todo       NUMBER(1) := 1;
        v_dia_semana            VARCHAR2(10);
        v_hora_desde            VARCHAR2(10);
        v_hora_hasta            VARCHAR2(10);
        v_fecha_inicial_str     VARCHAR2(30);
        v_fecha_final_str       VARCHAR2(30);
        v_fecha_inicial         DATE;
        v_fecha_final           DATE;
        v_codigo_traza          VARCHAR2(100);
        v_ip_origen             VARCHAR2(50);
        v_resp_obj              JSON_OBJECT_T;

        -- Telemetría
        v_traza_activa          BOOLEAN := FALSE;
        v_id_config_traza       NUMBER(12);
        v_id_traza_ejecucion    NUMBER(12);
        v_nivel_detalle_traza   VARCHAR2(30) := 'COMPLETO';
        v_grabar_payloads_traza NUMBER(1) := 1;
        v_fecha_inicio_traza    TIMESTAMP := SYSTIMESTAMP;
    BEGIN
        IF p_json_entrada IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'El payload de entrada JSON no puede ser nulo.');
        END IF;

        v_obj_in          := JSON_OBJECT_T.parse(p_json_entrada);
        v_id_usuario      := v_obj_in.get_number('id_usuario');
        v_reemplazar_todo := NVL(v_obj_in.get_number('reemplazar_todo'), 1);
        v_codigo_traza    := v_obj_in.get_string('codigo_traza');
        v_ip_origen       := v_obj_in.get_string('ip_origen');

        IF v_id_usuario IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'El identificador del profesional (id_usuario) es obligatorio.');
        END IF;

        -- Telemetría
        v_traza_activa := uti_manejo_trazas_pkg.f_debe_trazar(
            p_nombre_paquete => 'PKGLN_HORARIOS',
            p_nombre_metodo  => 'p_guardar_horarios',
            p_id_usuario     => v_id_usuario,
            p_id_config_out  => v_id_config_traza,
            p_nivel_out      => v_nivel_detalle_traza,
            p_grabar_pay_out => v_grabar_payloads_traza
        );

        IF v_traza_activa THEN
            uti_manejo_trazas_pkg.p_iniciar_traza(
                p_nombre_paquete   => 'PKGLN_HORARIOS',
                p_nombre_metodo    => 'p_guardar_horarios',
                p_id_config        => v_id_config_traza,
                p_id_usuario       => v_id_usuario,
                p_codigo_traza     => v_codigo_traza,
                p_ip_origen        => v_ip_origen,
                p_json_entrada     => p_json_entrada,
                p_grabar_payload   => v_grabar_payloads_traza,
                p_id_ejecucion_out => v_id_traza_ejecucion
            );
        END IF;

        -- Validación de la estructura del arreglo de horarios
        IF v_obj_in.has('horarios') THEN
            v_arr_horarios := v_obj_in.get_array('horarios');
            FOR i IN 0 .. v_arr_horarios.get_size - 1 LOOP
                v_elem_horario      := JSON_OBJECT_T(v_arr_horarios.get(i));
                v_dia_semana        := UPPER(TRIM(v_elem_horario.get_string('dia_semana')));
                v_hora_desde        := TRIM(v_elem_horario.get_string('hora_desde'));
                v_hora_hasta        := TRIM(v_elem_horario.get_string('hora_hasta'));
                v_fecha_inicial_str := TRIM(v_elem_horario.get_string('fecha_inicial'));
                v_fecha_final_str   := TRIM(v_elem_horario.get_string('fecha_final'));

                IF v_dia_semana NOT IN ('LU', 'MA', 'MI', 'JU', 'VI', 'SA', 'DO') THEN
                    RAISE_APPLICATION_ERROR(-20002, 'Día de la semana inválido (' || v_dia_semana || '). Debe ser LU, MA, MI, JU, VI, SA o DO.');
                END IF;

                IF v_hora_desde >= v_hora_hasta THEN
                    RAISE_APPLICATION_ERROR(-20003, 'La hora inicial (' || v_hora_desde || ') debe ser menor que la hora final (' || v_hora_hasta || ').');
                END IF;

                -- Validación de fecha_inicial obligatoria
                IF v_fecha_inicial_str IS NULL OR v_fecha_inicial_str = '' THEN
                    RAISE_APPLICATION_ERROR(-20004, 'La fecha inicial es obligatoria para cada horario configurado (formato YYYY-MM-DD).');
                END IF;

                BEGIN
                    v_fecha_inicial := TO_DATE(v_fecha_inicial_str, 'YYYY-MM-DD');
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE_APPLICATION_ERROR(-20005, 'Formato inválido en fecha_inicial (' || v_fecha_inicial_str || '). Se espera YYYY-MM-DD.');
                END;

                -- Validación de fecha_final opcional
                IF v_fecha_final_str IS NOT NULL AND v_fecha_final_str <> '' THEN
                    BEGIN
                        v_fecha_final := TO_DATE(v_fecha_final_str, 'YYYY-MM-DD');
                    EXCEPTION
                        WHEN OTHERS THEN
                            RAISE_APPLICATION_ERROR(-20006, 'Formato inválido en fecha_final (' || v_fecha_final_str || '). Se espera YYYY-MM-DD.');
                    END;

                    IF v_fecha_final < v_fecha_inicial THEN
                        RAISE_APPLICATION_ERROR(-20007, 'La fecha final (' || v_fecha_final_str || ') no puede ser menor a la fecha inicial (' || v_fecha_inicial_str || ').');
                    END IF;
                ELSE
                    v_fecha_final := NULL;
                END IF;

                -- Validación interna de no solapamiento con los demás rangos del payload para el mismo día
                FOR j IN (i + 1) .. v_arr_horarios.get_size - 1 LOOP
                    DECLARE
                        v_comp_elem     JSON_OBJECT_T := JSON_OBJECT_T(v_arr_horarios.get(j));
                        v_comp_dia      VARCHAR2(10)  := UPPER(TRIM(v_comp_elem.get_string('dia_semana')));
                        v_comp_desde    VARCHAR2(10)  := TRIM(v_comp_elem.get_string('hora_desde'));
                        v_comp_hasta    VARCHAR2(10)  := TRIM(v_comp_elem.get_string('hora_hasta'));
                        v_comp_ini_str  VARCHAR2(30)  := TRIM(v_comp_elem.get_string('fecha_inicial'));
                        v_comp_fin_str  VARCHAR2(30)  := TRIM(v_comp_elem.get_string('fecha_final'));
                        v_comp_ini      DATE;
                        v_comp_fin      DATE;
                        v_fin_eff_1     DATE;
                        v_fin_eff_2     DATE;
                    BEGIN
                        IF v_dia_semana = v_comp_dia THEN
                            v_comp_ini := TO_DATE(v_comp_ini_str, 'YYYY-MM-DD');
                            IF v_comp_fin_str IS NOT NULL AND v_comp_fin_str <> '' THEN
                                v_comp_fin := TO_DATE(v_comp_fin_str, 'YYYY-MM-DD');
                            ELSE
                                v_comp_fin := NULL;
                            END IF;

                            v_fin_eff_1 := NVL(v_fecha_final, TO_DATE('9999-12-31', 'YYYY-MM-DD'));
                            v_fin_eff_2 := NVL(v_comp_fin, TO_DATE('9999-12-31', 'YYYY-MM-DD'));

                            -- Se solapan si las vigencias de fechas coinciden Y las horas coinciden
                            IF (v_fecha_inicial <= v_fin_eff_2 AND v_fin_eff_1 >= v_comp_ini)
                               AND (v_hora_desde < v_comp_hasta AND v_hora_hasta > v_comp_desde) THEN
                                RAISE_APPLICATION_ERROR(
                                    -20008,
                                    'Existe traslape entre los rangos configurados para el día '
                                    || v_dia_semana || ' en el período [' || v_fecha_inicial_str
                                    || ' a ' || NVL(v_fecha_final_str, 'indefinido') || '] con horas ['
                                    || v_hora_desde || '-' || v_hora_hasta || '] y ['
                                    || v_comp_desde || '-' || v_comp_hasta || '].'
                                );
                            END IF;
                        END IF;
                    END;
                END LOOP;

                -- Si no es reemplazo total, valida contra los horarios ya existentes en base de datos
                IF v_reemplazar_todo = 0 THEN
                    IF PKGCN_HORARIOS.f_existe_traslape_horario(
                           p_id_usuario    => v_id_usuario,
                           p_dia_semana    => v_dia_semana,
                           p_hora_desde    => v_hora_desde,
                           p_hora_hasta    => v_hora_hasta,
                           p_fecha_inicial => v_fecha_inicial,
                           p_fecha_final   => v_fecha_final
                       ) THEN
                        RAISE_APPLICATION_ERROR(
                            -20009,
                            'El horario para el día ' || v_dia_semana || ' [' || v_hora_desde
                            || '-' || v_hora_hasta || '] se traslapa con un horario ya registrado en ese rango de fechas.'
                        );
                    END IF;
                END IF;

            END LOOP;
        END IF;

        -- 1. Si es reemplazo completo, borra horarios existentes de la tabla única
        IF v_reemplazar_todo = 1 THEN
            pkgca_tkr_horarios_profesional.p_borrar_x_profesional(
                p_id_usuario => v_id_usuario
            );
        END IF;

        -- 2. Inserción de los nuevos rangos horarios vía PKGCN (desestructuración JSON_TABLE con fechas)
        IF v_arr_horarios IS NOT NULL AND v_arr_horarios.get_size > 0 THEN
            PKGCN_HORARIOS.p_guardar_horarios_profesional(
                p_id_usuario    => v_id_usuario,
                p_json_horarios => p_json_entrada
            );
        END IF;

        -- 3. Confirmación transaccional controlada
        p_do_commit('PKGLN_HORARIOS.p_guardar_horarios');

        -- 4. Construcción de respuesta JSON
        v_resp_obj := JSON_OBJECT_T();
        v_resp_obj.put('codigo', 0);
        v_resp_obj.put('mensaje', 'Horarios del profesional guardados exitosamente.');
        v_resp_obj.put('id_usuario', v_id_usuario);
        p_json_salida := v_resp_obj.to_clob();

        -- 5. Cierre de telemetría exitosa
        IF v_traza_activa AND v_id_traza_ejecucion IS NOT NULL THEN
            uti_manejo_trazas_pkg.p_finalizar_traza(
                p_id_ejecucion   => v_id_traza_ejecucion,
                p_fecha_inicio   => v_fecha_inicio_traza,
                p_json_salida    => p_json_salida,
                p_grabar_payload => v_grabar_payloads_traza
            );
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            IF v_traza_activa AND v_id_traza_ejecucion IS NOT NULL THEN
                uti_manejo_trazas_pkg.p_finalizar_traza_error(
                    p_id_ejecucion  => v_id_traza_ejecucion,
                    p_fecha_inicio  => v_fecha_inicio_traza,
                    p_codigo_error  => SQLCODE,
                    p_mensaje_error => SQLERRM
                );
            END IF;

            IF SQLCODE BETWEEN -20999 AND -20001 THEN
                RAISE;
            END IF;

            vro_error.id_usuario      := v_id_usuario;
            vro_error.codigo_traza    := v_codigo_traza;
            vro_error.nombre_programa := 'PKGLN_HORARIOS';
            vro_error.nombre_metodo   := 'p_guardar_horarios';
            vro_error.codigo_error    := SQLCODE;
            vro_error.mensaje_error   := SUBSTR(SQLERRM, 1, 4000);
            vro_error.traza_error     := DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
            vro_error.pila_llamadas   := DBMS_UTILITY.FORMAT_CALL_STACK;
            vro_error.payload_entrada := p_json_entrada;
            vro_error.direccion_ip    := v_ip_origen;

            uti_ge_excepciones_pkg.p_grabar_log(vro_error);

            RAISE_APPLICATION_ERROR(
                -20000,
                'Se presento un error comunicarse con soporte. Número error: '
                || vro_error.id
                || ' - '
                || SQLERRM
            );
    END p_guardar_horarios;

    -- 3. Consultar agenda completa de un profesional
    PROCEDURE p_consultar_agenda (
        p_json_entrada IN  CLOB,
        p_json_salida  OUT CLOB
    ) IS
        v_obj_in                JSON_OBJECT_T;
        v_id_usuario            NUMBER(12);
        v_codigo_traza          VARCHAR2(100);
        v_ip_origen             VARCHAR2(50);

        -- Telemetría
        v_traza_activa          BOOLEAN := FALSE;
        v_id_config_traza       NUMBER(12);
        v_id_traza_ejecucion    NUMBER(12);
        v_nivel_detalle_traza   VARCHAR2(30) := 'COMPLETO';
        v_grabar_payloads_traza NUMBER(1) := 1;
        v_fecha_inicio_traza    TIMESTAMP := SYSTIMESTAMP;
    BEGIN
        IF p_json_entrada IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'El payload de entrada no puede ser nulo.');
        END IF;

        v_obj_in       := JSON_OBJECT_T.parse(p_json_entrada);
        v_id_usuario   := v_obj_in.get_number('id_usuario');
        v_codigo_traza := v_obj_in.get_string('codigo_traza');
        v_ip_origen    := v_obj_in.get_string('ip_origen');

        IF v_id_usuario IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'El identificador del profesional es obligatorio.');
        END IF;

        v_traza_activa := uti_manejo_trazas_pkg.f_debe_trazar(
            p_nombre_paquete => 'PKGLN_HORARIOS',
            p_nombre_metodo  => 'p_consultar_agenda',
            p_id_usuario     => v_id_usuario,
            p_id_config_out  => v_id_config_traza,
            p_nivel_out      => v_nivel_detalle_traza,
            p_grabar_pay_out => v_grabar_payloads_traza
        );

        IF v_traza_activa THEN
            uti_manejo_trazas_pkg.p_iniciar_traza(
                p_nombre_paquete   => 'PKGLN_HORARIOS',
                p_nombre_metodo    => 'p_consultar_agenda',
                p_id_config        => v_id_config_traza,
                p_id_usuario       => v_id_usuario,
                p_codigo_traza     => v_codigo_traza,
                p_ip_origen        => v_ip_origen,
                p_json_entrada     => p_json_entrada,
                p_grabar_payload   => v_grabar_payloads_traza,
                p_id_ejecucion_out => v_id_traza_ejecucion
            );
        END IF;

        -- Consulta consolidada
        PKGCN_HORARIOS.p_consultar_agenda_profesional_json(
            p_id_usuario  => v_id_usuario,
            p_json_salida => p_json_salida
        );

        IF v_traza_activa AND v_id_traza_ejecucion IS NOT NULL THEN
            uti_manejo_trazas_pkg.p_finalizar_traza(
                p_id_ejecucion   => v_id_traza_ejecucion,
                p_fecha_inicio   => v_fecha_inicio_traza,
                p_json_salida    => p_json_salida,
                p_grabar_payload => v_grabar_payloads_traza
            );
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            IF v_traza_activa AND v_id_traza_ejecucion IS NOT NULL THEN
                uti_manejo_trazas_pkg.p_finalizar_traza_error(
                    p_id_ejecucion  => v_id_traza_ejecucion,
                    p_fecha_inicio  => v_fecha_inicio_traza,
                    p_codigo_error  => SQLCODE,
                    p_mensaje_error => SQLERRM
                );
            END IF;

            IF SQLCODE BETWEEN -20999 AND -20001 THEN
                RAISE;
            END IF;

            vro_error.id_usuario      := v_id_usuario;
            vro_error.codigo_traza    := v_codigo_traza;
            vro_error.nombre_programa := 'PKGLN_HORARIOS';
            vro_error.nombre_metodo   := 'p_consultar_agenda';
            vro_error.codigo_error    := SQLCODE;
            vro_error.mensaje_error   := SUBSTR(SQLERRM, 1, 4000);
            vro_error.traza_error     := DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
            vro_error.pila_llamadas   := DBMS_UTILITY.FORMAT_CALL_STACK;
            vro_error.payload_entrada := p_json_entrada;
            vro_error.direccion_ip    := v_ip_origen;

            uti_ge_excepciones_pkg.p_grabar_log(vro_error);

            RAISE_APPLICATION_ERROR(
                -20000,
                'Se presento un error comunicarse con soporte. Número error: '
                || vro_error.id
                || ' - '
                || SQLERRM
            );
    END p_consultar_agenda;

    -- 4. Registrar ausencia de profesional
    PROCEDURE p_registrar_ausencia (
        p_json_entrada IN  CLOB,
        p_json_salida  OUT CLOB
    ) IS
        v_obj_in                JSON_OBJECT_T;
        v_id_usuario            NUMBER(12);
        v_str_inicio            VARCHAR2(50);
        v_str_fin               VARCHAR2(50);
        v_fecha_inicial         DATE;
        v_fecha_final           DATE;
        vro_ausencia            tkr_ausencias_profesional%ROWTYPE;
        v_codigo_traza          VARCHAR2(100);
        v_ip_origen             VARCHAR2(50);
        v_resp_obj              JSON_OBJECT_T;

        -- Telemetría
        v_traza_activa          BOOLEAN := FALSE;
        v_id_config_traza       NUMBER(12);
        v_id_traza_ejecucion    NUMBER(12);
        v_nivel_detalle_traza   VARCHAR2(30) := 'COMPLETO';
        v_grabar_payloads_traza NUMBER(1) := 1;
        v_fecha_inicio_traza    TIMESTAMP := SYSTIMESTAMP;
    BEGIN
        IF p_json_entrada IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'El payload de entrada JSON no puede ser nulo.');
        END IF;

        v_obj_in       := JSON_OBJECT_T.parse(p_json_entrada);
        v_id_usuario   := v_obj_in.get_number('id_usuario');
        v_str_inicio   := v_obj_in.get_string('fecha_inicial');
        v_str_fin      := v_obj_in.get_string('fecha_final');
        v_codigo_traza := v_obj_in.get_string('codigo_traza');
        v_ip_origen    := v_obj_in.get_string('ip_origen');

        IF v_id_usuario IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'El identificador del profesional (id_usuario) es obligatorio.');
        END IF;

        IF v_str_inicio IS NULL OR v_str_fin IS NULL THEN
            RAISE_APPLICATION_ERROR(-20002, 'Las fechas inicial y final son obligatorias.');
        END IF;

        v_fecha_inicial := f_parsear_fecha(v_str_inicio);
        v_fecha_final   := f_parsear_fecha(v_str_fin);

        IF v_fecha_inicial IS NULL OR v_fecha_final IS NULL THEN
            RAISE_APPLICATION_ERROR(-20003, 'Formato de fecha inválido. Utilice YYYY-MM-DD.');
        END IF;

        IF v_fecha_inicial > v_fecha_final THEN
            RAISE_APPLICATION_ERROR(-20004, 'La fecha inicial (' || TO_CHAR(v_fecha_inicial, 'YYYY-MM-DD') || ') no puede ser superior a la final (' || TO_CHAR(v_fecha_final, 'YYYY-MM-DD') || ').');
        END IF;

        -- Telemetría
        v_traza_activa := uti_manejo_trazas_pkg.f_debe_trazar(
            p_nombre_paquete => 'PKGLN_HORARIOS',
            p_nombre_metodo  => 'p_registrar_ausencia',
            p_id_usuario     => v_id_usuario,
            p_id_config_out  => v_id_config_traza,
            p_nivel_out      => v_nivel_detalle_traza,
            p_grabar_pay_out => v_grabar_payloads_traza
        );

        IF v_traza_activa THEN
            uti_manejo_trazas_pkg.p_iniciar_traza(
                p_nombre_paquete   => 'PKGLN_HORARIOS',
                p_nombre_metodo    => 'p_registrar_ausencia',
                p_id_config        => v_id_config_traza,
                p_id_usuario       => v_id_usuario,
                p_codigo_traza     => v_codigo_traza,
                p_ip_origen        => v_ip_origen,
                p_json_entrada     => p_json_entrada,
                p_grabar_payload   => v_grabar_payloads_traza,
                p_id_ejecucion_out => v_id_traza_ejecucion
            );
        END IF;

        -- Persistencia delegada al DAO
        vro_ausencia.id             := NULL; -- Asignado por secuencia o BD
        vro_ausencia.id_usuario     := v_id_usuario;
        vro_ausencia.fecha_inicial  := v_fecha_inicial;
        vro_ausencia.fecha_final    := v_fecha_final;
        vro_ausencia.fecha_creacion := SYSDATE;

        PKGTKR_AUSENCIAS_PROFESIONAL_DAO.p_insertar(vro_ausencia);

        -- Confirmación transaccional
        p_do_commit('PKGLN_HORARIOS.p_registrar_ausencia');

        -- Respuesta
        v_resp_obj := JSON_OBJECT_T();
        v_resp_obj.put('codigo', 0);
        v_resp_obj.put('mensaje', 'Ausencia del profesional registrada exitosamente.');
        v_resp_obj.put('id_usuario', v_id_usuario);
        v_resp_obj.put('fecha_inicial', TO_CHAR(v_fecha_inicial, 'YYYY-MM-DD'));
        v_resp_obj.put('fecha_final', TO_CHAR(v_fecha_final, 'YYYY-MM-DD'));
        p_json_salida := v_resp_obj.to_clob();

        IF v_traza_activa AND v_id_traza_ejecucion IS NOT NULL THEN
            uti_manejo_trazas_pkg.p_finalizar_traza(
                p_id_ejecucion   => v_id_traza_ejecucion,
                p_fecha_inicio   => v_fecha_inicio_traza,
                p_json_salida    => p_json_salida,
                p_grabar_payload => v_grabar_payloads_traza
            );
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            IF v_traza_activa AND v_id_traza_ejecucion IS NOT NULL THEN
                uti_manejo_trazas_pkg.p_finalizar_traza_error(
                    p_id_ejecucion  => v_id_traza_ejecucion,
                    p_fecha_inicio  => v_fecha_inicio_traza,
                    p_codigo_error  => SQLCODE,
                    p_mensaje_error => SQLERRM
                );
            END IF;

            IF SQLCODE BETWEEN -20999 AND -20001 THEN
                RAISE;
            END IF;

            vro_error.id_usuario      := v_id_usuario;
            vro_error.codigo_traza    := v_codigo_traza;
            vro_error.nombre_programa := 'PKGLN_HORARIOS';
            vro_error.nombre_metodo   := 'p_registrar_ausencia';
            vro_error.codigo_error    := SQLCODE;
            vro_error.mensaje_error   := SUBSTR(SQLERRM, 1, 4000);
            vro_error.traza_error     := DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
            vro_error.pila_llamadas   := DBMS_UTILITY.FORMAT_CALL_STACK;
            vro_error.payload_entrada := p_json_entrada;
            vro_error.direccion_ip    := v_ip_origen;

            uti_ge_excepciones_pkg.p_grabar_log(vro_error);

            RAISE_APPLICATION_ERROR(
                -20000,
                'Se presento un error comunicarse con soporte. Número error: '
                || vro_error.id
                || ' - '
                || SQLERRM
            );
    END p_registrar_ausencia;

    -- 5. Consultar ausencias
    PROCEDURE p_consultar_ausencias (
        p_json_entrada IN  CLOB,
        p_json_salida  OUT CLOB
    ) IS
    BEGIN
        PKGCN_HORARIOS.pr_consultar_ausencias_json(
            p_json      => p_json_entrada,
            p_resultado => p_json_salida
        );
    END p_consultar_ausencias;

    -- 6. Eliminar ausencia
    PROCEDURE p_eliminar_ausencia (
        p_json_entrada IN  CLOB,
        p_json_salida  OUT CLOB
    ) IS
        v_obj_in    JSON_OBJECT_T;
        v_id        NUMBER(12);
        v_resp_obj  JSON_OBJECT_T;
    BEGIN
        IF p_json_entrada IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'El payload de entrada no puede ser nulo.');
        END IF;

        v_obj_in := JSON_OBJECT_T.parse(p_json_entrada);
        v_id     := v_obj_in.get_number('id');

        IF v_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'El identificador de la ausencia (id) es obligatorio.');
        END IF;

        IF NOT PKGTKR_AUSENCIAS_PROFESIONAL_DAO.f_existe(v_id) THEN
            RAISE_APPLICATION_ERROR(-20002, 'La ausencia con ID ' || v_id || ' no existe.');
        END IF;

        PKGTKR_AUSENCIAS_PROFESIONAL_DAO.p_eliminar(v_id);

        p_do_commit('PKGLN_HORARIOS.p_eliminar_ausencia');

        v_resp_obj := JSON_OBJECT_T();
        v_resp_obj.put('codigo', 0);
        v_resp_obj.put('mensaje', 'Ausencia eliminada exitosamente.');
        v_resp_obj.put('id', v_id);
        p_json_salida := v_resp_obj.to_clob();

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            IF SQLCODE BETWEEN -20999 AND -20001 THEN
                RAISE;
            END IF;

            vro_error.nombre_programa := 'PKGLN_HORARIOS';
            vro_error.nombre_metodo   := 'p_eliminar_ausencia';
            vro_error.codigo_error    := SQLCODE;
            vro_error.mensaje_error   := SUBSTR(SQLERRM, 1, 4000);
            vro_error.traza_error     := DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
            vro_error.pila_llamadas   := DBMS_UTILITY.FORMAT_CALL_STACK;
            vro_error.payload_entrada := p_json_entrada;

            uti_ge_excepciones_pkg.p_grabar_log(vro_error);

            RAISE_APPLICATION_ERROR(
                -20000,
                'Se presento un error comunicarse con soporte. Número error: '
                || vro_error.id
                || ' - '
                || SQLERRM
            );
    END p_eliminar_ausencia;

    -- =========================================================================
    -- ALIAS DE COMPATIBILIDAD
    -- =========================================================================
    PROCEDURE pr_registrar_ausencia (
        p_json      IN  CLOB,
        p_resultado OUT CLOB
    ) IS
    BEGIN
        p_registrar_ausencia(p_json, p_resultado);
    END pr_registrar_ausencia;

    PROCEDURE pr_actualizar_ausencia (
        p_json      IN  CLOB,
        p_resultado OUT CLOB
    ) IS
        v_obj_in        JSON_OBJECT_T;
        v_id            NUMBER;
        v_id_usuario    NUMBER;
        v_str_inicio    VARCHAR2(50);
        v_str_fin       VARCHAR2(50);
        v_fecha_inicial DATE;
        v_fecha_final   DATE;
        vro_ausencia    tkr_ausencias_profesional%ROWTYPE;
        v_resp_obj      JSON_OBJECT_T;
    BEGIN
        v_obj_in        := JSON_OBJECT_T.parse(p_json);
        v_id            := v_obj_in.get_number('id');
        v_id_usuario    := v_obj_in.get_number('id_usuario');
        v_str_inicio    := v_obj_in.get_string('fecha_inicial');
        v_str_fin       := v_obj_in.get_string('fecha_final');

        IF v_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, 'El ID de la ausencia es obligatorio.');
        END IF;

        IF NOT PKGTKR_AUSENCIAS_PROFESIONAL_DAO.f_existe(v_id, vro_ausencia) THEN
            RAISE_APPLICATION_ERROR(-20002, 'La ausencia no existe.');
        END IF;

        IF v_id_usuario IS NOT NULL THEN
            vro_ausencia.id_usuario := v_id_usuario;
        END IF;

        IF v_str_inicio IS NOT NULL THEN
            v_fecha_inicial := f_parsear_fecha(v_str_inicio);
            vro_ausencia.fecha_inicial := v_fecha_inicial;
        END IF;

        IF v_str_fin IS NOT NULL THEN
            v_fecha_final := f_parsear_fecha(v_str_fin);
            vro_ausencia.fecha_final := v_fecha_final;
        END IF;

        IF vro_ausencia.fecha_inicial > vro_ausencia.fecha_final THEN
            RAISE_APPLICATION_ERROR(-20003, 'La fecha inicial no puede ser superior a la fecha final.');
        END IF;

        PKGTKR_AUSENCIAS_PROFESIONAL_DAO.p_actualizar(vro_ausencia);

        p_do_commit('PKGLN_HORARIOS.pr_actualizar_ausencia');

        v_resp_obj := JSON_OBJECT_T();
        v_resp_obj.put('success', TRUE);
        v_resp_obj.put('message', 'Ausencia actualizada exitosamente.');
        p_resultado := v_resp_obj.to_clob();

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            IF SQLCODE BETWEEN -20999 AND -20001 THEN
                RAISE;
            END IF;
            vro_error.nombre_programa := 'PKGLN_HORARIOS';
            vro_error.nombre_metodo   := 'pr_actualizar_ausencia';
            vro_error.codigo_error    := SQLCODE;
            vro_error.mensaje_error   := SUBSTR(SQLERRM, 1, 4000);
            vro_error.payload_entrada := p_json;
            uti_ge_excepciones_pkg.p_grabar_log(vro_error);
            RAISE_APPLICATION_ERROR(
                -20000,
                'Se presento un error comunicarse con soporte. Número error: '
                || vro_error.id || ' - ' || SQLERRM
            );
    END pr_actualizar_ausencia;

    PROCEDURE pr_obtener_ausencias (
        p_json      IN  CLOB,
        p_resultado OUT CLOB
    ) IS
    BEGIN
        p_consultar_ausencias(p_json, p_resultado);
    END pr_obtener_ausencias;

    PROCEDURE pr_eliminar_ausencia (
        p_json      IN  CLOB,
        p_resultado OUT CLOB
    ) IS
    BEGIN
        p_eliminar_ausencia(p_json, p_resultado);
    END pr_eliminar_ausencia;

END PKGLN_HORARIOS;
Warning: compiled but with compilation errors
SQL> PROMPT =========================================================================
=========================================================================
SQL> PROMPT INSTALACION Y COMPILACION FINALIZADA CON EXITO
INSTALACION Y COMPILACION FINALIZADA CON EXITO
SQL> PROMPT =========================================================================
=========================================================================
