-- =============================================================================
-- PROYECTO: horario-profesionales
-- ARTEFACTO: nuevo.sql (Script Maestro Raíz)
-- BASE DE DATOS: Oracle Database (TEKER)
-- FECHA: 14/10/2026
-- DESCRIPCIÓN: Redirige la ejecución al script maestro ubicado en database/
-- =============================================================================

SET ECHO ON;
SET FEEDBACK ON;
SET DEFINE OFF;

PROMPT Ejecutando instalador maestro desde carpeta database...
@@database/nuevo.sql
