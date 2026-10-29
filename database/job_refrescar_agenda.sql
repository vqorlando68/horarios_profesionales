-- =============================================================================
-- PROYECTO: CORE TEKER - Horario de Profesionales
-- ARTEFACTO: Script para creación de Scheduler Job de refresco de agenda
-- JOB: JOB_TKR_REFRESCAR_AGENDA
-- PROCEDIMIENTO: PKGLN_HORARIOS.p_actualizar_agenda
-- FRECUENCIA: Cada 20 segundos
-- =============================================================================

BEGIN
    -- Eliminar el job si ya existe para permitir recreación limpia
    BEGIN
        DBMS_SCHEDULER.DROP_JOB(
            job_name => 'JOB_TKR_REFRESCAR_AGENDA',
            force    => TRUE
        );
    EXCEPTION
        WHEN OTHERS THEN
            NULL;
    END;

    -- Crear el job programado cada 20 segundos
    DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'JOB_TKR_REFRESCAR_AGENDA',
        job_type        => 'STORED_PROCEDURE',
        job_action      => 'PKGLN_HORARIOS.p_actualizar_agenda',
        start_date      => SYSTIMESTAMP AT TIME ZONE 'America/Bogota',
        repeat_interval => 'FREQ=SECONDLY;INTERVAL=20',
        enabled         => FALSE,
        auto_drop       => FALSE,
        comments        => 'Procesa cola tkr_refrescar_agenda cada 20 segundos para actualizar slots y bitmaps de disponibilidad.'
    );

    -- Registrar en log del scheduler únicamente ejecuciones fallidas para optimizar rendimiento
    DBMS_SCHEDULER.SET_ATTRIBUTE(
        name      => 'JOB_TKR_REFRESCAR_AGENDA',
        attribute => 'LOGGING_LEVEL',
        value     => DBMS_SCHEDULER.LOGGING_FAILED_RUNS
    );

    -- Habilitar el job
    DBMS_SCHEDULER.ENABLE(
        name => 'JOB_TKR_REFRESCAR_AGENDA'
    );
END;
/

