-- =============================================================================
-- SCRIPT: ACTUALIZACIÓN DE PREFERENCIA TRABAJA_FESTIVOS EN TKR_USUARIOS
-- =============================================================================

PROMPT =========================================================================
PROMPT 1. Actualizando PKGCA_TKR_USUARIOS
PROMPT =========================================================================
@@pkgca_tkr_usuarios.pks
@@pkgca_tkr_usuarios.pkb

PROMPT =========================================================================
PROMPT 2. Actualizando PKGCA_TKR_HORARIOS_PROFESIONAL
PROMPT =========================================================================
@@pkgca_tkr_horarios_profesional.pks
@@pkgca_tkr_horarios_profesional.pkb

PROMPT =========================================================================
PROMPT 2. Actualizando PKGCN_HORARIOS
PROMPT =========================================================================
@@pkgcn_horarios.pks
@@pkgcn_horarios.pkb

PROMPT =========================================================================
PROMPT 3. Actualizando PKGLN_HORARIOS
PROMPT =========================================================================
@@pkgln_horarios.pks
@@pkgln_horarios.pkb

PROMPT =========================================================================
PROMPT Verificando estado de compilacion
PROMPT =========================================================================
SELECT name, type, line, position, text
  FROM user_errors
 WHERE name IN ('PKGCA_TKR_USUARIOS', 'PKGCA_TKR_HORARIOS_PROFESIONAL', 'PKGCN_HORARIOS', 'PKGLN_HORARIOS')
 ORDER BY name, line;
