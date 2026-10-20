# TEKER Medical Suite - Gestión de Horarios de Profesionales

Sistema integral para la programación, personalización y auditoría de horarios de atención médica, franjas por modalidad de aseguramiento, ausencias programadas y tiempos de consulta en **TEKER Medical Suite**.

---

## 📖 Documentación y Manuales
- **[Manual de Usuario y Guía Operativa Funcional](docs/manuales/MANUAL_USUARIO_HORARIOS.md):** Manual completo paso a paso para médicos, coordinadores y administradores, con explicaciones en lenguaje natural, diccionario de campos y resolución de preguntas frecuentes (FAQ).
- **Documentación Técnica PL/SQL:**
  - [`PKGLN_HORARIOS` (Flujo Funcional y Grafo de Dependencias)](database/pkgln_horarios.md)
  - [`PKGLN_FRANJAS` (Franjas de Atención por Profesional)](database/pkgln_franjas.md)
  - [`PKGLN_TIEMPOS_ATENCION` (Tiempos de Atención y Duraciones)](database/pkgln_tiempos_atencion.md)

---

## 🌟 Características Principales

### 1. Gestión de Horarios y Jerarquía de Prioridad
Soporte para 3 niveles de programación horaria con resolución automática de conflictos y visualización en calendario mensual interactivo:
1. **Prioridad 1 - Horario por Día (`fecha_inicial = fecha_final`):**
   - Diseñado para imprevistos, jornadas extraordinarias o coberturas en fechas puntuales.
   - Cuenta con un **switch interactivo** que unifica el formulario a un solo selector de fecha.
   - Detecta y habilita automáticamente únicamente el día de la semana correspondiente, bloqueando los demás días.
   - Emite una advertencia preventiva si la fecha cae en domingo o festivo oficial y el médico tiene configurado `trabaja_festivos = 'N'`.
2. **Prioridad 2 - Horario Personalizado (`fecha_inicial <> fecha_final`):**
   - Vigencia temporal por rango de fechas (ej. campañas, temporadas de vacaciones).
3. **Prioridad 3 - Horario Base (`fecha_final IS NULL`):**
   - Horario ordinario y permanente que rige por defecto durante todo el año. Unicidad garantizada por profesional.

### 2. Franjas de Atención por Modalidad
- Segmentación por día y hora según el tipo de aseguramiento:
  - **Voluntario (`V`):** Medicina prepagada, pólizas complementarias y particulares.
  - **Obligatorio (`O`):** Plan de Beneficios en Salud / EPS.
  - **Giris (`G`):** Consultas especializadas y programas de salud integral.

### 3. Tiempos de Atención por Consulta
- Configuración de la duración en minutos de la consulta médica por cada tipo de aseguramiento.
- Cálculo automático en tiempo real de la tasa estimada de **Pacientes por Hora**.

### 4. Ausencias y Bloqueos de Agenda
- Registro de permisos, vacaciones, incapacidades y licencias que bloquean automáticamente la asignación de citas en el calendario.

### 5. Interfaz de Usuario Moderna y Accesible
- **Icono y Modal de Ayuda Interactivo:** Asistente integrado en la cabecera con explicaciones detalladas, guías paso a paso y reglas de negocio para usuarios en tiempo real.
- **Doble Tema Visual:** Soporte nativo y persistente para **Modo Oscuro** y **Modo Claro**.
- **Diseño Glassmorphism y Micro-interacciones:** Indicadores de estado, advertencias contextuales y confirmaciones de borrado in-app.

---

## 🏗️ Arquitectura del Sistema

```
[ Frontend Next.js (App Router) ]
         │ (HTTP REST / JSON)
         ▼
[ Next.js Route Handlers (/app/api/*) ]
         │ (node-oracledb Thin Mode)
         ▼
[ Capa de Orquestación: PKGLN_* ]
         │
 ┌───────┴───────┐
 ▼               ▼
[ PKGCN_* ]    [ PKGCA_* ]
 (Multi-tabla)   (Mono-tabla no-PK)
         │               │
         └───────┬───────┘
                 ▼
          [ PKG*_DAO ]
          (Persistencia atómica en Oracle DB)
```

---

## 🚀 Puesta en Marcha Local

### Requisitos
- Node.js 18+ o 20+
- Conectividad a la base de datos Oracle (Credenciales configuradas en `.env.local`)

### Instalación y Ejecución
```bash
# 1. Instalar dependencias
npm install

# 2. Iniciar servidor de desarrollo
npm run dev

# 3. Acceder en el navegador
# http://localhost:3000
```
