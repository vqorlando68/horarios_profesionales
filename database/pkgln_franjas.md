# Documentación Técnica y Funcional: PKGLN_FRANJAS

## 1. Visión General de la Entidad y el Dominio
El paquete **`PKGLN_FRANJAS`** es el orquestador transaccional de dominio responsable de la administración de **Franjas de Atención por Profesional** (`tkr_franjas_profesional`). Permite asociar por día de la semana y rango de horas (`hora_desde` a `hora_hasta`):
- **Tipo de Aseguramiento**:
  - `1` / **`V`**: Voluntario
  - `2` / **`O`**: Obligatorio
- **Modalidad de Atención**:
  - **`V`**: Virtual
  - **`D`**: Domiciliaria
  - **`NULL` / Vacío**: Aplica para ambas (Virtual y Domiciliaria)

Las franjas se gestionan de forma totalmente autónoma e independiente de los horarios del profesional, contando con su propio control de vigencias por fechas (`fecha_inicial` y `fecha_final`).

---

## 2. Métodos del Paquete

### 2.1 `p_consultar_franjas`
* **Propósito**: Consulta la colección de franjas activas del profesional ordenadas por día de la semana y hora inicial, incluyendo `id_tipo_aseguramiento`, `tipo_aseguramiento` y `modalidad`.
* **Invocaciones**: Delega en `pkgcn_franjas.p_consultar_franjas_json`.

### 2.2 `p_guardar_franjas`
* **Propósito**: Registra o actualiza franjas de atención en modo de reemplazo completo o por vigencia específica.
* **Reglas de Negocio**:
  1. Validación canónica de días (`LU`..`DO`) y horas (`hora_desde < hora_hasta`).
  2. Validación de tipo de atención (`1`/`V`, `2`/`O`).
  3. Validación de modalidad: `V` (Virtual), `D` (Domiciliaria) o vacía/`NULL` (Ambas).
  4. No solapamiento de horas en el mismo día dentro de la vigencia.
  5. Unicidad de Franja Base: Solo una franja con `fecha_final IS NULL` por profesional.
  6. Cero validación contra los horarios laborales del médico.
* **Invocaciones**:
  * `pkgca_tkr_franjas_profesional.p_borrar_x_rango_fechas` (limpieza previa de vigencia si es edición).
  * `pkgca_tkr_franjas_profesional.f_existe_franja_base` (control de unicidad de franja base).
  * `pkgcn_franjas.f_existe_traslape_franja` (control de no solapamiento entre franjas con fecha final).
  * `pkgcn_franjas.p_guardar_franjas_profesional` (inserción relacional con `JSON_TABLE`).
  * `p_do_commit` (compromiso atómico).

### 2.3 `p_eliminar_franjas_vigencia`
* **Propósito**: Elimina todas las franjas de una vigencia específica del profesional.
* **Invocaciones**:
  * `pkgca_tkr_franjas_profesional.p_borrar_x_rango_fechas`.
  * `p_do_commit`.
