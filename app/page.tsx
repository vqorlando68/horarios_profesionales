'use client';

import React, { useState, useEffect, useMemo, useRef } from 'react';
import {
  Calendar,
  Clock,
  User,
  ShieldCheck,
  Plus,
  Trash2,
  Save,
  CheckCircle2,
  AlertCircle,
  CalendarOff,
  ChevronDown,
  Sparkles,
  RefreshCw,
  Copy,
  Info,
  CalendarRange,
  Search,
  X,
  Sun,
  Moon,
  Edit3,
  Phone
} from 'lucide-react';

interface Profesional {
  id_usuario: number;
  nombre_completo: string;
  nombres?: string;
  apellidos?: string;
  correo: string;
  telefono?: string | number | null;
  url_foto?: string | null;
  trabaja_festivos?: 'S' | 'N';
}

interface TurnoHorario {
  idTemp: string;
  hora_desde: string;
  hora_hasta: string;
}

interface DiaConfig {
  activo: boolean;
  turnos: TurnoHorario[];
}

interface HorarioRegistrado {
  id: number;
  dia_semana: 'LU' | 'MA' | 'MI' | 'JU' | 'VI' | 'SA' | 'DO';
  hora_desde: string;
  hora_hasta: string;
  fecha_inicial: string;
  fecha_final: string | null;
  activo?: number;
}

interface Ausencia {
  id: number;
  id_usuario: number;
  fecha_inicial: string;
  fecha_final: string;
}

const DIAS_SEMANA: Array<{ key: 'LU' | 'MA' | 'MI' | 'JU' | 'VI' | 'SA' | 'DO'; nombre: string; corto: string }> = [
  { key: 'LU', nombre: 'Lunes', corto: 'Lun' },
  { key: 'MA', nombre: 'Martes', corto: 'Mar' },
  { key: 'MI', nombre: 'Miércoles', corto: 'Mié' },
  { key: 'JU', nombre: 'Jueves', corto: 'Jue' },
  { key: 'VI', nombre: 'Viernes', corto: 'Vie' },
  { key: 'SA', nombre: 'Sábado', corto: 'Sáb' },
  { key: 'DO', nombre: 'Domingo', corto: 'Dom' },
];

const MAPA_ORDEN_DIAS: Record<string, { orden: number; nombre: string }> = {
  LU: { orden: 1, nombre: 'Lunes' },
  MA: { orden: 2, nombre: 'Martes' },
  MI: { orden: 3, nombre: 'Miércoles' },
  JU: { orden: 4, nombre: 'Jueves' },
  VI: { orden: 5, nombre: 'Viernes' },
  SA: { orden: 6, nombre: 'Sábado' },
  DO: { orden: 7, nombre: 'Domingo' },
};

