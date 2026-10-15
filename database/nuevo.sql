-- =============================================================================
-- PROYECTO: horario-profesionales
-- ARTEFACTO: nuevo.sql (Script Maestro Director)
-- BASE DE DATOS: Oracle Database (TEKER)
-- FECHA: 14/10/2026
-- DESCRIPCIÓN: Invoca secuencialmente mediante la directiva de SQL*Plus (@@)
--              todos los scripts del proyecto: DDL, DAO, Capa Mono-Tabla (pkgca_),
--              Casos de Negocio Multi-Tabla (pkgcn_) y Orquestador Transaccional (pkgln_).
-- =============================================================================

SET ECHO ON;
SET FEEDBACK ON;
SET DEFINE OFF;

PROMPT =========================================================================
PROMPT 1. CREANDO TABLA, SECUENCIA, INDICES Y TRIGGER: tkr_horarios_profesional
PROMPT =========================================================================
@@tkr_horarios_profesional.sql
SHOW ERRORS TRIGGER trg_bi_tkr_horarios_prof;

PROMPT =========================================================================
PROMPT 2. COMPILANDO ESPECIFICACION DAO: PKGTKR_HORARIOS_PROFESIONAL_DAO
PROMPT =========================================================================
@@pkgtkr_horarios_profesional_dao.pks
SHOW ERRORS PACKAGE PKGTKR_HORARIOS_PROFESIONAL_DAO;

PROMPT =========================================================================
PROMPT 3. COMPILANDO CUERPO DAO: PKGTKR_HORARIOS_PROFESIONAL_DAO
PROMPT =========================================================================
@@pkgtkr_horarios_profesional_dao.pkb
SHOW ERRORS PACKAGE BODY PKGTKR_HORARIOS_PROFESIONAL_DAO;

PROMPT =========================================================================
PROMPT 4. COMPILANDO ESPECIFICACION MONO-TABLA: pkgca_tkr_horarios_profesional
PROMPT =========================================================================
@@pkgca_tkr_horarios_profesional.pks
SHOW ERRORS PACKAGE pkgca_tkr_horarios_profesional;

PROMPT =========================================================================
PROMPT 5. COMPILANDO CUERPO MONO-TABLA: pkgca_tkr_horarios_profesional
PROMPT =========================================================================
@@pkgca_tkr_horarios_profesional.pkb
SHOW ERRORS PACKAGE BODY pkgca_tkr_horarios_profesional;

PROMPT =========================================================================
PROMPT 6. COMPILANDO ESPECIFICACION CASOS DE NEGOCIO: PKGCN_HORARIOS
PROMPT =========================================================================
@@pkgcn_horarios.pks
SHOW ERRORS PACKAGE PKGCN_HORARIOS;

PROMPT =========================================================================
PROMPT 7. COMPILANDO CUERPO CASOS DE NEGOCIO: PKGCN_HORARIOS
PROMPT =========================================================================
@@pkgcn_horarios.pkb
SHOW ERRORS PACKAGE BODY PKGCN_HORARIOS;

PROMPT =========================================================================
PROMPT 8. COMPILANDO ESPECIFICACION ORQUESTADOR TRANSACCIONAL: PKGLN_HORARIOS
PROMPT =========================================================================
@@pkgln_horarios.pks
SHOW ERRORS PACKAGE PKGLN_HORARIOS;

PROMPT =========================================================================
PROMPT 9. COMPILANDO CUERPO ORQUESTADOR TRANSACCIONAL: PKGLN_HORARIOS
PROMPT =========================================================================
@@pkgln_horarios.pkb
SHOW ERRORS PACKAGE BODY PKGLN_HORARIOS;

PROMPT =========================================================================
PROMPT INSTALACION Y COMPILACION FINALIZADA CON EXITO
PROMPT =========================================================================