export default function HorariosPage() {
  // Tema Claro / Oscuro
  const [tema, setTema] = useState<'dark' | 'light'>('dark');

  const [profesionales, setProfesionales] = useState<Profesional[]>([]);
  const [profesionalSeleccionado, setProfesionalSeleccionado] = useState<Profesional | null>(null);
  const [dropdownAbierto, setDropdownAbierto] = useState(false);
  const [busquedaProf, setBusquedaProf] = useState('');
  const dropdownRef = useRef<HTMLDivElement>(null);

  // Horarios registrados en BD Oracle y Estado de Expansión
  const [horariosRegistrados, setHorariosRegistrados] = useState<HorarioRegistrado[]>([]);
  const [expandidoHorariosRegistrados, setExpandidoHorariosRegistrados] = useState<boolean>(true);
  const [ausencias, setAusencias] = useState<Ausencia[]>([]);
  const [tabActiva, setTabActiva] = useState<'horarios' | 'ausencias'>('horarios');

  // Estado para Modal In-App de Confirmación de Borrado de Vigencia
  const [vigenciaAEliminar, setVigenciaAEliminar] = useState<{
    fecha_inicial: string;
    fecha_final: string | null;
    descripcion: string;
  } | null>(null);

  // Estado para Modal In-App de Confirmación de Borrado de Ausencia
  const [ausenciaAEliminar, setAusenciaAEliminar] = useState<{
    id: number;
    fecha_inicial: string;
    fecha_final: string;
  } | null>(null);

  // Estado para Vigencia Cargada en Edición (permite actualizar sin error de traslape contra sí misma)
  const [vigenciaEnEdicion, setVigenciaEnEdicion] = useState<{
    fecha_inicial: string;
    fecha_final: string | null;
    descripcion: string;
  } | null>(null);

  // Estado para Modal In-App de Advertencia de Trabaja Festivos = 'N' con horarios en Domingo
  const [modalFestivosAdvertencia, setModalFestivosAdvertencia] = useState<{
    cantidadDomingos: number;
  } | null>(null);
  const [actualizandoFestivos, setActualizandoFestivos] = useState(false);

  const [cargando, setCargando] = useState(false);
  const [guardando, setGuardando] = useState(false);
  const [toast, setToast] = useState<{ tipo: 'success' | 'error'; mensaje: string } | null>(null);


  // 1. Rango de Fechas para el Horario en Edición y Refs para Pickers
  const fechaHoy = useMemo(() => new Date().toISOString().split('T')[0], []);
  const [fechaInicial, setFechaInicial] = useState<string>(fechaHoy);
  const [fechaFinal, setFechaFinal] = useState<string>('');
  const [esIndefinido, setEsIndefinido] = useState<boolean>(true);
  const [modoReemplazo, setModoReemplazo] = useState<number>(1); // 1 = Reemplaza todo, 0 = Adiciona

  const fechaInicialRef = useRef<HTMLInputElement>(null);
  const fechaFinalRef = useRef<HTMLInputElement>(null);
  const fechaInicialAusenciaRef = useRef<HTMLInputElement>(null);
  const fechaFinalAusenciaRef = useRef<HTMLInputElement>(null);

  // 2. Horarios por Días de la Semana para el Rango Seleccionado
  const [diasConfig, setDiasConfig] = useState<Record<string, DiaConfig>>({
    LU: { activo: true, turnos: [{ idTemp: '1', hora_desde: '08:00', hora_hasta: '12:00' }, { idTemp: '2', hora_desde: '14:00', hora_hasta: '18:00' }] },
    MA: { activo: true, turnos: [{ idTemp: '3', hora_desde: '08:00', hora_hasta: '12:00' }, { idTemp: '4', hora_desde: '14:00', hora_hasta: '18:00' }] },
    MI: { activo: true, turnos: [{ idTemp: '5', hora_desde: '08:00', hora_hasta: '12:00' }, { idTemp: '6', hora_desde: '14:00', hora_hasta: '18:00' }] },
    JU: { activo: true, turnos: [{ idTemp: '7', hora_desde: '08:00', hora_hasta: '12:00' }, { idTemp: '8', hora_desde: '14:00', hora_hasta: '18:00' }] },
    VI: { activo: true, turnos: [{ idTemp: '9', hora_desde: '08:00', hora_hasta: '12:00' }, { idTemp: '10', hora_desde: '14:00', hora_hasta: '18:00' }] },
    SA: { activo: false, turnos: [{ idTemp: '11', hora_desde: '08:00', hora_hasta: '12:00' }] },
    DO: { activo: false, turnos: [{ idTemp: '12', hora_desde: '08:00', hora_hasta: '12:00' }] },
  });

  // Formulario nueva ausencia
  const [nuevaAusencia, setNuevaAusencia] = useState({
    fecha_inicial: '',
    fecha_final: '',
  });

  // Efecto para inicializar tema desde localStorage
  useEffect(() => {
    const temaGuardado = localStorage.getItem('teker_theme') as 'dark' | 'light' | null;
    if (temaGuardado) {
      setTema(temaGuardado);
      document.documentElement.setAttribute('data-theme', temaGuardado);
    } else {
      document.documentElement.setAttribute('data-theme', 'dark');
    }
  }, []);

  const toggleTema = () => {
    const nuevoTema = tema === 'dark' ? 'light' : 'dark';
    setTema(nuevoTema);
    localStorage.setItem('teker_theme', nuevoTema);
    document.documentElement.setAttribute('data-theme', nuevoTema);
  };

  // Helper para abrir picker nativo de fecha desde el icono
  const abrirSelectorFecha = (ref: React.RefObject<HTMLInputElement | null>) => {
    if (ref.current) {
      if (typeof (ref.current as any).showPicker === 'function') {
        try {
          (ref.current as any).showPicker();
        } catch {
          ref.current.focus();
        }
      } else {
        ref.current.focus();
      }
    }
  };

  // Limpiar residuos técnicos de Oracle para el usuario final
  const sanitizarMensaje = (msg: string) => {
    if (!msg) return 'Ocurrió un error en la operación.';
    const limpio = msg
      .replace(/Help:\s*https?:\/\/\S+/gi, '')
      .replace(/ORA-06512:\s*at\s+["'\w\s.]+,?\s*line\s+\d+/gi, '')
      .replace(/ORA-06512:\s*at\s+line\s+\d+/gi, '')
      .replace(/ORA-06512:\s*at\s+[^\n]+/gi, '')
      .replace(/ORA-\d{5}:\s*/gi, '')
      .replace(/\s+/g, ' ')
      .trim();
    return limpio || msg;
  };

  // Mostrar toast con tiempo suficiente de lectura y mensaje amigable
  const notificar = (tipo: 'success' | 'error', mensaje: string) => {
    const mensajeFinal = tipo === 'error' ? sanitizarMensaje(mensaje) : mensaje;
    setToast({ tipo, mensaje: mensajeFinal });
    setTimeout(() => setToast(null), 7000);
  };

  // Cargar lista de profesionales al iniciar
  useEffect(() => {
    cargarProfesionales();
  }, []);

  // Cerrar dropdown al hacer clic afuera
  useEffect(() => {
    const handleClickAfuera = (event: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setDropdownAbierto(false);
      }
    };
    document.addEventListener('mousedown', handleClickAfuera);
    return () => {
      document.removeEventListener('mousedown', handleClickAfuera);
    };
  }, []);

  const cargarProfesionales = async () => {
    setCargando(true);
    try {
      const res = await fetch('/api/profesionales');
      const data = await res.json();
      if (data && Array.isArray(data.datos)) {
        // Deduplicar profesionales por id_usuario
        const mapa = new Map<number, Profesional>();
        data.datos.forEach((p: Profesional) => {
          if (!mapa.has(p.id_usuario)) {
            mapa.set(p.id_usuario, p);
          }
        });
        const listaUnicos = Array.from(mapa.values());
        setProfesionales(listaUnicos);

        if (listaUnicos.length > 0 && !profesionalSeleccionado) {
          seleccionarProfesional(listaUnicos[0]);
        }
      } else if (data && data.mensaje) {
        notificar('error', data.mensaje);
      }
    } catch (err: any) {
      console.warn('Error al cargar profesionales:', err);
      notificar('error', 'Error al consultar profesionales desde Oracle DB.');
    } finally {
      setCargando(false);
    }
  };

  // Cargar agenda al seleccionar un profesional
  const seleccionarProfesional = async (prof: Profesional) => {
    setProfesionalSeleccionado(prof);
    setVigenciaEnEdicion(null);
    setDropdownAbierto(false);
    setBusquedaProf('');
    setCargando(true);
    try {
      const res = await fetch(`/api/agenda?id_usuario=${prof.id_usuario}&_t=${Date.now()}`, {
        cache: 'no-store',
      });
      const data = await res.json();

      if (data && data.horarios && Array.isArray(data.horarios)) {
        setHorariosRegistrados(data.horarios);
      } else {
        setHorariosRegistrados([]);
      }

      if (data && data.ausencias && Array.isArray(data.ausencias)) {
        setAusencias(data.ausencias);
      } else {
        setAusencias([]);
      }
    } catch (err: any) {
      console.warn('Error al cargar agenda:', err);
      notificar('error', 'Error al consultar la agenda del profesional.');
    } finally {
      setCargando(false);
    }
  };

  // Manejador del Toggle Trabaja Festivos / Domingos
  const handleToggleFestivos = async () => {
    if (!profesionalSeleccionado) return;

    const valorActual = profesionalSeleccionado.trabaja_festivos === 'S' ? 'S' : 'N';
    const nuevoValor: 'S' | 'N' = valorActual === 'S' ? 'N' : 'S';

    // Si intenta desmarcar ('N') y tiene horarios registrados en Domingo ('DO')
    if (nuevoValor === 'N') {
      const turnosDomingo = horariosRegistrados.filter((h) => h.dia_semana === 'DO');
      if (turnosDomingo.length > 0) {
        setModalFestivosAdvertencia({ cantidadDomingos: turnosDomingo.length });
        return;
      }
    }

    // Si pasa a 'S' o si pasa a 'N' sin tener domingos en BD
    await guardarCambioFestivos(nuevoValor, false);
  };

  // Guardar cambio de trabaja_festivos en Oracle mediante PATCH /api/profesionales
  const guardarCambioFestivos = async (nuevoValor: 'S' | 'N', borrarDomingos: boolean) => {
    if (!profesionalSeleccionado) return;

    setActualizandoFestivos(true);
    try {
      const res = await fetch('/api/profesionales', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          id_usuario: profesionalSeleccionado.id_usuario,
          trabaja_festivos: nuevoValor,
          borrar_domingos: borrarDomingos ? 1 : 0,
        }),
      });

      const data = await res.json();
      if (data && data.codigo === 0) {
        const profActualizado: Profesional = {
          ...profesionalSeleccionado,
          trabaja_festivos: nuevoValor,
        };

        setProfesionalSeleccionado(profActualizado);
        setProfesionales((prev) =>
          prev.map((p) => (p.id_usuario === profActualizado.id_usuario ? profActualizado : p))
        );

        if (nuevoValor === 'N') {
          // Desactivar y limpiar el domingo en el editor
          setDiasConfig((prev) => ({
            ...prev,
            DO: { activo: false, turnos: [] },
          }));

          if (borrarDomingos) {
            notificar('success', 'Configuración actualizada: Se borraron los horarios del domingo en Oracle.');
            await seleccionarProfesional(profActualizado);
          } else {
            notificar('success', 'Configuración guardada: El profesional no labora festivos ni domingos.');
          }
        } else {
          notificar('success', 'Configuración guardada: El profesional ahora labora domingos y festivos.');
        }
      } else {
        notificar('error', data.mensaje || 'Error al actualizar el estado de festivos.');
      }
    } catch (err: any) {
      console.error(err);
      notificar('error', 'Error al comunicarse con el servidor para actualizar festivos.');
    } finally {
      setActualizandoFestivos(false);
      setModalFestivosAdvertencia(null);
    }
  };

  // Confirmar en el modal la eliminación de turnos de domingo y pasar a 'N'
  const confirmarCambioFestivosANo = async () => {
    await guardarCambioFestivos('N', true);
  };


  // Manejadores de Días y Turnos
  const toggleDia = (diaKey: string) => {
    if (diaKey === 'DO' && profesionalSeleccionado?.trabaja_festivos === 'N') {
      notificar('error', 'El profesional no tiene habilitado laborar domingos ni festivos.');
      return;
    }

    setDiasConfig((prev) => {
      const actual = prev[diaKey];
      return {
        ...prev,
        [diaKey]: {
          ...actual,
          activo: !actual.activo,
        },
      };
    });
  };

  const agregarTurno = (diaKey: string) => {
    if (diaKey === 'DO' && profesionalSeleccionado?.trabaja_festivos === 'N') {
      notificar('error', 'No se pueden agregar horarios en domingo para un profesional que no trabaja festivos.');
      return;
    }

    setDiasConfig((prev) => {
      const actual = prev[diaKey];
      const ultimo = actual.turnos[actual.turnos.length - 1];
      let nuevaDesde = '14:00';
      let nuevaHasta = '18:00';
      if (ultimo) {
        nuevaDesde = ultimo.hora_hasta;
        const [h, m] = ultimo.hora_hasta.split(':').map(Number);
        const finH = Math.min(22, h + 2);
        nuevaHasta = `${String(finH).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
      }
      return {
        ...prev,
        [diaKey]: {
          activo: true,
          turnos: [
            ...actual.turnos,
            { idTemp: Date.now().toString() + Math.random(), hora_desde: nuevaDesde, hora_hasta: nuevaHasta },
          ],
        },
      };
    });
  };


  const eliminarTurno = (diaKey: string, index: number) => {
    setDiasConfig((prev) => {
      const actual = prev[diaKey];
      const nuevos = [...actual.turnos];
      nuevos.splice(index, 1);
      return {
        ...prev,
        [diaKey]: {
          ...actual,
          turnos: nuevos,
          activo: nuevos.length > 0 ? actual.activo : false,
        },
      };
    });
  };

  const actualizarTurno = (diaKey: string, index: number, campo: 'hora_desde' | 'hora_hasta', valor: string) => {
    setDiasConfig((prev) => {
      const actual = prev[diaKey];
      const nuevos = [...actual.turnos];
      nuevos[index] = { ...nuevos[index], [campo]: valor };
      return {
        ...prev,
        [diaKey]: {
          ...actual,
          turnos: nuevos,
        },
      };
    });
  };

  const copiarADiasLaborales = (diaOrigenKey: string) => {
    const turnosACopiar = diasConfig[diaOrigenKey].turnos;
    setDiasConfig((prev) => {
      const nuevo = { ...prev };
      ['LU', 'MA', 'MI', 'JU', 'VI'].forEach((d) => {
        nuevo[d] = {
          activo: true,
          turnos: turnosACopiar.map((t, idx) => ({
            idTemp: Date.now().toString() + idx + Math.random(),
            hora_desde: t.hora_desde,
            hora_hasta: t.hora_hasta,
          })),
        };
      });
      return nuevo;
    });
    notificar('success', `Horarios de ${diaOrigenKey} replicados a Lunes-Viernes.`);
  };

  // Calcular total de turnos activos para el rango
  const totalTurnosActivos = useMemo(() => {
    let cuenta = 0;
    Object.values(diasConfig).forEach((d) => {
      if (d.activo) cuenta += d.turnos.length;
    });
    return cuenta;
  }, [diasConfig]);

  // Guardar Horarios para el Rango de Fecha Seleccionado
  const guardarHorariosRango = async () => {
    if (!profesionalSeleccionado) {
      notificar('error', 'Seleccione un profesional de salud.');
      return;
    }

    if (!fechaInicial) {
      notificar('error', 'La fecha inicial del rango de vigencia es obligatoria.');
      return;
    }

    if (!esIndefinido && fechaFinal && fechaFinal < fechaInicial) {
      notificar('error', 'La fecha final no puede ser menor a la fecha inicial.');
      return;
    }

    // Validación de unicidad de Horario Base: Solo 1 horario sin fecha final por profesional
    const esHorarioBaseAGuardar = esIndefinido || !fechaFinal;
    if (esHorarioBaseAGuardar) {
      const existeHorarioBase = periodosRegistrados.some((p) => p.fecha_final === null);
      const editandoMismoHorarioBase =
        vigenciaEnEdicion && vigenciaEnEdicion.fecha_final === null;
      const esReemplazoTotal = !vigenciaEnEdicion && modoReemplazo === 1;

      if (existeHorarioBase && !editandoMismoHorarioBase && !esReemplazoTotal) {
        notificar(
          'error',
          'El profesional ya cuenta con un Horario Base registrado (sin fecha final). Solo se permite un único Horario Base por profesional; modifique el existente o asigne una fecha final para registrarlo como Horario Personalizado.'
        );
        return;
      }
    }

    // Aplanar los horarios de los días activos
    const listaHorariosAplanada: Array<{
      dia_semana: string;
      hora_desde: string;
      hora_hasta: string;
      fecha_inicial: string;
      fecha_final: string | null;
    }> = [];

    for (const dia of DIAS_SEMANA) {
      const conf = diasConfig[dia.key];
      if (conf.activo && conf.turnos.length > 0) {
        for (const t of conf.turnos) {
          if (t.hora_desde >= t.hora_hasta) {
            notificar('error', `En ${dia.nombre}, la hora inicial (${t.hora_desde}) debe ser menor que la final (${t.hora_hasta}).`);
            return;
          }
          listaHorariosAplanada.push({
            dia_semana: dia.key,
            hora_desde: t.hora_desde,
            hora_hasta: t.hora_hasta,
            fecha_inicial: fechaInicial,
            fecha_final: esIndefinido || !fechaFinal ? null : fechaFinal,
          });
        }
      }
    }

    if (listaHorariosAplanada.length === 0) {
      notificar('error', 'No hay horarios configurados en ningún día para este rango de fecha.');
      return;
    }

    setGuardando(true);
    try {
      const payload = {
        id_usuario: profesionalSeleccionado.id_usuario,
        reemplazar_todo: vigenciaEnEdicion ? 0 : modoReemplazo,
        reemplazar_vigencia: vigenciaEnEdicion ? 1 : 0,
        fecha_inicial_origen: vigenciaEnEdicion ? vigenciaEnEdicion.fecha_inicial : null,
        fecha_final_origen: vigenciaEnEdicion ? vigenciaEnEdicion.fecha_final : null,
        horarios: listaHorariosAplanada,
      };

      const res = await fetch('/api/horarios', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });

      const data = await res.json();
      if (data && data.codigo === 0) {
        const msjExito = vigenciaEnEdicion
          ? `¡Vigencia (${vigenciaEnEdicion.descripcion}) actualizada exitosamente en Oracle DB!`
          : '¡Horarios para el rango guardados exitosamente en Oracle DB!';
        notificar('success', msjExito);
        setVigenciaEnEdicion(null);
        seleccionarProfesional(profesionalSeleccionado);
      } else {
        notificar('error', data.mensaje || 'Error al persistir horarios.');
      }
    } catch (err: any) {
      console.error(err);
      notificar('error', 'Error al comunicarse con la API de horarios.');
    } finally {
      setGuardando(false);
    }
  };

  // Registrar nueva ausencia
  const guardarAusencia = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!profesionalSeleccionado) return;
    if (!nuevaAusencia.fecha_inicial || !nuevaAusencia.fecha_final) {
      notificar('error', 'Las fechas de inicio y fin son obligatorias.');
      return;
    }
    if (nuevaAusencia.fecha_final < nuevaAusencia.fecha_inicial) {
      notificar('error', 'La fecha final no puede ser anterior a la inicial.');
      return;
    }

    setCargando(true);
    try {
      const res = await fetch('/api/ausencias', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          id_usuario: profesionalSeleccionado.id_usuario,
          fecha_inicial: nuevaAusencia.fecha_inicial,
          fecha_final: nuevaAusencia.fecha_final,
        }),
      });
      const data = await res.json();
      if (data && data.codigo === 0) {
        notificar('success', 'Ausencia registrada exitosamente.');
        setNuevaAusencia({ fecha_inicial: '', fecha_final: '' });
        seleccionarProfesional(profesionalSeleccionado);
      } else {
        notificar('error', data.mensaje || 'Error al registrar ausencia.');
      }
    } catch {
      notificar('error', 'Error al registrar ausencia.');
    } finally {
      setCargando(false);
    }
  };

  // Solicitar eliminación de ausencia abriendo modal in-app con el estilo de la aplicación
  const solicitarEliminacionAusencia = (aus: Ausencia) => {
    setAusenciaAEliminar({
      id: aus.id,
      fecha_inicial: aus.fecha_inicial,
      fecha_final: aus.fecha_final,
    });
  };

  // Confirmar y procesar eliminación de ausencia
  const confirmarYEliminarAusencia = async () => {
    if (!ausenciaAEliminar) return;

    setCargando(true);
    try {
      const res = await fetch(`/api/ausencias?id=${ausenciaAEliminar.id}`, { method: 'DELETE' });
      const data = await res.json();
      if (data && data.codigo === 0) {
        notificar('success', 'Ausencia o bloqueo eliminado exitosamente.');
        setAusenciaAEliminar(null);
        if (profesionalSeleccionado) seleccionarProfesional(profesionalSeleccionado);
      } else {
        notificar('error', data.mensaje || 'Error al eliminar ausencia.');
      }
    } catch {
      notificar('error', 'Error al comunicarse con el servidor para eliminar ausencia.');
    } finally {
      setCargando(false);
    }
  };

  // Solicitar eliminación de vigencia abriendo el modal in-app
  const solicitarEliminacionVigencia = (fechaIni: string, fechaFin: string | null) => {
    if (!profesionalSeleccionado) return;
    const descVigencia = fechaFin
      ? `del ${fechaIni} al ${fechaFin}`
      : `a partir del ${fechaIni} (indefinida)`;

    setVigenciaAEliminar({
      fecha_inicial: fechaIni,
      fecha_final: fechaFin,
      descripcion: descVigencia,
    });
  };

  // Confirmar y ejecutar eliminación en Oracle
  const confirmarYEliminarVigencia = async () => {
    if (!profesionalSeleccionado || !vigenciaAEliminar) return;

    setCargando(true);
    try {
      const params = new URLSearchParams({
        id_usuario: profesionalSeleccionado.id_usuario.toString(),
        fecha_inicial: vigenciaAEliminar.fecha_inicial,
      });
      if (vigenciaAEliminar.fecha_final) {
        params.append('fecha_final', vigenciaAEliminar.fecha_final);
      }

      const res = await fetch(`/api/horarios?${params.toString()}`, {
        method: 'DELETE',
        headers: { 'Cache-Control': 'no-cache' },
      });

      const data = await res.json();
      if (data && data.codigo === 0) {
        notificar('success', `Vigencia ${vigenciaAEliminar.descripcion} eliminada exitosamente.`);
        setVigenciaAEliminar(null);
        await seleccionarProfesional(profesionalSeleccionado);
      } else {
        notificar('error', data.mensaje || 'Error al eliminar la vigencia de horarios.');
      }
    } catch (err: any) {
      console.error('Error al eliminar vigencia:', err);
      notificar('error', 'Error al comunicarse con el servidor para eliminar la vigencia.');
    } finally {
      setCargando(false);
    }
  };

  // Cargar una vigencia grabada en el editor para realizar modificaciones
  const cargarVigenciaEnEditor = (periodo: {
    fecha_inicial: string;
    fecha_final: string | null;
    diasAgrupados: Array<{
      diaKey: string;
      nombreDia: string;
      turnos: HorarioRegistrado[];
    }>;
  }) => {
    // 1. Cargar las fechas en el formulario del Paso 1
    setFechaInicial(periodo.fecha_inicial);
    if (periodo.fecha_final) {
      setFechaFinal(periodo.fecha_final);
      setEsIndefinido(false);
    } else {
      setFechaFinal('');
      setEsIndefinido(true);
    }

    // Registrar la vigencia origen para reemplazo limpio al guardar
    setVigenciaEnEdicion({
      fecha_inicial: periodo.fecha_inicial,
      fecha_final: periodo.fecha_final,
      descripcion: periodo.fecha_final
        ? `del ${periodo.fecha_inicial} al ${periodo.fecha_final}`
        : `del ${periodo.fecha_inicial} en adelante (Indefinido)`,
    });

    // 2. Mapear días y turnos en el formulario del Paso 2
    const mapaDiasRegistrados = new Map<string, HorarioRegistrado[]>();
    periodo.diasAgrupados.forEach((g) => {
      mapaDiasRegistrados.set(g.diaKey, g.turnos);
    });

    const nuevaConfigDias: Record<string, DiaConfig> = {};
    DIAS_SEMANA.forEach((dia) => {
      // Si el profesional no trabaja festivos, bloquear Domingo
      if (dia.key === 'DO' && profesionalSeleccionado?.trabaja_festivos === 'N') {
        nuevaConfigDias[dia.key] = {
          activo: false,
          turnos: [],
        };
        return;
      }

      const turnosEnBD = mapaDiasRegistrados.get(dia.key);
      if (turnosEnBD && turnosEnBD.length > 0) {
        nuevaConfigDias[dia.key] = {
          activo: true,
          turnos: turnosEnBD.map((t, idx) => ({
            idTemp: `${dia.key}_edit_${idx}_${Date.now()}_${Math.random()}`,
            hora_desde: t.hora_desde,
            hora_hasta: t.hora_hasta,
          })),
        };
      } else {
        nuevaConfigDias[dia.key] = {
          activo: false,
          turnos: [
            { idTemp: `${dia.key}_default_${Date.now()}`, hora_desde: '08:00', hora_hasta: '12:00' },
          ],
        };
      }
    });


    setDiasConfig(nuevaConfigDias);
    setTabActiva('horarios');

    notificar(
      'success',
      `Vigencia (${periodo.fecha_inicial} → ${periodo.fecha_final || 'Indefinido'}) cargada en el editor. Puede ajustar fechas u horas y presionar "Guardar Horarios".`
    );

    // Scroll suave hacia el editor
    setTimeout(() => {
      const editorEl = document.getElementById('editor-horarios-seccion');
      if (editorEl) {
        editorEl.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
    }, 100);
  };

  // Agrupación de Horarios Registrados por Período de Vigencia y por DÍA con sus Horas
  const periodosRegistrados = useMemo(() => {
    const grupos: Record<string, HorarioRegistrado[]> = {};
    horariosRegistrados.forEach((h) => {
      const clave = `${h.fecha_inicial}__${h.fecha_final || 'INDEFINIDO'}`;
      if (!grupos[clave]) grupos[clave] = [];
      grupos[clave].push(h);
    });

    return Object.entries(grupos).map(([clave, items]) => {
      const [ini, fin] = clave.split('__');

      // Agrupar los horarios de este período por día de la semana
      const porDia: Record<string, HorarioRegistrado[]> = {};
      items.forEach((h) => {
        if (!porDia[h.dia_semana]) porDia[h.dia_semana] = [];
        porDia[h.dia_semana].push(h);
      });

      // Ordenar según el flujo de la semana (Lunes a Domingo)
      const diasAgrupados = Object.entries(porDia)
        .sort(([d1], [d2]) => (MAPA_ORDEN_DIAS[d1]?.orden || 99) - (MAPA_ORDEN_DIAS[d2]?.orden || 99))
        .map(([diaKey, turnos]) => ({
          diaKey,
          nombreDia: MAPA_ORDEN_DIAS[diaKey]?.nombre || diaKey,
          turnos: turnos.sort((a, b) => a.hora_desde.localeCompare(b.hora_desde)),
        }));

      return {
        fecha_inicial: ini,
        fecha_final: fin === 'INDEFINIDO' ? null : fin,
        totalTurnos: items.length,
        diasAgrupados,
      };
    }).sort((a, b) => {
      // 1. El Horario Base (sin fecha_final) aparece siempre de primero
      if (a.fecha_final === null && b.fecha_final !== null) return -1;
      if (b.fecha_final === null && a.fecha_final !== null) return 1;

      // 2. Los demás aparecen ordenados por fecha_inicio (ascendente)
      return a.fecha_inicial.localeCompare(b.fecha_inicial);
    });
  }, [horariosRegistrados]);

  // Filtrado de profesionales para el buscador del select
  const profesionalesFiltrados = useMemo(() => {
    if (!busquedaProf.trim()) return profesionales;
    const q = busquedaProf.toLowerCase().trim();
    return profesionales.filter(
      (p) =>
        p.nombre_completo.toLowerCase().includes(q) ||
        p.correo.toLowerCase().includes(q) ||
        (p.telefono && String(p.telefono).toLowerCase().includes(q))
    );
  }, [profesionales, busquedaProf]);

  return (
    <div className="app-container">
      {/* Toast Notificaciones de Alta Visibilidad */}
      {toast && (
        <div className="toast-container">
          <div className={`toast ${toast.tipo}`}>
            <div className="toast-icon-badge">
              {toast.tipo === 'success' ? <CheckCircle2 size={20} /> : <AlertCircle size={20} />}
            </div>
            <div className="toast-content">
              <div className="toast-title">
                {toast.tipo === 'success' ? 'Operación Exitosa' : 'Mensaje del Sistema / Error'}
              </div>
              <div className="toast-message">{toast.mensaje}</div>
            </div>
            <button
              type="button"
              className="toast-close-btn"
              onClick={() => setToast(null)}
              title="Cerrar notificación"
            >
              <X size={16} />
            </button>
          </div>
        </div>
      )}

      {/* Header Corporativo */}
      <header className="app-header">
        <div className="brand-wrapper">
          <div className="brand-logo-badge">TK</div>
          <div className="brand-info">
            <h1>
              TEKER Medical Suite
              <span className="env-tag">Oracle Cloud • Vercel Ready</span>
            </h1>
            <p>Configuración de Horarios de Atención por Rango de Fechas y Ausencias</p>
          </div>
        </div>

        <div className="header-actions">
          {/* Selector de Tema Claro / Oscuro */}
          <button
            type="button"
            onClick={toggleTema}
            className="btn-theme-toggle"
            title={tema === 'dark' ? 'Cambiar a Modo Claro' : 'Cambiar a Modo Oscuro'}
          >
            {tema === 'dark' ? <Sun size={15} color="#FBBF24" /> : <Moon size={15} color="#38BDF8" />}
            <span>{tema === 'dark' ? 'Modo Claro' : 'Modo Oscuro'}</span>
          </button>

          <button
            onClick={cargarProfesionales}
            className="btn-add-slot"
            title="Refrescar datos"
          >
            <RefreshCw size={14} className={cargando ? 'spinner' : ''} />
            Actualizar
          </button>
        </div>
      </header>

      {/* Panel Superior: Selección del Profesional con Buscador Integrado */}
      <section className="doctor-selection-panel">
        <div className="card-glass doctor-selector-card" ref={dropdownRef}>
          <div className="panel-title">
            <User size={16} />
            Selección de Profesional
          </div>

          <div className="doctor-dropdown-wrapper">
            <button
              type="button"
              className="doctor-select-trigger"
              onClick={() => {
                setDropdownAbierto(!dropdownAbierto);
                if (!dropdownAbierto) setBusquedaProf('');
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px', overflow: 'hidden' }}>
                {profesionalSeleccionado ? (
                  <>
                    <div className="avatar-circle" style={{ width: '28px', height: '28px', fontSize: '11px' }}>
                      {profesionalSeleccionado.url_foto ? (
                        <img src={profesionalSeleccionado.url_foto} alt={profesionalSeleccionado.nombre_completo} />
                      ) : (
                        profesionalSeleccionado.nombre_completo.substring(0, 2).toUpperCase()
                      )}
                    </div>
                    <div style={{ textAlign: 'left', lineHeight: 1.2 }}>
                      <div className="doctor-option-name">
                        {profesionalSeleccionado.nombre_completo}
                      </div>
                      <div className="doctor-option-email" style={{ display: 'flex', alignItems: 'center', gap: '6px', flexWrap: 'wrap' }}>
                        <span>{profesionalSeleccionado.correo}</span>
                        {profesionalSeleccionado.telefono && (
                          <span className="doctor-phone-tag">
                            • <Phone size={11} /> {profesionalSeleccionado.telefono}
                          </span>
                        )}
                      </div>
                    </div>
                  </>
                ) : (
                  <span>Seleccione un profesional...</span>
                )}
              </div>
              <ChevronDown size={16} color="var(--accent-cyan)" />
            </button>

            {dropdownAbierto && (
              <div className="doctor-dropdown-menu">
                {/* Buscador dentro del Select */}
                <div className="doctor-search-box">
                  <Search size={15} color="var(--accent-cyan)" />
                  <input
                    type="text"
                    placeholder="Buscar médico por nombre, correo o teléfono..."
                    className="doctor-search-input"
                    value={busquedaProf}
                    onChange={(e) => setBusquedaProf(e.target.value)}
                    autoFocus
                  />
                  {busquedaProf && (
                    <button
                      type="button"
                      onClick={() => setBusquedaProf('')}
                      style={{ background: 'transparent', border: 'none', color: 'var(--text-muted)', cursor: 'pointer', display: 'flex' }}
                    >
                      <X size={14} />
                    </button>
                  )}
                </div>

                {/* Lista de Profesionales con Scroll */}
                <div className="doctor-list-scroll">
                  {profesionalesFiltrados.length === 0 ? (
                    <div style={{ padding: '16px', fontSize: '13px', color: 'var(--text-muted)', textAlign: 'center' }}>
                      No se encontraron médicos con ese criterio.
                    </div>
                  ) : (
                    profesionalesFiltrados.map((prof) => {
                      const esSeleccionado = profesionalSeleccionado?.id_usuario === prof.id_usuario;

                      return (
                        <div
                          key={prof.id_usuario}
                          className={`doctor-option ${esSeleccionado ? 'selected' : ''}`}
                          onClick={() => seleccionarProfesional(prof)}
                        >
                          <div className="avatar-circle">
                            {prof.url_foto ? (
                              <img src={prof.url_foto} alt={prof.nombre_completo} />
                            ) : (
                              prof.nombre_completo.substring(0, 2).toUpperCase()
                            )}
                          </div>
                          <div style={{ flex: 1, minWidth: 0 }}>
                            <div className="doctor-option-name">
                              {prof.nombre_completo}
                            </div>
                            <div className="doctor-option-email" style={{ display: 'flex', alignItems: 'center', gap: '6px', flexWrap: 'wrap' }}>
                              <span>{prof.correo}</span>
                              {prof.telefono && (
                                <span className="doctor-phone-tag">
                                  • <Phone size={11} /> {prof.telefono}
                                </span>
                              )}
                            </div>
                          </div>
                          {esSeleccionado && <CheckCircle2 size={16} color="var(--accent-teal)" />}
                        </div>
                      );
                    })
                  )}
                </div>
              </div>
            )}
          </div>
        </div>

        {/* Ficha Resumen */}
        <div className="card-glass">
          {profesionalSeleccionado ? (
            <div className="doctor-hero-card">
              <div className="doctor-profile-lead">
                <div className="avatar-circle avatar-circle-lg">
                  {profesionalSeleccionado.url_foto ? (
                    <img
                      src={profesionalSeleccionado.url_foto}
                      alt={profesionalSeleccionado.nombre_completo}
                    />
                  ) : (
                    profesionalSeleccionado.nombre_completo.substring(0, 2).toUpperCase()
                  )}
                </div>
                <div>
                  <h2 className="doctor-name-title">{profesionalSeleccionado.nombre_completo}</h2>
                  <div className="doctor-meta-line">
                    <span className="meta-pill">
                      <ShieldCheck size={13} color="var(--accent-teal)" />
                      Médico Habilitado (ID {profesionalSeleccionado.id_usuario})
                    </span>
                    <span>{profesionalSeleccionado.correo}</span>
                    {profesionalSeleccionado.telefono && (
                      <span className="meta-pill" style={{ display: 'inline-flex', alignItems: 'center', gap: '4px' }}>
                        <Phone size={12} color="var(--accent-cyan)" />
                        {profesionalSeleccionado.telefono}
                      </span>
                    )}
                  </div>
                </div>
              </div>

              <div className="stats-grid">
                <div className="stat-chip">
                  <div className="stat-value">{periodosRegistrados.length}</div>
                  <div className="stat-label">Períodos Configurados</div>
                </div>
              </div>

              {/* Toggle Trabaja Festivos / Domingos */}
              <div className="festivos-toggle-wrap">
                <div className="festivos-info-lead">
                  <div className={`festivos-icon-badge ${profesionalSeleccionado.trabaja_festivos === 'S' ? 'active' : ''}`}>
                    <Calendar size={16} />
                  </div>
                  <div className="festivos-texts">
                    <span className="festivos-texts-title">
                      ¿Trabaja Domingos y Festivos?
                    </span>
                    <span className="festivos-texts-desc">
                      {profesionalSeleccionado.trabaja_festivos === 'S'
                        ? 'Habilitado para laborar domingos y días festivos'
                        : 'No labora festivos (día domingo bloqueado sin horarios)'}
                    </span>
                  </div>
                </div>

                <div className="festivos-switch-container">
                  <span className={`switch-label-status ${profesionalSeleccionado.trabaja_festivos === 'S' ? 'active' : 'inactive'}`}>
                    {profesionalSeleccionado.trabaja_festivos === 'S' ? 'SÍ (S)' : 'NO (N)'}
                  </span>
                  <label className="switch-control" title="Cambiar disponibilidad de festivos y domingos">
                    <input
                      type="checkbox"
                      checked={profesionalSeleccionado.trabaja_festivos === 'S'}
                      onChange={handleToggleFestivos}
                      disabled={actualizandoFestivos}
                    />
                    <span className="switch-slider"></span>
                  </label>
                </div>
              </div>
            </div>
          ) : (
            <div style={{ color: 'var(--text-muted)', fontSize: '14px', padding: '16px 0' }}>
              Seleccione un profesional para gestionar sus horarios y agenda.
            </div>
          )}
        </div>
      </section>

      {/* HORARIOS REGISTRADOS ACTUALMENTE EN ORACLE (SE MUESTRA SOLO SI TIENE REGISTROS) */}
      {profesionalSeleccionado && periodosRegistrados.length > 0 && (
        <section className="registered-schedules-card" style={{ marginTop: '0px' }}>
          <div
            className="registered-card-header"
            onClick={() => setExpandidoHorariosRegistrados(!expandidoHorariosRegistrados)}
          >
            <div className="registered-card-title-wrap">
              <CalendarRange size={18} color="var(--accent-cyan)" />
              <div>
                <h3 className="registered-card-title">
                  Horarios Registrados en el Sistema
                </h3>
                <span className="registered-card-subtitle">
                  {profesionalSeleccionado.nombre_completo} • {horariosRegistrados.length} turnos configurados
                </span>
              </div>
            </div>

            <div className="registered-header-controls">
              <span className="meta-pill">
                {periodosRegistrados.length} Vigencia{periodosRegistrados.length !== 1 ? 's' : ''}
              </span>
              <button
                type="button"
                className="btn-collapse-toggle"
                onClick={(e) => {
                  e.stopPropagation();
                  setExpandidoHorariosRegistrados(!expandidoHorariosRegistrados);
                }}
                title={expandidoHorariosRegistrados ? 'Contraer lista' : 'Expandir lista'}
              >
                <span>{expandidoHorariosRegistrados ? 'Contraer' : 'Expandir'}</span>
                <ChevronDown
                  size={15}
                  style={{
                    transform: expandidoHorariosRegistrados ? 'rotate(180deg)' : 'rotate(0deg)',
                    transition: 'transform 0.25s ease',
                  }}
                />
              </button>
            </div>
          </div>

          {expandidoHorariosRegistrados && (
            <div className="registered-card-content">
              {periodosRegistrados.map((periodo, idx) => {
                const tieneFechaFinal = Boolean(periodo.fecha_final);

                return (
                  <div
                    key={idx}
                    className={`registered-period-block ${tieneFechaFinal ? 'period-finite' : 'period-indefinite'}`}
                  >
                    <div className="period-badge-header">
                      <div style={{ display: 'flex', alignItems: 'center', gap: '10px', flexWrap: 'wrap' }}>
                        <span className={`period-badge ${tieneFechaFinal ? 'badge-finite' : 'badge-indefinite'}`}>
                          <Calendar size={13} />
                          {tieneFechaFinal
                            ? `Horario Personalizado: ${periodo.fecha_inicial} → ${periodo.fecha_final}`
                            : `Horario Base: ${periodo.fecha_inicial} → Indefinido`}
                        </span>
                        <span className={`period-type-chip ${tieneFechaFinal ? 'chip-finite' : 'chip-indefinite'}`}>
                          {tieneFechaFinal ? 'Horario Personalizado' : 'Horario Base'}
                        </span>
                        <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                          {periodo.totalTurnos} turnos en {periodo.diasAgrupados.length} días
                        </span>
                      </div>

                      <div style={{ display: 'flex', alignItems: 'center', gap: '8px', flexWrap: 'wrap' }}>
                        {/* Botón para cargar vigencia en el editor y modificarla */}
                        <button
                          type="button"
                          onClick={() => cargarVigenciaEnEditor(periodo)}
                          className="btn-load-period"
                          title="Cargar esta vigencia en el formulario para modificar fechas u horarios"
                        >
                          <Edit3 size={13} />
                          <span>Cargar / Modificar</span>
                        </button>

                        {/* Botón para borrar toda la vigencia con confirmación in-app */}
                        <button
                          type="button"
                          onClick={() => solicitarEliminacionVigencia(periodo.fecha_inicial, periodo.fecha_final)}
                          className="btn-delete-period"
                          title="Borrar toda esta vigencia y sus horarios asociados en Oracle"
                        >
                          <Trash2 size={13} />
                          <span>Borrar Vigencia</span>
                        </button>
                      </div>
                    </div>

                    {/* Agrupación por DÍA de la semana y sus horas */}
                    <div className="registered-days-container">
                      {periodo.diasAgrupados.map((grupoDia) => (
                        <div key={grupoDia.diaKey} className="registered-day-group-card">
                          <div className="registered-day-group-header">
                            <div className="registered-day-title-box">
                              <span className="day-badge-sm">{grupoDia.diaKey}</span>
                              <span className="registered-day-name">{grupoDia.nombreDia}</span>
                            </div>
                            <span className="registered-turnos-count">
                              {grupoDia.turnos.length} turno{grupoDia.turnos.length > 1 ? 's' : ''}
                            </span>
                          </div>

                          <div className="registered-turnos-list">
                            {grupoDia.turnos.map((turno) => (
                              <div key={turno.id} className="registered-turno-row">
                                <Clock size={13} color="var(--accent-teal)" />
                                <span>
                                  <strong>{turno.hora_desde}</strong> a <strong>{turno.hora_hasta}</strong>
                                </span>
                              </div>
                            ))}
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </section>
      )}

      {/* Pestañas de Navegación */}
      <div className="tabs-container">
        <button
          className={`tab-btn ${tabActiva === 'horarios' ? 'active' : ''}`}
          onClick={() => setTabActiva('horarios')}
        >
          <Clock size={16} />
          Configurar Horarios por Rango de Fechas
          <span className="badge-count">{totalTurnosActivos} turnos listos</span>
        </button>
        <button
          className={`tab-btn ${tabActiva === 'ausencias' ? 'active' : ''}`}
          onClick={() => setTabActiva('ausencias')}
        >
          <CalendarOff size={16} />
          Ausencias y Bloqueos de Agenda
          <span className="badge-count">{ausencias.length}</span>
        </button>
      </div>

      {tabActiva === 'horarios' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
          
          {/* Banner Indicador de Vigencia en Modo Modificación */}
          {vigenciaEnEdicion && (
            <div className="editing-vigencia-banner">
              <div className="editing-vigencia-info">
                <Edit3 size={20} color="var(--accent-cyan)" />
                <div>
                  <div style={{ fontWeight: 700, fontSize: '14px', color: 'var(--text-highlight)' }}>
                    Modificando Vigencia Grabada ({vigenciaEnEdicion.descripcion})
                  </div>
                  <div style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '2px' }}>
                    Puede ajustar fechas u horas libremente. Al guardar se actualizará este período en Oracle sin duplicar registros ni generar traslapes.
                  </div>
                </div>
              </div>
              <button
                type="button"
                className="btn-cancel-editing"
                onClick={() => {
                  setVigenciaEnEdicion(null);
                  notificar('success', 'Modo edición cancelado. Ahora puede crear un nuevo horario independiente.');
                }}
                title="Cancelar modificación de esta vigencia"
              >
                <X size={14} />
                Cancelar Edición
              </button>
            </div>
          )}

          {/* PASO 1: SELECCIONAR EL RANGO DE FECHAS */}
          <section id="editor-horarios-seccion" className="master-date-card">
            <div className="master-date-header">
              <div className="master-date-title">
                <span className="master-date-step">1</span>
                <span>Paso 1: Escoger Rango de Vigencia del Horario</span>
              </div>
            </div>

            {/* Inputs de Fecha Inicial y Final */}
            <div className="master-date-grid">
              <div className="input-group">
                <label className="input-label" style={{ color: 'var(--accent-cyan)' }}>
                  <Calendar size={13} style={{ display: 'inline', marginRight: '6px' }} />
                  Fecha Inicial (Obligatoria)
                </label>
                <div className="date-input-wrapper">
                  <input
                    ref={fechaInicialRef}
                    type="date"
                    className="date-input"
                    value={fechaInicial}
                    onChange={(e) => setFechaInicial(e.target.value)}
                  />
                  <button
                    type="button"
                    className="btn-date-picker-icon"
                    onClick={() => abrirSelectorFecha(fechaInicialRef)}
                    title="Abrir calendario para escoger fecha inicial"
                  >
                    <Calendar size={16} />
                  </button>
                </div>
              </div>

              <div className="input-group">
                <label className="input-label">
                  <CalendarRange size={13} style={{ display: 'inline', marginRight: '6px' }} />
                  Fecha Final (Vigencia)
                </label>
                <div className="date-input-wrapper">
                  <input
                    ref={fechaFinalRef}
                    type="date"
                    className="date-input"
                    value={fechaFinal}
                    disabled={esIndefinido}
                    placeholder={esIndefinido ? 'Indefinido' : ''}
                    onChange={(e) => setFechaFinal(e.target.value)}
                    style={{ opacity: esIndefinido ? 0.4 : 1 }}
                  />
                  <button
                    type="button"
                    className="btn-date-picker-icon"
                    onClick={() => abrirSelectorFecha(fechaFinalRef)}
                    disabled={esIndefinido}
                    title={esIndefinido ? 'Habilite fecha final desmarcando indefinido' : 'Abrir calendario para escoger fecha final'}
                  >
                    <Calendar size={16} />
                  </button>
                </div>
              </div>

              <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', paddingTop: '10px' }}>
                <label className="day-switch-toggle">
                  <input
                    type="checkbox"
                    checked={esIndefinido}
                    onChange={(e) => {
                      setEsIndefinido(e.target.checked);
                      if (e.target.checked) setFechaFinal('');
                    }}
                  />
                  <span>Vigencia Indefinida (aplica permanentemente)</span>
                </label>
                <span style={{ fontSize: '11px', color: 'var(--text-muted)' }}>
                  Si se marca, el horario regirá a partir de la fecha inicial sin límite.
                </span>
              </div>
            </div>

            {/* Banner resumen del rango */}
            <div className="range-summary-banner">
              <Info size={16} color="var(--accent-cyan)" />
              <span>
                Los horarios configurados en el <strong>Paso 2</strong> aplicarán desde el{' '}
                <strong>{fechaInicial || 'fecha no definida'}</strong>{' '}
                {esIndefinido || !fechaFinal ? (
                  <strong>en adelante de manera indefinida</strong>
                ) : (
                  <>
                    hasta el <strong>{fechaFinal}</strong>
                  </>
                )}
                .
              </span>
            </div>
          </section>

          {/* PASO 2: ESCOGER LOS HORARIOS PARA LOS DÍAS EN ESE RANGO */}
          <section>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '16px' }}>
              <div className="master-date-title">
                <span className="master-date-step" style={{ background: 'var(--accent-teal)' }}>2</span>
                <span>Paso 2: Escoger los Horarios para los Días (en este rango de fechas)</span>
              </div>
              <span style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>
                Puede ingresar varios rangos de horas para el mismo día
              </span>
            </div>

            <div className="week-grid">
              {DIAS_SEMANA.map((dia) => {
                const conf = diasConfig[dia.key];
                const esDomingoBloqueado = dia.key === 'DO' && profesionalSeleccionado?.trabaja_festivos === 'N';

                return (
                  <div
                    key={dia.key}
                    className={`day-column ${!conf.activo ? 'inactive' : ''} ${
                      esDomingoBloqueado ? 'holiday-disabled' : ''
                    }`}
                  >
                    {/* Header del Día */}
                    <div className="day-header">
                      <div className="day-title-box">
                        <span className="day-badge">{dia.key}</span>
                        <span className="day-name">{dia.nombre}</span>
                      </div>

                      {esDomingoBloqueado ? (
                        <span
                          style={{
                            fontSize: '11px',
                            color: 'var(--color-danger)',
                            fontWeight: 700,
                            background: 'var(--color-danger-bg)',
                            padding: '2px 8px',
                            borderRadius: 'var(--radius-xs)',
                          }}
                        >
                          Bloqueado
                        </span>
                      ) : (
                        <label className="day-switch-toggle" title="Habilitar/Deshabilitar día">
                          <input
                            type="checkbox"
                            checked={conf.activo}
                            onChange={() => toggleDia(dia.key)}
                          />
                          <span
                            style={{
                              fontSize: '11px',
                              color: conf.activo ? 'var(--accent-teal)' : 'var(--text-muted)',
                            }}
                          >
                            {conf.activo ? 'Activo' : 'Cerrado'}
                          </span>
                        </label>
                      )}
                    </div>

                    {/* Cuerpo del Día */}
                    <div className="day-body">
                      {esDomingoBloqueado ? (
                        <div className="locked-day-banner">
                          <AlertCircle size={20} color="var(--color-danger)" />
                          <strong>Domingo Bloqueado</strong>
                          <span>El profesional no labora festivos ni domingos según su configuración.</span>
                        </div>
                      ) : !conf.activo || conf.turnos.length === 0 ? (
                        <div className="empty-day-state">
                          <Clock size={20} />
                          <span>No atiende este día</span>
                          <button
                            type="button"
                            onClick={() => toggleDia(dia.key)}
                            style={{
                              background: 'transparent',
                              border: 'none',
                              color: 'var(--accent-cyan)',
                              fontSize: '12px',
                              cursor: 'pointer',
                              fontWeight: 600,
                            }}
                          >
                            + Habilitar turnos
                          </button>
                        </div>
                      ) : (

                        conf.turnos.map((turno, idx) => (
                          <div key={turno.idTemp} className="time-slot-card">
                            <div className="slot-header">
                              <span className="slot-index">
                                <Sparkles size={12} color="var(--accent-teal)" />
                                Turno #{idx + 1}
                              </span>
                              <button
                                type="button"
                                onClick={() => eliminarTurno(dia.key, idx)}
                                className="btn-delete-slot"
                                title="Eliminar este turno"
                              >
                                <Trash2 size={14} />
                              </button>
                            </div>

                            <div className="hours-row">
                              <div className="input-group">
                                <label className="input-label">Desde</label>
                                <input
                                  type="time"
                                  className="time-input"
                                  value={turno.hora_desde}
                                  onChange={(e) =>
                                    actualizarTurno(dia.key, idx, 'hora_desde', e.target.value)
                                  }
                                />
                              </div>
                              <div className="input-group">
                                <label className="input-label">Hasta</label>
                                <input
                                  type="time"
                                  className="time-input"
                                  value={turno.hora_hasta}
                                  onChange={(e) =>
                                    actualizarTurno(dia.key, idx, 'hora_hasta', e.target.value)
                                  }
                                />
                              </div>
                            </div>
                          </div>
                        ))
                      )}

                      {/* Botones de acción del día */}
                      {!esDomingoBloqueado && conf.activo && (
                        <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', marginTop: 'auto' }}>
                          <button
                            type="button"
                            onClick={() => agregarTurno(dia.key)}
                            className="btn-add-slot"
                            style={{ width: '100%', justifyContent: 'center' }}
                          >
                            <Plus size={14} />
                            + Agregar Rango de Horas
                          </button>

                          {conf.turnos.length > 0 && dia.key === 'LU' && (
                            <button
                              type="button"
                              onClick={() => copiarADiasLaborales(dia.key)}
                              className="day-copy-btn"
                              title="Copiar turnos de Lunes a Martes, Miércoles, Jueves y Viernes"
                            >
                              <Copy size={12} />
                              Copiar a Lun-Vie
                            </button>
                          )}
                        </div>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>

            {/* Barra Inferior de Guardado */}
            <div className="schedule-save-banner">
              <div>
                <h4 className="schedule-save-title">
                  Guardar Horarios para este Rango de Vigencia
                </h4>
                <p className="schedule-save-desc">
                  Se guardarán <strong>{totalTurnosActivos} turnos</strong> distribuidos en los días activos con vigencia desde{' '}
                  <strong>{fechaInicial}</strong> {esIndefinido || !fechaFinal ? 'en adelante' : `hasta ${fechaFinal}`}.
                </p>
              </div>

              <div style={{ display: 'flex', alignItems: 'center', gap: '14px', flexWrap: 'wrap' }}>
                {vigenciaEnEdicion ? (
                  <div style={{ display: 'inline-flex', alignItems: 'center', gap: '6px', fontSize: '12px', color: 'var(--accent-teal)', background: 'rgba(0, 229, 163, 0.1)', padding: '6px 14px', borderRadius: 'var(--radius-xs)', border: '1px solid rgba(0, 229, 163, 0.3)' }}>
                    <Edit3 size={13} />
                    <span>Actualizando: <strong>{vigenciaEnEdicion.descripcion}</strong></span>
                  </div>
                ) : (
                  <label className="day-switch-toggle" style={{ fontSize: '12px' }}>
                    <input
                      type="checkbox"
                      checked={modoReemplazo === 1}
                      onChange={(e) => setModoReemplazo(e.target.checked ? 1 : 0)}
                    />
                    <span>Reemplazar horarios anteriores de este profesional</span>
                  </label>
                )}

                <button
                  type="button"
                  onClick={guardarHorariosRango}
                  disabled={guardando || totalTurnosActivos === 0}
                  className="btn-save-main"
                  style={{ minWidth: '220px' }}
                >
                  <Save size={16} className={guardando ? 'spinner' : ''} />
                  {guardando
                    ? 'Guardando en Oracle...'
                    : vigenciaEnEdicion
                    ? 'Actualizar Vigencia'
                    : 'Guardar Horarios'}
                </button>
              </div>
            </div>
          </section>

        </div>
      )}

      {/* VISTA 2: AUSENCIAS Y BLOQUEOS */}
      {tabActiva === 'ausencias' && (
        <section className="absence-panel-grid">
          {/* Formulario Nueva Ausencia */}
          <div className="card-glass">
            <div className="panel-title">
              <CalendarOff size={16} />
              Registrar Ausencia o Bloqueo
            </div>
            <p style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '16px' }}>
              Bloquea días específicos en que el profesional no estará disponible en su agenda médica.
            </p>

            <form onSubmit={guardarAusencia} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
              <div className="input-group">
                <label className="input-label">Fecha Inicial</label>
                <div className="date-input-wrapper">
                  <input
                    ref={fechaInicialAusenciaRef}
                    type="date"
                    className="date-input"
                    value={nuevaAusencia.fecha_inicial}
                    onChange={(e) => setNuevaAusencia({ ...nuevaAusencia, fecha_inicial: e.target.value })}
                    required
                  />
                  <button
                    type="button"
                    className="btn-date-picker-icon"
                    onClick={() => abrirSelectorFecha(fechaInicialAusenciaRef)}
                    title="Abrir calendario para escoger fecha inicial de ausencia"
                  >
                    <Calendar size={16} />
                  </button>
                </div>
              </div>

              <div className="input-group">
                <label className="input-label">Fecha Final</label>
                <div className="date-input-wrapper">
                  <input
                    ref={fechaFinalAusenciaRef}
                    type="date"
                    className="date-input"
                    value={nuevaAusencia.fecha_final}
                    onChange={(e) => setNuevaAusencia({ ...nuevaAusencia, fecha_final: e.target.value })}
                    required
                  />
                  <button
                    type="button"
                    className="btn-date-picker-icon"
                    onClick={() => abrirSelectorFecha(fechaFinalAusenciaRef)}
                    title="Abrir calendario para escoger fecha final de ausencia"
                  >
                    <Calendar size={16} />
                  </button>
                </div>
              </div>

              <button
                type="submit"
                disabled={cargando}
                className="btn-save-main"
                style={{ width: '100%', justifyContent: 'center', marginTop: '10px' }}
              >
                <Plus size={16} />
                Registrar Bloqueo de Agenda
              </button>
            </form>
          </div>

          {/* Lista de Ausencias Activas */}
          <div className="card-glass">
            <div className="panel-title">
              <ShieldCheck size={16} />
              Ausencias Programadas ({ausencias.length})
            </div>

            {ausencias.length === 0 ? (
              <div style={{ color: 'var(--text-muted)', fontSize: '13px', padding: '24px 0', textAlign: 'center' }}>
                El profesional no tiene ausencias ni bloqueos programados.
              </div>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                {ausencias.map((aus) => {
                  const esMismoDia = aus.fecha_inicial === aus.fecha_final;
                  let diasBloqueo = 1;
                  try {
                    const d1 = new Date(aus.fecha_inicial + 'T00:00:00');
                    const d2 = new Date(aus.fecha_final + 'T00:00:00');
                    const diff = Math.abs(d2.getTime() - d1.getTime());
                    diasBloqueo = Math.ceil(diff / (1000 * 60 * 60 * 24)) + 1;
                  } catch {
                    diasBloqueo = 1;
                  }

                  return (
                    <div key={aus.id} className="absence-item-card">
                      <div className="absence-info-wrap">
                        <div className="absence-icon-badge">
                          <CalendarOff size={18} />
                        </div>
                        <div className="absence-details">
                          <div className="absence-range-text">
                            {esMismoDia
                              ? `Fecha de Bloqueo: ${aus.fecha_inicial}`
                              : `Del ${aus.fecha_inicial} al ${aus.fecha_final}`}
                          </div>
                          <div className="absence-meta-row">
                            <span className="absence-days-pill">
                              {diasBloqueo} {diasBloqueo === 1 ? 'día' : 'días'} bloqueado
                            </span>
                            <span className="absence-status-text">• Agenda no disponible</span>
                          </div>
                        </div>
                      </div>

                      <button
                        type="button"
                        onClick={() => solicitarEliminacionAusencia(aus)}
                        className="btn-delete-slot"
                        title="Eliminar esta ausencia programada"
                      >
                        <Trash2 size={16} color="var(--color-danger)" />
                      </button>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        </section>
      )}

      {/* Modal In-App de Confirmación de Borrado de Vigencia (Previene bloqueos de navegador) */}
      {vigenciaAEliminar && (
        <div className="modal-backdrop" onClick={() => setVigenciaAEliminar(null)}>
          <div className="modal-dialog" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header-danger">
              <AlertCircle size={22} color="var(--color-danger)" />
              <h3>Confirmar Eliminación de Vigencia</h3>
            </div>

            <p className="modal-body-text">
              ¿Está seguro de que desea eliminar permanentemente todos los turnos registrados para la vigencia del profesional{' '}
              <strong className="modal-highlight-name">
                {profesionalSeleccionado?.nombre_completo}
              </strong>?
            </p>

            <div className="modal-highlight-box">
              <div className="modal-highlight-title">Vigencia a eliminar:</div>
              <div className="modal-highlight-desc">{vigenciaAEliminar.descripcion}</div>
              <div className="modal-highlight-subdesc">
                Esta acción borrará de la base de datos Oracle todos los horarios asociados a este rango.
              </div>
            </div>

            <div className="modal-actions">
              <button
                type="button"
                className="btn-modal-cancel"
                onClick={() => setVigenciaAEliminar(null)}
                disabled={cargando}
              >
                Cancelar
              </button>

              <button
                type="button"
                className="btn-modal-confirm-delete"
                onClick={confirmarYEliminarVigencia}
                disabled={cargando}
              >
                <Trash2 size={15} />
                {cargando ? 'Eliminando en Oracle...' : 'Sí, Eliminar Vigencia'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Modal In-App de Confirmación de Borrado de Ausencia (Estilo propio de la aplicación) */}
      {ausenciaAEliminar && (
        <div className="modal-backdrop" onClick={() => setAusenciaAEliminar(null)}>
          <div className="modal-dialog" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header-danger">
              <AlertCircle size={22} color="var(--color-danger)" />
              <h3>Confirmar Eliminación de Ausencia</h3>
            </div>

            <p className="modal-body-text">
              ¿Está seguro de que desea eliminar este bloqueo de agenda médica para el profesional{' '}
              <strong className="modal-highlight-name">
                {profesionalSeleccionado?.nombre_completo}
              </strong>?
            </p>

            <div className="modal-highlight-box">
              <div className="modal-highlight-title">Período de bloqueo a eliminar:</div>
              <div className="modal-highlight-desc">
                {ausenciaAEliminar.fecha_inicial === ausenciaAEliminar.fecha_final
                  ? `Fecha: ${ausenciaAEliminar.fecha_inicial}`
                  : `Del ${ausenciaAEliminar.fecha_inicial} al ${ausenciaAEliminar.fecha_final}`}
              </div>
              <div className="modal-highlight-subdesc">
                Al desbloquear este rango de fechas, los horarios regulares del profesional volverán a estar habilitados para la asignación de citas.
              </div>
            </div>

            <div className="modal-actions">
              <button
                type="button"
                className="btn-modal-cancel"
                onClick={() => setAusenciaAEliminar(null)}
                disabled={cargando}
              >
                Cancelar
              </button>

              <button
                type="button"
                className="btn-modal-confirm-delete"
                onClick={confirmarYEliminarAusencia}
                disabled={cargando}
              >
                <Trash2 size={15} />
                {cargando ? 'Eliminando...' : 'Sí, Eliminar Bloqueo'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Modal In-App de Advertencia: Desmarcar Festivos cuando existen turnos en Domingo */}
      {modalFestivosAdvertencia && (
        <div className="modal-backdrop" onClick={() => setModalFestivosAdvertencia(null)}>
          <div className="modal-dialog" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header-warning">
              <AlertCircle size={24} color="var(--color-danger)" />
              <h3>Advertencia: Horarios de Domingo Registrados</h3>
            </div>

            <p className="modal-body-text">
              El profesional{' '}
              <strong className="modal-highlight-name">
                {profesionalSeleccionado?.nombre_completo}
              </strong>{' '}
              tiene{' '}
              <strong className="modal-highlight-count">
                {modalFestivosAdvertencia.cantidadDomingos} turno(s)
              </strong>{' '}
              registrado(s) para el día <strong>Domingo</strong> en la base de datos Oracle.
            </p>

            <div className="modal-highlight-box">
              <div className="modal-highlight-title">¡Atención: Acción Destructiva Permanente!</div>
              <div className="modal-highlight-desc">
                Si desmarca esta opción, todos los horarios configurados para el día domingo <strong>se borrarán permanentemente</strong> de la base de datos Oracle y no se permitirá ingresar nuevos turnos para domingos.
              </div>
            </div>

            <div className="modal-actions">
              <button
                type="button"
                className="btn-modal-cancel"
                onClick={() => setModalFestivosAdvertencia(null)}
                disabled={actualizandoFestivos}
              >
                Cancelar y Mantener
              </button>

              <button
                type="button"
                className="btn-modal-confirm-warning"
                onClick={confirmarCambioFestivosANo}
                disabled={actualizandoFestivos}
              >
                <Trash2 size={15} />
                {actualizandoFestivos ? 'Borrando domingos...' : 'Confirmar y Borrar Horarios de Domingo'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

