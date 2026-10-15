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
  Phone,
  ChevronLeft,
  ChevronRight,
  Grid,
  List,
  CalendarDays
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

type TipoAtencion = 'V' | 'O' | 'G';

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

// Interfaces dedicadas para Franjas de Atención por Rango de Fechas
interface FranjaHorario {
  idTemp: string;
  hora_desde: string;
  hora_hasta: string;
  tipo_atencion: TipoAtencion;
}

interface DiaConfigFranja {
  activo: boolean;
  turnos: FranjaHorario[];
}

interface FranjaRegistrada {
  id: number;
  dia_semana: 'LU' | 'MA' | 'MI' | 'JU' | 'VI' | 'SA' | 'DO';
  hora_desde: string;
  hora_hasta: string;
  fecha_inicial: string;
  fecha_final: string | null;
  tipo_atencion: TipoAtencion;
  activo?: number;
}

const TIPOS_ATENCION: Array<{
  codigo: TipoAtencion;
  nombre: string;
  descripcion: string;
  badgeClass: string;
}> = [
  { codigo: 'V', nombre: 'Voluntario', descripcion: 'Atención voluntaria', badgeClass: 'atencion-voluntario' },
  { codigo: 'O', nombre: 'Obligatorio', descripcion: 'Atención obligatoria', badgeClass: 'atencion-obligatorio' },
];

// Helper para visualización histórica de tipo de atención
const obtenerConfigTipoAtencion = (tipo: string) => {
  if (tipo === 'O') return { codigo: 'O', nombre: 'Obligatorio', badgeClass: 'atencion-obligatorio' };
  if (tipo === 'G') return { codigo: 'G', nombre: 'Giris', badgeClass: 'atencion-giris' };
  return { codigo: 'V', nombre: 'Voluntario', badgeClass: 'atencion-voluntario' };
};

// Función utilitaria para formatear horas a 12 horas con AM / PM
const formatearHora12 = (hora24: string): string => {
  if (!hora24) return '';
  const partes = hora24.split(':');
  if (partes.length < 2) return hora24;
  let horas = parseInt(partes[0], 10);
  const minutos = partes[1];
  if (isNaN(horas)) return hora24;
  const ampm = horas >= 12 ? 'PM' : 'AM';
  horas = horas % 12;
  if (horas === 0) horas = 12;
  return `${String(horas).padStart(2, '0')}:${minutos} ${ampm}`;
};

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
  const [franjasRegistradas, setFranjasRegistradas] = useState<FranjaRegistrada[]>([]);
  const [expandidoFranjasRegistradas, setExpandidoFranjasRegistradas] = useState<boolean>(true);
  const [ausencias, setAusencias] = useState<Ausencia[]>([]);
  const [tabActiva, setTabActiva] = useState<'horarios' | 'franjas' | 'ausencias' | 'calendario'>('horarios');

  // Estados del Módulo de Calendario
  const [vistaCalendario, setVistaCalendario] = useState<'mes' | 'semana' | 'dia' | 'agenda'>('mes');
  const [fechaCalendario, setFechaCalendario] = useState<Date>(new Date());
  const [diaModalDetalle, setDiaModalDetalle] = useState<string | null>(null);

  // Filtros de visualización por capas en Calendario (Checkboxes interactivos)
  const [filtroVerHorario, setFiltroVerHorario] = useState<boolean>(true);
  const [filtroVerVoluntario, setFiltroVerVoluntario] = useState<boolean>(true);
  const [filtroVerObligatorio, setFiltroVerObligatorio] = useState<boolean>(true);
  const [filtroVerAusencias, setFiltroVerAusencias] = useState<boolean>(true);

  // Estado para Modal In-App de Confirmación de Borrado de Vigencia (Horarios)
  const [vigenciaAEliminar, setVigenciaAEliminar] = useState<{
    fecha_inicial: string;
    fecha_final: string | null;
    descripcion: string;
  } | null>(null);

  // Estado para Modal In-App de Confirmación de Borrado de Vigencia (Franjas)
  const [franjaVigenciaAEliminar, setFranjaVigenciaAEliminar] = useState<{
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

  // Estado para Vigencia Cargada en Edición (Horarios)
  const [vigenciaEnEdicion, setVigenciaEnEdicion] = useState<{
    fecha_inicial: string;
    fecha_final: string | null;
    descripcion: string;
  } | null>(null);

  // Estado para Vigencia Cargada en Edición (Franjas)
  const [vigenciaFranjasEnEdicion, setVigenciaFranjasEnEdicion] = useState<{
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
  const [guardandoFranjas, setGuardandoFranjas] = useState(false);
  const [toast, setToast] = useState<{ tipo: 'success' | 'error'; mensaje: string } | null>(null);


  // 1. Rango de Fechas para el Horario en Edición y Refs para Pickers
  const fechaHoy = useMemo(() => new Date().toISOString().split('T')[0], []);
  const [fechaInicial, setFechaInicial] = useState<string>(fechaHoy);
  const [fechaFinal, setFechaFinal] = useState<string>('');
  const [esIndefinido, setEsIndefinido] = useState<boolean>(true);
  const [modoReemplazo, setModoReemplazo] = useState<number>(1); // 1 = Reemplaza todo, 0 = Adiciona

  // Rango de Fechas para Franjas de Atención
  const [fechaInicialFranjas, setFechaInicialFranjas] = useState<string>(fechaHoy);
  const [fechaFinalFranjas, setFechaFinalFranjas] = useState<string>('');
  const [esIndefinidoFranjas, setEsIndefinidoFranjas] = useState<boolean>(true);
  const [modoReemplazoFranjas, setModoReemplazoFranjas] = useState<number>(1);

  const fechaInicialRef = useRef<HTMLInputElement>(null);
  const fechaFinalRef = useRef<HTMLInputElement>(null);
  const fechaInicialFranjasRef = useRef<HTMLInputElement>(null);
  const fechaFinalFranjasRef = useRef<HTMLInputElement>(null);
  const fechaInicialAusenciaRef = useRef<HTMLInputElement>(null);
  const fechaFinalAusenciaRef = useRef<HTMLInputElement>(null);

  // 2. Horarios por Días de la Semana para el Rango Seleccionado (Horarios del profesional)
  const [diasConfig, setDiasConfig] = useState<Record<string, DiaConfig>>({
    LU: { activo: true, turnos: [{ idTemp: '1', hora_desde: '08:00', hora_hasta: '12:00' }, { idTemp: '2', hora_desde: '14:00', hora_hasta: '18:00' }] },
    MA: { activo: true, turnos: [{ idTemp: '3', hora_desde: '08:00', hora_hasta: '12:00' }, { idTemp: '4', hora_desde: '14:00', hora_hasta: '18:00' }] },
    MI: { activo: true, turnos: [{ idTemp: '5', hora_desde: '08:00', hora_hasta: '12:00' }, { idTemp: '6', hora_desde: '14:00', hora_hasta: '18:00' }] },
    JU: { activo: true, turnos: [{ idTemp: '7', hora_desde: '08:00', hora_hasta: '12:00' }, { idTemp: '8', hora_desde: '14:00', hora_hasta: '18:00' }] },
    VI: { activo: true, turnos: [{ idTemp: '9', hora_desde: '08:00', hora_hasta: '12:00' }, { idTemp: '10', hora_desde: '14:00', hora_hasta: '18:00' }] },
    SA: { activo: false, turnos: [{ idTemp: '11', hora_desde: '08:00', hora_hasta: '12:00' }] },
    DO: { activo: false, turnos: [{ idTemp: '12', hora_desde: '08:00', hora_hasta: '12:00' }] },
  });

  // Franjas de Atención por Días de la Semana (Independiente)
  const [diasConfigFranjas, setDiasConfigFranjas] = useState<Record<string, DiaConfigFranja>>({
    LU: { activo: true, turnos: [{ idTemp: 'f1', hora_desde: '08:00', hora_hasta: '12:00', tipo_atencion: 'V' }, { idTemp: 'f2', hora_desde: '14:00', hora_hasta: '18:00', tipo_atencion: 'O' }] },
    MA: { activo: true, turnos: [{ idTemp: 'f3', hora_desde: '08:00', hora_hasta: '12:00', tipo_atencion: 'V' }, { idTemp: 'f4', hora_desde: '14:00', hora_hasta: '18:00', tipo_atencion: 'O' }] },
    MI: { activo: true, turnos: [{ idTemp: 'f5', hora_desde: '08:00', hora_hasta: '12:00', tipo_atencion: 'V' }, { idTemp: 'f6', hora_desde: '14:00', hora_hasta: '18:00', tipo_atencion: 'O' }] },
    JU: { activo: true, turnos: [{ idTemp: 'f7', hora_desde: '08:00', hora_hasta: '12:00', tipo_atencion: 'V' }, { idTemp: 'f8', hora_desde: '14:00', hora_hasta: '18:00', tipo_atencion: 'O' }] },
    VI: { activo: true, turnos: [{ idTemp: 'f9', hora_desde: '08:00', hora_hasta: '12:00', tipo_atencion: 'V' }, { idTemp: 'f10', hora_desde: '14:00', hora_hasta: '18:00', tipo_atencion: 'O' }] },
    SA: { activo: false, turnos: [{ idTemp: 'f11', hora_desde: '08:00', hora_hasta: '12:00', tipo_atencion: 'V' }] },
    DO: { activo: false, turnos: [{ idTemp: 'f12', hora_desde: '08:00', hora_hasta: '12:00', tipo_atencion: 'V' }] },
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

  // Cargar agenda y franjas al seleccionar un profesional
  const seleccionarProfesional = async (prof: Profesional) => {
    setProfesionalSeleccionado(prof);
    setVigenciaEnEdicion(null);
    setVigenciaFranjasEnEdicion(null);
    setDropdownAbierto(false);
    setBusquedaProf('');
    setCargando(true);
    try {
      const [resAgenda, resFranjas] = await Promise.all([
        fetch(`/api/agenda?id_usuario=${prof.id_usuario}&_t=${Date.now()}`, { cache: 'no-store' }),
        fetch(`/api/franjas?id_usuario=${prof.id_usuario}&_t=${Date.now()}`, { cache: 'no-store' }),
      ]);
      const data = await resAgenda.json();
      const dataFranjas = await resFranjas.json();

      if (data && data.horarios && Array.isArray(data.horarios)) {
        setHorariosRegistrados(data.horarios);
      } else {
        setHorariosRegistrados([]);
      }

      const arrFranjas = (dataFranjas && (dataFranjas.franjas || dataFranjas.datos)) || [];
      if (Array.isArray(arrFranjas)) {
        setFranjasRegistradas(arrFranjas);
      } else {
        setFranjasRegistradas([]);
      }

      if (data && data.ausencias && Array.isArray(data.ausencias)) {
        setAusencias(data.ausencias);
      } else {
        setAusencias([]);
      }
    } catch (err: any) {
      console.warn('Error al cargar agenda y franjas:', err);
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
            {
              idTemp: Date.now().toString() + Math.random(),
              hora_desde: nuevaDesde,
              hora_hasta: nuevaHasta,
            },
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

  const actualizarTurno = (
    diaKey: string,
    index: number,
    campo: 'hora_desde' | 'hora_hasta',
    valor: string
  ) => {
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

  // =========================================================================
  // HANDLERS Y LÓGICA PARA FRANJAS DE ATENCIÓN (TAB SEPARADO)
  // =========================================================================
  const toggleDiaFranja = (diaKey: string) => {
    setDiasConfigFranjas((prev) => {
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

  const agregarFranja = (diaKey: string) => {
    setDiasConfigFranjas((prev) => {
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
            {
              idTemp: 'f_' + Date.now().toString() + Math.random(),
              hora_desde: nuevaDesde,
              hora_hasta: nuevaHasta,
              tipo_atencion: 'V',
            },
          ],
        },
      };
    });
  };

  const eliminarFranja = (diaKey: string, index: number) => {
    setDiasConfigFranjas((prev) => {
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

  const actualizarFranja = (
    diaKey: string,
    index: number,
    campo: 'hora_desde' | 'hora_hasta' | 'tipo_atencion',
    valor: any
  ) => {
    setDiasConfigFranjas((prev) => {
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

  const copiarFranjasADiasLaborales = (diaOrigenKey: string) => {
    const turnosACopiar = diasConfigFranjas[diaOrigenKey].turnos;
    setDiasConfigFranjas((prev) => {
      const nuevo = { ...prev };
      ['LU', 'MA', 'MI', 'JU', 'VI'].forEach((d) => {
        nuevo[d] = {
          activo: true,
          turnos: turnosACopiar.map((t, idx) => ({
            idTemp: 'f_copy_' + Date.now().toString() + idx + Math.random(),
            hora_desde: t.hora_desde,
            hora_hasta: t.hora_hasta,
            tipo_atencion: t.tipo_atencion || 'V',
          })),
        };
      });
      return nuevo;
    });
    notificar('success', `Franjas de ${diaOrigenKey} replicadas a Lunes-Viernes.`);
  };

  const totalFranjasActivas = useMemo(() => {
    let cuenta = 0;
    Object.values(diasConfigFranjas).forEach((d) => {
      if (d.activo) cuenta += d.turnos.length;
    });
    return cuenta;
  }, [diasConfigFranjas]);

  // Guardar Franjas de Atención por Rango de Fechas
  const guardarFranjasRango = async () => {
    if (!profesionalSeleccionado) {
      notificar('error', 'Seleccione un profesional de salud.');
      return;
    }

    if (!fechaInicialFranjas) {
      notificar('error', 'La fecha inicial del rango de vigencia de franjas es obligatoria.');
      return;
    }

    if (!esIndefinidoFranjas && fechaFinalFranjas && fechaFinalFranjas < fechaInicialFranjas) {
      notificar('error', 'La fecha final no puede ser menor a la fecha inicial.');
      return;
    }

    // Validación de unicidad de Franja Base: Solo 1 franja sin fecha final por profesional
    const esFranjaBaseAGuardar = esIndefinidoFranjas || !fechaFinalFranjas;
    if (esFranjaBaseAGuardar) {
      const existeFranjaBase = periodosFranjasRegistrados.some((p) => p.fecha_final === null);
      const editandoMismaFranjaBase =
        vigenciaFranjasEnEdicion && vigenciaFranjasEnEdicion.fecha_final === null;
      const esReemplazoTotal = !vigenciaFranjasEnEdicion && modoReemplazoFranjas === 1;

      if (existeFranjaBase && !editandoMismaFranjaBase && !esReemplazoTotal) {
        notificar(
          'error',
          'El profesional ya cuenta con una Franja Base registrada (sin fecha final). Solo se permite una única Franja Base por profesional; modifique la existente o asigne una fecha final para registrarla como Franja Personalizada.'
        );
        return;
      }
    }

    // Aplanar franjas de los días activos
    const listaFranjasAplanada: Array<{
      dia_semana: string;
      hora_desde: string;
      hora_hasta: string;
      fecha_inicial: string;
      fecha_final: string | null;
      tipo_atencion: TipoAtencion;
    }> = [];

    for (const dia of DIAS_SEMANA) {
      const conf = diasConfigFranjas[dia.key];
      if (conf.activo && conf.turnos.length > 0) {
        for (const t of conf.turnos) {
          if (t.hora_desde >= t.hora_hasta) {
            notificar('error', `En ${dia.nombre}, la hora inicial (${t.hora_desde}) debe ser menor que la final (${t.hora_hasta}).`);
            return;
          }
          if (!t.tipo_atencion) {
            notificar('error', `En ${dia.nombre}, debe seleccionar el tipo de atención (V/O/G) para cada franja.`);
            return;
          }
          listaFranjasAplanada.push({
            dia_semana: dia.key,
            hora_desde: t.hora_desde,
            hora_hasta: t.hora_hasta,
            fecha_inicial: fechaInicialFranjas,
            fecha_final: esIndefinidoFranjas || !fechaFinalFranjas ? null : fechaFinalFranjas,
            tipo_atencion: t.tipo_atencion,
          });
        }
      }
    }

    if (listaFranjasAplanada.length === 0) {
      notificar('error', 'No hay franjas de atención configuradas en ningún día para este rango de fecha.');
      return;
    }

    setGuardandoFranjas(true);
    try {
      const payload = {
        id_usuario: profesionalSeleccionado.id_usuario,
        reemplazar_todo: vigenciaFranjasEnEdicion ? 0 : modoReemplazoFranjas,
        reemplazar_vigencia: vigenciaFranjasEnEdicion ? 1 : 0,
        fecha_inicial_origen: vigenciaFranjasEnEdicion ? vigenciaFranjasEnEdicion.fecha_inicial : null,
        fecha_final_origen: vigenciaFranjasEnEdicion ? vigenciaFranjasEnEdicion.fecha_final : null,
        franjas: listaFranjasAplanada,
      };

      const res = await fetch('/api/franjas', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });

      const data = await res.json();
      if (data && data.codigo === 0) {
        const msjExito = vigenciaFranjasEnEdicion
          ? `¡Vigencia de franjas (${vigenciaFranjasEnEdicion.descripcion}) actualizada exitosamente!`
          : '¡Franjas de atención guardadas exitosamente!';
        notificar('success', msjExito);
        setVigenciaFranjasEnEdicion(null);
        seleccionarProfesional(profesionalSeleccionado);
      } else {
        notificar('error', data.mensaje || 'Error al persistir franjas de atención.');
      }
    } catch (err: any) {
      console.error(err);
      notificar('error', 'Error al comunicarse con la API de franjas.');
    } finally {
      setGuardandoFranjas(false);
    }
  };

  // Solicitar eliminación de vigencia de franjas
  const solicitarEliminacionFranjaVigencia = (fechaIni: string, fechaFin: string | null) => {
    if (!profesionalSeleccionado) return;
    const descVigencia = fechaFin
      ? `del ${fechaIni} al ${fechaFin}`
      : `a partir del ${fechaIni} (indefinida)`;

    setFranjaVigenciaAEliminar({
      fecha_inicial: fechaIni,
      fecha_final: fechaFin,
      descripcion: descVigencia,
    });
  };

  // Confirmar y procesar eliminación de vigencia de franjas
  const confirmarYEliminarFranjaVigencia = async () => {
    if (!profesionalSeleccionado || !franjaVigenciaAEliminar) return;

    setCargando(true);
    try {
      const params = new URLSearchParams({
        id_usuario: profesionalSeleccionado.id_usuario.toString(),
        fecha_inicial: franjaVigenciaAEliminar.fecha_inicial,
      });
      if (franjaVigenciaAEliminar.fecha_final) {
        params.append('fecha_final', franjaVigenciaAEliminar.fecha_final);
      }

      const res = await fetch(`/api/franjas?${params.toString()}`, {
        method: 'DELETE',
        headers: { 'Cache-Control': 'no-cache' },
      });

      const data = await res.json();
      if (data && data.codigo === 0) {
        notificar('success', `Vigencia de franjas ${franjaVigenciaAEliminar.descripcion} eliminada exitosamente.`);
        setFranjaVigenciaAEliminar(null);
        await seleccionarProfesional(profesionalSeleccionado);
      } else {
        notificar('error', data.mensaje || 'Error al eliminar la vigencia de franjas.');
      }
    } catch (err: any) {
      console.error('Error al eliminar vigencia de franjas:', err);
      notificar('error', 'Error al comunicarse con el servidor para eliminar la vigencia de franjas.');
    } finally {
      setCargando(false);
    }
  };

  // Cargar una vigencia grabada de franjas en el editor
  const cargarVigenciaFranjasEnEditor = (periodo: {
    fecha_inicial: string;
    fecha_final: string | null;
    diasAgrupados: Array<{
      diaKey: string;
      nombreDia: string;
      turnos: FranjaRegistrada[];
    }>;
  }) => {
    setFechaInicialFranjas(periodo.fecha_inicial);
    if (periodo.fecha_final) {
      setFechaFinalFranjas(periodo.fecha_final);
      setEsIndefinidoFranjas(false);
    } else {
      setFechaFinalFranjas('');
      setEsIndefinidoFranjas(true);
    }

    setVigenciaFranjasEnEdicion({
      fecha_inicial: periodo.fecha_inicial,
      fecha_final: periodo.fecha_final,
      descripcion: periodo.fecha_final
        ? `del ${periodo.fecha_inicial} al ${periodo.fecha_final}`
        : `del ${periodo.fecha_inicial} en adelante (Indefinido)`,
    });

    const mapaDiasRegistrados = new Map<string, FranjaRegistrada[]>();
    periodo.diasAgrupados.forEach((g) => {
      mapaDiasRegistrados.set(g.diaKey, g.turnos);
    });

    const nuevaConfigDiasFranjas: Record<string, DiaConfigFranja> = {};
    DIAS_SEMANA.forEach((dia) => {
      const turnosEnBD = mapaDiasRegistrados.get(dia.key);
      if (turnosEnBD && turnosEnBD.length > 0) {
        nuevaConfigDiasFranjas[dia.key] = {
          activo: true,
          turnos: turnosEnBD.map((t, idx) => ({
            idTemp: `f_${dia.key}_edit_${idx}_${Date.now()}_${Math.random()}`,
            hora_desde: t.hora_desde,
            hora_hasta: t.hora_hasta,
            tipo_atencion: t.tipo_atencion,
          })),
        };
      } else {
        nuevaConfigDiasFranjas[dia.key] = {
          activo: false,
          turnos: [
            { idTemp: `f_${dia.key}_default_${Date.now()}`, hora_desde: '08:00', hora_hasta: '12:00', tipo_atencion: 'V' },
          ],
        };
      }
    });

    setDiasConfigFranjas(nuevaConfigDiasFranjas);
    setTabActiva('franjas');

    notificar(
      'success',
      `Vigencia de franjas (${periodo.fecha_inicial} → ${periodo.fecha_final || 'Indefinido'}) cargada en el editor.`
    );

    setTimeout(() => {
      const editorEl = document.getElementById('editor-franjas-seccion');
      if (editorEl) {
        editorEl.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
    }, 100);
  };

  // Agrupación de Franjas Registradas por Período de Vigencia
  const periodosFranjasRegistrados = useMemo(() => {
    const grupos: Record<string, FranjaRegistrada[]> = {};
    franjasRegistradas.forEach((f) => {
      const clave = `${f.fecha_inicial}__${f.fecha_final || 'INDEFINIDO'}`;
      if (!grupos[clave]) grupos[clave] = [];
      grupos[clave].push(f);
    });

    return Object.entries(grupos).map(([clave, items]) => {
      const [ini, fin] = clave.split('__');

      const porDia: Record<string, FranjaRegistrada[]> = {};
      items.forEach((f) => {
        if (!porDia[f.dia_semana]) porDia[f.dia_semana] = [];
        porDia[f.dia_semana].push(f);
      });

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
      if (a.fecha_final === null && b.fecha_final !== null) return -1;
      if (b.fecha_final === null && a.fecha_final !== null) return 1;
      return a.fecha_inicial.localeCompare(b.fecha_inicial);
    });
  }, [franjasRegistradas]);

  // Cargar / Importar la estructura de algún horario del profesional a las franjas
  const copiarHorarioProfesionalAFranjas = (periodoIndex: number) => {
    const periodo = periodosRegistrados[periodoIndex];
    if (!periodo) return;

    // 1. Cargar fechas sugeridas
    setFechaInicialFranjas(periodo.fecha_inicial);
    if (periodo.fecha_final) {
      setFechaFinalFranjas(periodo.fecha_final);
      setEsIndefinidoFranjas(false);
    } else {
      setFechaFinalFranjas('');
      setEsIndefinidoFranjas(true);
    }

    setVigenciaFranjasEnEdicion(null);

    // 2. Mapear días y turnos a franjas
    const mapaDias = new Map<string, HorarioRegistrado[]>();
    periodo.diasAgrupados.forEach((g) => {
      mapaDias.set(g.diaKey, g.turnos);
    });

    const nuevaConfigDiasFranjas: Record<string, DiaConfigFranja> = {};
    DIAS_SEMANA.forEach((dia) => {
      const turnosEnHorario = mapaDias.get(dia.key);
      if (turnosEnHorario && turnosEnHorario.length > 0) {
        nuevaConfigDiasFranjas[dia.key] = {
          activo: true,
          turnos: turnosEnHorario.map((t, idx) => ({
            idTemp: `f_imp_${dia.key}_${idx}_${Date.now()}_${Math.random()}`,
            hora_desde: t.hora_desde,
            hora_hasta: t.hora_hasta,
            tipo_atencion: 'V' as TipoAtencion,
          })),
        };
      } else {
        nuevaConfigDiasFranjas[dia.key] = {
          activo: false,
          turnos: [
            { idTemp: `f_${dia.key}_default_${Date.now()}`, hora_desde: '08:00', hora_hasta: '12:00', tipo_atencion: 'V' },
          ],
        };
      }
    });

    setDiasConfigFranjas(nuevaConfigDiasFranjas);

    const desc = periodo.fecha_final
      ? `Horario Personalizado (${periodo.fecha_inicial} a ${periodo.fecha_final})`
      : `Horario Base (${periodo.fecha_inicial} en adelante)`;

    notificar(
      'success',
      `¡${desc} cargado en el editor de franjas! Ahora puede ajustar las horas y definir qué turnos son Voluntarios u Obligatorios.`
    );

    setTimeout(() => {
      const editorEl = document.getElementById('editor-franjas-seccion');
      if (editorEl) {
        editorEl.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
    }, 100);
  };

  // =========================================================================
  // LÓGICA Y HELPERS DEL CALENDARIO INTEGRADO (REGLA DE PREVALENCIA)
  // =========================================================================

  // Helper para obtener YYYY-MM-DD sin desfase UTC
  const formatYMD = (date: Date): string => {
    const y = date.getFullYear();
    const m = String(date.getMonth() + 1).padStart(2, '0');
    const d = String(date.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
  };

  // Helper para determinar código de día ('LU' .. 'DO')
  const obtenerKeyDiaSemana = (fechaStr: string): 'LU' | 'MA' | 'MI' | 'JU' | 'VI' | 'SA' | 'DO' => {
    const [y, m, d] = fechaStr.split('-').map(Number);
    const dt = new Date(y, m - 1, d);
    const day = dt.getDay(); // 0 = Domingo, 1 = Lunes, ..., 6 = Sábado
    const map: Record<number, 'LU' | 'MA' | 'MI' | 'JU' | 'VI' | 'SA' | 'DO'> = {
      0: 'DO',
      1: 'LU',
      2: 'MA',
      3: 'MI',
      4: 'JU',
      5: 'VI',
      6: 'SA',
    };
    return map[day];
  };

  // Resolución diaria con regla estricta de prevalencia y filtros de visualización:
  // "prima es la que en el rango tenga fecha_final de lo contrario aplica lo que no tenga fecha_final"
  const resolverDiaCalendario = (fechaStr: string) => {
    const diaKey = obtenerKeyDiaSemana(fechaStr);
    const noLaboraFestivo = diaKey === 'DO' && profesionalSeleccionado?.trabaja_festivos === 'N';

    // 1. Ausencias (filtradas por filtroVerAusencias)
    const tieneAusenciaReal = ausencias.some(
      (a) => fechaStr >= a.fecha_inicial && fechaStr <= a.fecha_final
    );
    const tieneAusencia = filtroVerAusencias && tieneAusenciaReal;

    // 2. Horario del profesional (Encima, filtrado por filtroVerHorario)
    let turnosHorario: HorarioRegistrado[] = [];
    if (filtroVerHorario && !noLaboraFestivo) {
      // Prioridad 1: Vigencia con fecha_final (Horario Personalizado)
      const turnosPersonalizados = horariosRegistrados.filter(
        (h) =>
          h.fecha_final !== null &&
          fechaStr >= h.fecha_inicial &&
          fechaStr <= h.fecha_final &&
          h.dia_semana === diaKey
      );

      if (turnosPersonalizados.length > 0) {
        turnosHorario = turnosPersonalizados;
      } else {
        // Prioridad 2: Vigencia sin fecha_final (Horario Base)
        turnosHorario = horariosRegistrados.filter(
          (h) =>
            h.fecha_final === null &&
            fechaStr >= h.fecha_inicial &&
            h.dia_semana === diaKey
        );
      }
      turnosHorario.sort((a, b) => a.hora_desde.localeCompare(b.hora_desde));
    }

    // 3. Franjas de atención (filtradas por filtroVerVoluntario y filtroVerObligatorio)
    let franjasDia: FranjaRegistrada[] = [];
    if (filtroVerVoluntario || filtroVerObligatorio) {
      // Prioridad 1: Franja con fecha_final (Personalizada)
      const franjasPersonalizadas = franjasRegistradas.filter(
        (f) =>
          f.fecha_final !== null &&
          fechaStr >= f.fecha_inicial &&
          fechaStr <= f.fecha_final &&
          f.dia_semana === diaKey
      );

      if (franjasPersonalizadas.length > 0) {
        franjasDia = franjasPersonalizadas;
      } else {
        // Prioridad 2: Franja sin fecha_final (Franja Base)
        franjasDia = franjasRegistradas.filter(
          (f) =>
            f.fecha_final === null &&
            fechaStr >= f.fecha_inicial &&
            f.dia_semana === diaKey
        );
      }

      // Filtrar según los tipos de franja seleccionados en los checks
      franjasDia = franjasDia.filter((f) => {
        if (f.tipo_atencion === 'V') return filtroVerVoluntario;
        if (f.tipo_atencion === 'O') return filtroVerObligatorio;
        return true;
      });

      franjasDia.sort((a, b) => a.hora_desde.localeCompare(b.hora_desde));
    }

    return {
      fechaStr,
      diaKey,
      tieneAusencia,
      tieneAusenciaReal,
      noLaboraFestivo,
      turnosHorario,
      franjasDia,
    };
  };

  // Controles de navegación de fecha del Calendario
  const navegarAnterior = () => {
    setFechaCalendario((prev) => {
      const nueva = new Date(prev);
      if (vistaCalendario === 'mes') {
        nueva.setMonth(nueva.getMonth() - 1);
      } else if (vistaCalendario === 'semana') {
        nueva.setDate(nueva.getDate() - 7);
      } else if (vistaCalendario === 'dia') {
        nueva.setDate(nueva.getDate() - 1);
      } else {
        nueva.setDate(nueva.getDate() - 15);
      }
      return nueva;
    });
  };

  const navegarSiguiente = () => {
    setFechaCalendario((prev) => {
      const nueva = new Date(prev);
      if (vistaCalendario === 'mes') {
        nueva.setMonth(nueva.getMonth() + 1);
      } else if (vistaCalendario === 'semana') {
        nueva.setDate(nueva.getDate() + 7);
      } else if (vistaCalendario === 'dia') {
        nueva.setDate(nueva.getDate() + 1);
      } else {
        nueva.setDate(nueva.getDate() + 15);
      }
      return nueva;
    });
  };

  const irAHoy = () => {
    setFechaCalendario(new Date());
  };

  // Título dinámico del período según la vista activa
  const tituloPeriodo = useMemo(() => {
    const meses = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
    ];
    const anio = fechaCalendario.getFullYear();
    const mesIndex = fechaCalendario.getMonth();

    if (vistaCalendario === 'mes') {
      return `${meses[mesIndex]} ${anio}`;
    }

    if (vistaCalendario === 'dia') {
      const diasSem = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];
      const diaNom = diasSem[fechaCalendario.getDay()];
      return `${diaNom}, ${fechaCalendario.getDate()} de ${meses[mesIndex]} ${anio}`;
    }

    if (vistaCalendario === 'semana') {
      const current = new Date(fechaCalendario);
      const day = current.getDay();
      const diffToMonday = current.getDate() - day + (day === 0 ? -6 : 1);
      const monday = new Date(current.setDate(diffToMonday));
      const sunday = new Date(monday);
      sunday.setDate(monday.getDate() + 6);

      return `Semana: ${monday.getDate()} ${meses[monday.getMonth()]} - ${sunday.getDate()} ${meses[sunday.getMonth()]} ${sunday.getFullYear()}`;
    }

    return `Agenda desde ${fechaCalendario.getDate()} de ${meses[mesIndex]} ${anio}`;
  }, [fechaCalendario, vistaCalendario]);

  // Días para la vista Mes
  const diasVistaMes = useMemo(() => {
    const anio = fechaCalendario.getFullYear();
    const mes = fechaCalendario.getMonth();

    const primerDiaMes = new Date(anio, mes, 1);
    const ultimoDiaMes = new Date(anio, mes + 1, 0);

    const primerDiaSemana = primerDiaMes.getDay();
    const paddingInicio = primerDiaSemana === 0 ? 6 : primerDiaSemana - 1;

    const celdas: Array<{
      fechaStr: string;
      diaNumero: number;
      esMesActual: boolean;
      esHoy: boolean;
    }> = [];

    const hoyStr = formatYMD(new Date());

    for (let i = paddingInicio; i > 0; i--) {
      const d = new Date(anio, mes, 1 - i);
      const fStr = formatYMD(d);
      celdas.push({
        fechaStr: fStr,
        diaNumero: d.getDate(),
        esMesActual: false,
        esHoy: fStr === hoyStr,
      });
    }

    for (let d = 1; d <= ultimoDiaMes.getDate(); d++) {
      const dObj = new Date(anio, mes, d);
      const fStr = formatYMD(dObj);
      celdas.push({
        fechaStr: fStr,
        diaNumero: d,
        esMesActual: true,
        esHoy: fStr === hoyStr,
      });
    }

    const totalCeldas = celdas.length;
    const paddingFin = totalCeldas % 7 === 0 ? 0 : 7 - (totalCeldas % 7);
    for (let i = 1; i <= paddingFin; i++) {
      const d = new Date(anio, mes + 1, i);
      const fStr = formatYMD(d);
      celdas.push({
        fechaStr: fStr,
        diaNumero: d.getDate(),
        esMesActual: false,
        esHoy: fStr === hoyStr,
      });
    }

    return celdas;
  }, [fechaCalendario]);

  // Días para la vista Semana (Lunes a Domingo)
  const diasVistaSemana = useMemo(() => {
    const current = new Date(fechaCalendario);
    const day = current.getDay();
    const diffToMonday = current.getDate() - day + (day === 0 ? -6 : 1);
    const monday = new Date(current.setDate(diffToMonday));

    const hoyStr = formatYMD(new Date());
    const dias: Array<{
      fechaStr: string;
      nombreDia: string;
      diaNumero: number;
      diaKey: string;
      esHoy: boolean;
    }> = [];

    const nombres = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    const keys = ['LU', 'MA', 'MI', 'JU', 'VI', 'SA', 'DO'];

    for (let i = 0; i < 7; i++) {
      const d = new Date(monday);
      d.setDate(monday.getDate() + i);
      const fStr = formatYMD(d);
      dias.push({
        fechaStr: fStr,
        nombreDia: nombres[i],
        diaNumero: d.getDate(),
        diaKey: keys[i],
        esHoy: fStr === hoyStr,
      });
    }

    return dias;
  }, [fechaCalendario]);

  // Días para la vista Agenda (21 días secuenciales)
  const diasVistaAgenda = useMemo(() => {
    const dias: Array<{
      fechaStr: string;
      diaNumero: number;
      nombreMes: string;
      nombreDia: string;
      diaKey: string;
      esHoy: boolean;
    }> = [];

    const mesesCortos = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    const nombresSem = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];
    const hoyStr = formatYMD(new Date());

    for (let i = 0; i < 21; i++) {
      const d = new Date(fechaCalendario);
      d.setDate(fechaCalendario.getDate() + i);
      const fStr = formatYMD(d);
      const diaKey = obtenerKeyDiaSemana(fStr);

      dias.push({
        fechaStr: fStr,
        diaNumero: d.getDate(),
        nombreMes: mesesCortos[d.getMonth()],
        nombreDia: nombresSem[d.getDay()],
        diaKey,
        esHoy: fStr === hoyStr,
      });
    }

    return dias;
  }, [fechaCalendario]);

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
                                <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                                  <Clock size={13} color="var(--accent-teal)" />
                                  <span>
                                    <strong>{formatearHora12(turno.hora_desde)}</strong> a{' '}
                                    <strong>{formatearHora12(turno.hora_hasta)}</strong>
                                  </span>
                                </div>
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
          className={`tab-btn ${tabActiva === 'franjas' ? 'active' : ''}`}
          onClick={() => setTabActiva('franjas')}
        >
          <Sparkles size={16} />
          Franjas de Atención por Rango de Fechas
          <span className="badge-count">{totalFranjasActivas} franjas listas</span>
        </button>
        <button
          className={`tab-btn ${tabActiva === 'ausencias' ? 'active' : ''}`}
          onClick={() => setTabActiva('ausencias')}
        >
          <CalendarOff size={16} />
          Ausencias y Bloqueos de Agenda
          <span className="badge-count">{ausencias.length}</span>
        </button>
        <button
          className={`tab-btn ${tabActiva === 'calendario' ? 'active' : ''}`}
          onClick={() => setTabActiva('calendario')}
        >
          <CalendarDays size={16} />
          Calendario
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

      {/* VISTA 2: FRANJAS DE ATENCIÓN POR RANGO DE FECHAS (TAB SEPARADO) */}
      {tabActiva === 'franjas' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
          
          {/* FRANJAS REGISTRADAS ACTUALMENTE EN ORACLE (SE MUESTRA SOLO SI TIENE REGISTROS) */}
          {profesionalSeleccionado && periodosFranjasRegistrados.length > 0 && (
            <section className="registered-schedules-card" style={{ marginTop: '0px' }}>
              <div
                className="registered-card-header"
                onClick={() => setExpandidoFranjasRegistradas(!expandidoFranjasRegistradas)}
              >
                <div className="registered-card-title-wrap">
                  <CalendarRange size={18} color="var(--accent-purple)" />
                  <div>
                    <h3 className="registered-card-title">
                      Franjas de Atención Registradas en el Sistema
                    </h3>
                    <span className="registered-card-subtitle">
                      {profesionalSeleccionado.nombre_completo} • {franjasRegistradas.length} franjas configuradas
                    </span>
                  </div>
                </div>

                <div className="registered-header-controls">
                  <span className="meta-pill">
                    {periodosFranjasRegistrados.length} Vigencia{periodosFranjasRegistrados.length !== 1 ? 's' : ''}
                  </span>
                  <button
                    type="button"
                    className="btn-collapse-toggle"
                    onClick={(e) => {
                      e.stopPropagation();
                      setExpandidoFranjasRegistradas(!expandidoFranjasRegistradas);
                    }}
                    title={expandidoFranjasRegistradas ? 'Contraer lista' : 'Expandir lista'}
                  >
                    <span>{expandidoFranjasRegistradas ? 'Contraer' : 'Expandir'}</span>
                    <ChevronDown
                      size={15}
                      style={{
                        transform: expandidoFranjasRegistradas ? 'rotate(180deg)' : 'rotate(0deg)',
                        transition: 'transform 0.25s ease',
                      }}
                    />
                  </button>
                </div>
              </div>

              {expandidoFranjasRegistradas && (
                <div className="registered-card-content">
                  {periodosFranjasRegistrados.map((periodo, idx) => {
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
                                ? `Franja Personalizada: ${periodo.fecha_inicial} → ${periodo.fecha_final}`
                                : `Franja Base: ${periodo.fecha_inicial} → Indefinido`}
                            </span>
                            <span className={`period-type-chip ${tieneFechaFinal ? 'chip-finite' : 'chip-indefinite'}`}>
                              {tieneFechaFinal ? 'Franja Personalizada' : 'Franja Base'}
                            </span>
                            <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                              {periodo.totalTurnos} franjas en {periodo.diasAgrupados.length} días
                            </span>
                          </div>

                          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', flexWrap: 'wrap' }}>
                            <button
                              type="button"
                              onClick={() => cargarVigenciaFranjasEnEditor(periodo)}
                              className="btn-load-period"
                              title="Cargar esta vigencia en el formulario para modificar fechas o franjas"
                            >
                              <Edit3 size={13} />
                              <span>Cargar / Modificar</span>
                            </button>

                            <button
                              type="button"
                              onClick={() => solicitarEliminacionFranjaVigencia(periodo.fecha_inicial, periodo.fecha_final)}
                              className="btn-delete-period"
                              title="Borrar toda esta vigencia de franjas en Oracle"
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
                                  {grupoDia.turnos.length} franja{grupoDia.turnos.length > 1 ? 's' : ''}
                                </span>
                              </div>

                              <div className="registered-turnos-list">
                                {grupoDia.turnos.map((turno) => {
                                  const tipoConf = obtenerConfigTipoAtencion(turno.tipo_atencion);
                                  return (
                                    <div key={turno.id} className="registered-turno-row">
                                      <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                                        <Clock size={13} color="var(--accent-purple)" />
                                        <span>
                                          <strong>{formatearHora12(turno.hora_desde)}</strong> a{' '}
                                          <strong>{formatearHora12(turno.hora_hasta)}</strong>
                                        </span>
                                      </div>
                                      <span
                                        className={`turno-atencion-pill ${tipoConf.badgeClass}`}
                                        title={`Modalidad: ${tipoConf.nombre}`}
                                      >
                                        {tipoConf.nombre}
                                      </span>
                                    </div>
                                  );
                                })}
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

          {/* Banner Indicador de Vigencia en Modo Modificación */}
          {vigenciaFranjasEnEdicion && (
            <div className="editing-vigencia-banner">
              <div className="editing-vigencia-info">
                <Edit3 size={20} color="var(--accent-purple)" />
                <div>
                  <div style={{ fontWeight: 700, fontSize: '14px', color: 'var(--text-highlight)' }}>
                    Modificando Vigencia Grabada de Franjas ({vigenciaFranjasEnEdicion.descripcion})
                  </div>
                  <div style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '2px' }}>
                    Puede ajustar fechas, franjas y tipos de atención. Al guardar se actualizará este período en Oracle.
                  </div>
                </div>
              </div>
              <button
                type="button"
                className="btn-cancel-editing"
                onClick={() => {
                  setVigenciaFranjasEnEdicion(null);
                  notificar('success', 'Modo edición de franjas cancelado.');
                }}
                title="Cancelar modificación de esta vigencia"
              >
                <X size={14} />
                Cancelar Edición
              </button>
            </div>
          )}

          {/* Importación Rápida desde Horarios del Profesional */}
          <div className="card-glass" style={{ border: '1px solid rgba(139, 92, 246, 0.3)', padding: '16px 20px', background: 'rgba(139, 92, 246, 0.05)', borderRadius: 'var(--radius-md)' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '14px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                <div style={{ width: '38px', height: '38px', borderRadius: '10px', background: 'rgba(139, 92, 246, 0.2)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#C4B5FD' }}>
                  <Copy size={18} />
                </div>
                <div>
                  <div style={{ fontWeight: 700, fontSize: '13.5px', color: 'var(--text-primary)' }}>
                    Cargar desde Horario del Profesional
                  </div>
                  <div style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>
                    Seleccione un horario registrado del profesional para cargarlo directamente en el editor y asignar el tipo de atención.
                  </div>
                </div>
              </div>

              {periodosRegistrados.length > 0 ? (
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px', flexWrap: 'wrap' }}>
                  <select
                    id="select-horario-profesional-franjas"
                    className="date-input"
                    defaultValue=""
                    onChange={(e) => {
                      const idx = parseInt(e.target.value, 10);
                      if (!isNaN(idx)) {
                        copiarHorarioProfesionalAFranjas(idx);
                        e.target.value = '';
                      }
                    }}
                    style={{ minWidth: '300px', padding: '9px 12px', fontSize: '12.5px', cursor: 'pointer', borderColor: 'rgba(139, 92, 246, 0.4)' }}
                  >
                    <option value="" disabled>Seleccione un horario del profesional a cargar...</option>
                    {periodosRegistrados.map((p, idx) => (
                      <option key={idx} value={idx}>
                        {p.fecha_final
                          ? `Horario Personalizado: ${p.fecha_inicial} → ${p.fecha_final} (${p.totalTurnos} turnos)`
                          : `Horario Base: ${p.fecha_inicial} → Indefinido (${p.totalTurnos} turnos)`}
                      </option>
                    ))}
                  </select>
                </div>
              ) : (
                <div style={{ fontSize: '12px', color: 'var(--text-muted)', fontStyle: 'italic' }}>
                  El profesional no tiene horarios registrados aún. Puede configurar las franjas manualmente abajo.
                </div>
              )}
            </div>
          </div>

          {/* PASO 1: SELECCIONAR EL RANGO DE FECHAS DE FRANJAS */}
          <section id="editor-franjas-seccion" className="master-date-card">
            <div className="master-date-header">
              <div className="master-date-title">
                <span className="master-date-step" style={{ background: 'var(--accent-purple)' }}>1</span>
                <span>Paso 1: Escoger Rango de Vigencia de las Franjas de Atención</span>
              </div>
            </div>

            <div className="master-date-grid">
              <div className="input-group">
                <label className="input-label" style={{ color: 'var(--accent-purple)' }}>
                  <Calendar size={13} style={{ display: 'inline', marginRight: '6px' }} />
                  Fecha Inicial (Obligatoria)
                </label>
                <div className="date-input-wrapper">
                  <input
                    ref={fechaInicialFranjasRef}
                    type="date"
                    className="date-input"
                    value={fechaInicialFranjas}
                    onChange={(e) => setFechaInicialFranjas(e.target.value)}
                  />
                  <button
                    type="button"
                    className="btn-date-picker-icon"
                    onClick={() => abrirSelectorFecha(fechaInicialFranjasRef)}
                    title="Abrir calendario para escoger fecha inicial de franjas"
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
                    ref={fechaFinalFranjasRef}
                    type="date"
                    className="date-input"
                    value={fechaFinalFranjas}
                    disabled={esIndefinidoFranjas}
                    placeholder={esIndefinidoFranjas ? 'Indefinido' : ''}
                    onChange={(e) => setFechaFinalFranjas(e.target.value)}
                    style={{ opacity: esIndefinidoFranjas ? 0.4 : 1 }}
                  />
                  <button
                    type="button"
                    className="btn-date-picker-icon"
                    onClick={() => abrirSelectorFecha(fechaFinalFranjasRef)}
                    disabled={esIndefinidoFranjas}
                    title={esIndefinidoFranjas ? 'Habilite fecha final desmarcando indefinido' : 'Abrir calendario para escoger fecha final'}
                  >
                    <Calendar size={16} />
                  </button>
                </div>
              </div>

              <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', paddingTop: '10px' }}>
                <label className="day-switch-toggle">
                  <input
                    type="checkbox"
                    checked={esIndefinidoFranjas}
                    onChange={(e) => {
                      setEsIndefinidoFranjas(e.target.checked);
                      if (e.target.checked) setFechaFinalFranjas('');
                    }}
                  />
                  <span>Vigencia Indefinida (aplica permanentemente)</span>
                </label>
                <span style={{ fontSize: '11px', color: 'var(--text-muted)' }}>
                  Si se marca, las franjas regirán a partir de la fecha inicial sin límite.
                </span>
              </div>
            </div>

            <div className="range-summary-banner">
              <Info size={16} color="var(--accent-purple)" />
              <span>
                Las franjas configuradas en el <strong>Paso 2</strong> aplicarán desde el{' '}
                <strong>{fechaInicialFranjas || 'fecha no definida'}</strong>{' '}
                {esIndefinidoFranjas || !fechaFinalFranjas ? (
                  <strong>en adelante de manera indefinida</strong>
                ) : (
                  <>
                    hasta el <strong>{fechaFinalFranjas}</strong>
                  </>
                )}
                .
              </span>
            </div>
          </section>

          {/* PASO 2: ESCOGER LAS FRANJAS Y EL TIPO DE ATENCIÓN PARA CADA RANGO */}
          <section>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '16px' }}>
              <div className="master-date-title">
                <span className="master-date-step" style={{ background: 'var(--accent-purple)' }}>2</span>
                <span>Paso 2: Configurar Franjas Horarias y Tipo de Atención por Día</span>
              </div>
              <span style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>
                Cada franja debe tener un tipo de atención asignado (Voluntario, Obligatorio o Giris)
              </span>
            </div>

            <div className="week-grid">
              {DIAS_SEMANA.map((dia) => {
                const conf = diasConfigFranjas[dia.key];

                return (
                  <div
                    key={dia.key}
                    className={`day-column ${!conf.activo ? 'inactive' : ''}`}
                  >
                    {/* Header del Día */}
                    <div className="day-header">
                      <div className="day-title-box">
                        <span className="day-badge" style={{ background: 'rgba(139, 92, 246, 0.2)', borderColor: 'rgba(139, 92, 246, 0.4)', color: '#C4B5FD' }}>
                          {dia.key}
                        </span>
                        <span className="day-name">{dia.nombre}</span>
                      </div>

                      <label className="day-switch-toggle" title="Habilitar/Deshabilitar día">
                        <input
                          type="checkbox"
                          checked={conf.activo}
                          onChange={() => toggleDiaFranja(dia.key)}
                        />
                        <span
                          style={{
                            fontSize: '11px',
                            color: conf.activo ? 'var(--accent-purple)' : 'var(--text-muted)',
                          }}
                        >
                          {conf.activo ? 'Activo' : 'Cerrado'}
                        </span>
                      </label>
                    </div>

                    {/* Cuerpo del Día */}
                    <div className="day-body">
                      {!conf.activo || conf.turnos.length === 0 ? (
                        <div className="empty-day-state">
                          <Clock size={20} />
                          <span>Sin franjas este día</span>
                          <button
                            type="button"
                            onClick={() => toggleDiaFranja(dia.key)}
                            style={{
                              background: 'transparent',
                              border: 'none',
                              color: 'var(--accent-purple)',
                              fontSize: '12px',
                              cursor: 'pointer',
                              fontWeight: 600,
                            }}
                          >
                            + Habilitar franjas
                          </button>
                        </div>
                      ) : (
                        conf.turnos.map((turno, idx) => (
                          <div key={turno.idTemp} className="time-slot-card">
                            <div className="slot-header">
                              <span className="slot-index">
                                <Sparkles size={12} color="var(--accent-purple)" />
                                Franja #{idx + 1}
                              </span>
                              <button
                                type="button"
                                onClick={() => eliminarFranja(dia.key, idx)}
                                className="btn-delete-slot"
                                title="Eliminar esta franja"
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
                                    actualizarFranja(dia.key, idx, 'hora_desde', e.target.value)
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
                                    actualizarFranja(dia.key, idx, 'hora_hasta', e.target.value)
                                  }
                                />
                              </div>
                            </div>

                            {/* Selector de Tipo de Atención Exclusivo de la Franja */}
                            <div className="tipo-atencion-selector-wrap">
                              <label className="tipo-atencion-label">Tipo de Atención:</label>
                              <div className="tipo-atencion-chips">
                                {TIPOS_ATENCION.map((tAtenc) => {
                                  const activo = turno.tipo_atencion === tAtenc.codigo;
                                  return (
                                    <button
                                      key={tAtenc.codigo}
                                      type="button"
                                      onClick={() =>
                                        actualizarFranja(dia.key, idx, 'tipo_atencion', tAtenc.codigo)
                                      }
                                      className={`chip-tipo-atenc ${tAtenc.badgeClass} ${
                                        activo ? 'active' : ''
                                      }`}
                                      title={tAtenc.descripcion}
                                    >
                                      <span className="chip-code">{tAtenc.codigo}</span>
                                      <span className="chip-text">{tAtenc.nombre}</span>
                                    </button>
                                  );
                                })}
                              </div>
                            </div>
                          </div>
                        ))
                      )}

                      {/* Botones de acción del día */}
                      {conf.activo && (
                        <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', marginTop: 'auto' }}>
                          <button
                            type="button"
                            onClick={() => agregarFranja(dia.key)}
                            className="btn-add-slot"
                            style={{ width: '100%', justifyContent: 'center' }}
                          >
                            <Plus size={14} />
                            + Agregar Franja Horaria
                          </button>

                          {conf.turnos.length > 0 && dia.key === 'LU' && (
                            <button
                              type="button"
                              onClick={() => copiarFranjasADiasLaborales(dia.key)}
                              className="day-copy-btn"
                              title="Copiar franjas de Lunes a Martes, Miércoles, Jueves y Viernes"
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

            {/* Barra Inferior de Guardado de Franjas */}
            <div className="schedule-save-banner">
              <div>
                <h4 className="schedule-save-title">
                  Guardar Franjas de Atención para este Rango de Vigencia
                </h4>
                <p className="schedule-save-desc">
                  Se guardarán <strong>{totalFranjasActivas} franjas</strong> distribuidas en los días activos con vigencia desde{' '}
                  <strong>{fechaInicialFranjas}</strong> {esIndefinidoFranjas || !fechaFinalFranjas ? 'en adelante' : `hasta ${fechaFinalFranjas}`}.
                </p>
              </div>

              <div style={{ display: 'flex', alignItems: 'center', gap: '14px', flexWrap: 'wrap' }}>
                {vigenciaFranjasEnEdicion ? (
                  <div style={{ display: 'inline-flex', alignItems: 'center', gap: '6px', fontSize: '12px', color: 'var(--accent-purple)', background: 'rgba(139, 92, 246, 0.1)', padding: '6px 14px', borderRadius: 'var(--radius-xs)', border: '1px solid rgba(139, 92, 246, 0.3)' }}>
                    <Edit3 size={13} />
                    <span>Actualizando: <strong>{vigenciaFranjasEnEdicion.descripcion}</strong></span>
                  </div>
                ) : (
                  <label className="day-switch-toggle" style={{ fontSize: '12px' }}>
                    <input
                      type="checkbox"
                      checked={modoReemplazoFranjas === 1}
                      onChange={(e) => setModoReemplazoFranjas(e.target.checked ? 1 : 0)}
                    />
                    <span>Reemplazar franjas anteriores de este profesional</span>
                  </label>
                )}

                <button
                  type="button"
                  onClick={guardarFranjasRango}
                  disabled={guardandoFranjas || totalFranjasActivas === 0}
                  className="btn-save-main"
                  style={{ minWidth: '220px', background: 'linear-gradient(135deg, var(--accent-purple) 0%, #6D28D9 100%)' }}
                >
                  <Save size={16} className={guardandoFranjas ? 'spinner' : ''} />
                  {guardandoFranjas
                    ? 'Guardando en Oracle...'
                    : vigenciaFranjasEnEdicion
                    ? 'Actualizar Vigencia'
                    : 'Guardar Franjas'}
                </button>
              </div>
            </div>
          </section>

        </div>
      )}

      {/* VISTA 3: AUSENCIAS Y BLOQUEOS */}
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

      {/* VISTA 4: CALENDARIO DE TURNOS Y FRANJAS (MES, SEMANA, DÍA, AGENTA) */}
      {tabActiva === 'calendario' && (
        <div className="calendar-main-wrapper">
          {/* Barra de Herramientas y Navegación del Calendario */}
          <div className="calendar-toolbar-card">
            <div className="calendar-toolbar-top">
              {/* Grupo de Navegación de Fecha */}
              <div className="calendar-nav-group">
                <button
                  type="button"
                  onClick={navegarAnterior}
                  className="btn-calendar-nav"
                  title="Período anterior"
                >
                  <ChevronLeft size={18} />
                </button>
                <button
                  type="button"
                  onClick={irAHoy}
                  className="btn-calendar-today"
                  title="Ir al día de hoy"
                >
                  Hoy
                </button>
                <button
                  type="button"
                  onClick={navegarSiguiente}
                  className="btn-calendar-nav"
                  title="Período siguiente"
                >
                  <ChevronRight size={18} />
                </button>
                <div className="calendar-title-text">{tituloPeriodo}</div>
              </div>

              {/* Selector de Vistas: Mes, Semana, Día, Agenda */}
              <div className="calendar-view-selector">
                <button
                  type="button"
                  onClick={() => setVistaCalendario('mes')}
                  className={`calendar-view-tab ${vistaCalendario === 'mes' ? 'active' : ''}`}
                >
                  <Grid size={14} />
                  Mes
                </button>
                <button
                  type="button"
                  onClick={() => setVistaCalendario('semana')}
                  className={`calendar-view-tab ${vistaCalendario === 'semana' ? 'active' : ''}`}
                >
                  <CalendarRange size={14} />
                  Semana
                </button>
                <button
                  type="button"
                  onClick={() => setVistaCalendario('dia')}
                  className={`calendar-view-tab ${vistaCalendario === 'dia' ? 'active' : ''}`}
                >
                  <Clock size={14} />
                  Día
                </button>
                <button
                  type="button"
                  onClick={() => setVistaCalendario('agenda')}
                  className={`calendar-view-tab ${vistaCalendario === 'agenda' ? 'active' : ''}`}
                >
                  <List size={14} />
                  Agenda
                </button>
              </div>
            </div>

            {/* Leyenda y Explicación de Prevalencia con Checkboxes de Filtro */}
            <div className="calendar-legend-bar">
              <label className={`legend-filter-chip ${filtroVerHorario ? 'active' : 'inactive'}`} title="Marcar/desmarcar para mostrar u ocultar el horario laboral en el calendario">
                <input
                  type="checkbox"
                  checked={filtroVerHorario}
                  onChange={(e) => setFiltroVerHorario(e.target.checked)}
                />
                <span className="legend-dot profesional"></span>
                <span>Horario Laboral Profesional (Encima)</span>
              </label>

              <label className={`legend-filter-chip ${filtroVerVoluntario ? 'active' : 'inactive'}`} title="Marcar/desmarcar para mostrar u ocultar franjas de tipo voluntario">
                <input
                  type="checkbox"
                  checked={filtroVerVoluntario}
                  onChange={(e) => setFiltroVerVoluntario(e.target.checked)}
                />
                <span className="legend-dot voluntario"></span>
                <span>Franja Voluntaria</span>
              </label>

              <label className={`legend-filter-chip ${filtroVerObligatorio ? 'active' : 'inactive'}`} title="Marcar/desmarcar para mostrar u ocultar franjas de tipo obligatorio">
                <input
                  type="checkbox"
                  checked={filtroVerObligatorio}
                  onChange={(e) => setFiltroVerObligatorio(e.target.checked)}
                />
                <span className="legend-dot obligatorio"></span>
                <span>Franja Obligatoria</span>
              </label>

              <label className={`legend-filter-chip ${filtroVerAusencias ? 'active' : 'inactive'}`} title="Marcar/desmarcar para mostrar u ocultar bloqueos por ausencias">
                <input
                  type="checkbox"
                  checked={filtroVerAusencias}
                  onChange={(e) => setFiltroVerAusencias(e.target.checked)}
                />
                <span className="legend-dot ausencia"></span>
                <span>Ausencia / Bloqueo</span>
              </label>

              <span style={{ marginLeft: 'auto', fontSize: '11px', color: 'var(--text-muted)' }}>
                ⭐ Regla: Prima la vigencia con fecha final; en su ausencia aplica el horario/franja base.
              </span>
            </div>
          </div>

          {/* 1. VISTA MES */}
          {vistaCalendario === 'mes' && (
            <div className="calendar-month-grid">
              <div className="month-days-header-row">
                <div>LUN</div>
                <div>MAR</div>
                <div>MIÉ</div>
                <div>JUE</div>
                <div>VIE</div>
                <div>SÁB</div>
                <div>DOM</div>
              </div>

              <div className="month-cells-grid">
                {diasVistaMes.map((c, i) => {
                  const dataDia = resolverDiaCalendario(c.fechaStr);
                  const totalItems = dataDia.turnosHorario.length + dataDia.franjasDia.length;

                  return (
                    <div
                      key={i}
                      className={`month-day-cell ${!c.esMesActual ? 'other-month' : ''} ${
                        c.esHoy ? 'is-today' : ''
                      } ${dataDia.tieneAusencia ? 'is-blocked' : ''}`}
                      onClick={() => setDiaModalDetalle(c.fechaStr)}
                      title={`Clic para ver detalle de ${c.fechaStr}`}
                    >
                      <div className="month-day-header-line">
                        <span className="month-day-number">{c.diaNumero}</span>
                        {dataDia.tieneAusencia && (
                          <span className="badge-absence-pill">
                            <CalendarOff size={10} /> Bloqueado
                          </span>
                        )}
                        {!dataDia.tieneAusencia && dataDia.noLaboraFestivo && (
                          <span style={{ fontSize: '9px', color: 'var(--text-muted)' }}>No festivos</span>
                        )}
                      </div>

                      {/* Si hay ausencia, solo mostrar banner de ausencia */}
                      {dataDia.tieneAusencia ? (
                        <div style={{ fontSize: '10.5px', color: 'var(--color-danger)', fontWeight: 600, padding: '2px 4px' }}>
                          Agenda bloqueada por ausencia médica
                        </div>
                      ) : (
                        <>
                          {/* Horario del Profesional (Encima) */}
                          {dataDia.turnosHorario.map((th, idx) => (
                            <div key={`th_${idx}`} className="cal-event-horario" title={`Horario Profesional: ${formatearHora12(th.hora_desde)} a ${formatearHora12(th.hora_hasta)}`}>
                              <Clock size={10} />
                              <span>{formatearHora12(th.hora_desde)} - {formatearHora12(th.hora_hasta)}</span>
                            </div>
                          ))}

                          {/* Franjas de Atención (Debajo, con color distintivo por tipo) */}
                          {dataDia.franjasDia.slice(0, 3).map((fr, idx) => {
                            const confTipo = obtenerConfigTipoAtencion(fr.tipo_atencion);
                            const claseTipo = fr.tipo_atencion === 'O' ? 'obligatorio' : fr.tipo_atencion === 'G' ? 'giris' : 'voluntario';
                            return (
                              <div
                                key={`fr_${idx}`}
                                className={`cal-event-franja ${claseTipo}`}
                                title={`Franja ${confTipo.nombre}: ${formatearHora12(fr.hora_desde)} a ${formatearHora12(fr.hora_hasta)}`}
                              >
                                <span>{formatearHora12(fr.hora_desde)} - {formatearHora12(fr.hora_hasta)}</span>
                                <span style={{ opacity: 0.85, fontSize: '9px' }}>{confTipo.codigo}</span>
                              </div>
                            );
                          })}

                          {dataDia.franjasDia.length > 3 && (
                            <div className="cal-more-events">
                              +{dataDia.franjasDia.length - 3} franjas más...
                            </div>
                          )}

                          {totalItems === 0 && !dataDia.noLaboraFestivo && (
                            <span style={{ fontSize: '10px', color: 'var(--text-muted)', marginTop: 'auto' }}>
                              Sin turnos
                            </span>
                          )}
                        </>
                      )}
                    </div>
                  );
                })}
              </div>
            </div>
          )}

          {/* 2. VISTA SEMANA */}
          {vistaCalendario === 'semana' && (
            <div className="calendar-week-grid">
              {diasVistaSemana.map((d, i) => {
                const dataDia = resolverDiaCalendario(d.fechaStr);

                return (
                  <div key={i} className={`week-day-card ${d.esHoy ? 'is-today' : ''}`}>
                    <div className="week-day-header">
                      <div>
                        <div className="week-day-name">{d.nombreDia}</div>
                        <div className="week-day-date">{d.fechaStr}</div>
                      </div>
                      {d.esHoy && (
                        <span className="cal-today-pill">
                          Hoy
                        </span>
                      )}
                    </div>

                    {dataDia.tieneAusencia ? (
                      <div className="locked-day-banner" style={{ marginTop: '10px' }}>
                        <CalendarOff size={18} color="var(--color-danger)" />
                        <strong>Día Bloqueado</strong>
                        <span>Ausencia o permiso médico programado</span>
                      </div>
                    ) : (
                      <>
                        {/* Sección 1: Horario Profesional (Encima) */}
                        {filtroVerHorario && (
                          <div>
                            <div className="week-section-title">
                              <Clock size={11} color="var(--accent-teal)" />
                              Horario Profesional
                            </div>
                            {dataDia.turnosHorario.length === 0 ? (
                              <div style={{ fontSize: '11px', color: 'var(--text-muted)', padding: '4px 0' }}>
                                {dataDia.noLaboraFestivo ? 'No labora domingos' : 'Sin horario base ni personalizado'}
                              </div>
                            ) : (
                              dataDia.turnosHorario.map((th, idx) => (
                                <div key={`w_th_${idx}`} className="cal-event-horario">
                                  <Clock size={11} />
                                  <span>{formatearHora12(th.hora_desde)} a {formatearHora12(th.hora_hasta)}</span>
                                </div>
                              ))
                            )}
                          </div>
                        )}

                        {/* Sección 2: Franjas de Atención (Debajo) */}
                        {(filtroVerVoluntario || filtroVerObligatorio) && (
                          <div style={{ marginTop: filtroVerHorario ? '8px' : '0px', flex: 1 }}>
                            <div className="week-section-title">
                              <Sparkles size={11} color="var(--accent-purple)" />
                              Franjas de Atención ({dataDia.franjasDia.length})
                            </div>
                            {dataDia.franjasDia.length === 0 ? (
                              <div style={{ fontSize: '11px', color: 'var(--text-muted)', padding: '4px 0' }}>
                                Sin franjas para los filtros activos
                              </div>
                            ) : (
                              <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
                                {dataDia.franjasDia.map((fr, idx) => {
                                  const confTipo = obtenerConfigTipoAtencion(fr.tipo_atencion);
                                  const claseTipo = fr.tipo_atencion === 'O' ? 'obligatorio' : fr.tipo_atencion === 'G' ? 'giris' : 'voluntario';
                                  return (
                                    <div key={`w_fr_${idx}`} className={`cal-event-franja ${claseTipo}`} style={{ padding: '6px 8px' }}>
                                      <div>
                                        <strong>{formatearHora12(fr.hora_desde)}</strong> a <strong>{formatearHora12(fr.hora_hasta)}</strong>
                                      </div>
                                      <span className={`turno-atencion-pill ${confTipo.badgeClass}`} style={{ fontSize: '9.5px' }}>
                                        {confTipo.nombre}
                                      </span>
                                    </div>
                                  );
                                })}
                              </div>
                            )}
                          </div>
                        )}

                        {!filtroVerHorario && !filtroVerVoluntario && !filtroVerObligatorio && (
                          <div style={{ fontSize: '11px', color: 'var(--text-muted)', padding: '16px 0', textAlign: 'center' }}>
                            Capas desactivadas en la leyenda
                          </div>
                        )}
                      </>
                    )}
                  </div>
                );
              })}
            </div>
          )}

          {/* 3. VISTA DÍA */}
          {vistaCalendario === 'dia' && (() => {
            const fStr = formatYMD(fechaCalendario);
            const dataDia = resolverDiaCalendario(fStr);

            return (
              <div className="calendar-day-view-wrap">
                <div className="day-view-hero-card">
                  <div>
                    <h3 style={{ fontSize: '20px', fontWeight: 800, color: 'var(--text-highlight)' }}>
                      {tituloPeriodo}
                    </h3>
                    <p style={{ fontSize: '13px', color: 'var(--text-secondary)', marginTop: '2px' }}>
                      {profesionalSeleccionado?.nombre_completo} • {dataDia.turnosHorario.length} turnos de horario • {dataDia.franjasDia.length} franjas de atención
                    </p>
                  </div>

                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <button
                      type="button"
                      onClick={() => {
                        const nueva = new Date(fechaCalendario);
                        nueva.setDate(nueva.getDate() - 1);
                        setFechaCalendario(nueva);
                      }}
                      className="btn-add-slot"
                    >
                      <ChevronLeft size={14} /> Día Anterior
                    </button>
                    <button
                      type="button"
                      onClick={() => {
                        const nueva = new Date(fechaCalendario);
                        nueva.setDate(nueva.getDate() + 1);
                        setFechaCalendario(nueva);
                      }}
                      className="btn-add-slot"
                    >
                      Día Siguiente <ChevronRight size={14} />
                    </button>
                  </div>
                </div>

                {dataDia.tieneAusencia ? (
                  <div className="card-glass" style={{ textAlign: 'center', padding: '40px 20px' }}>
                    <CalendarOff size={36} color="var(--color-danger)" style={{ margin: '0 auto 12px' }} />
                    <h4 style={{ fontSize: '18px', color: 'var(--color-danger)' }}>Día no disponible por Ausencia o Bloqueo</h4>
                    <p style={{ color: 'var(--text-secondary)', fontSize: '13px', maxWidth: '450px', margin: '8px auto 0' }}>
                      El profesional tiene registrada una ausencia para este día en la agenda médica.
                    </p>
                  </div>
                ) : (
                  <div className="day-view-detail-grid">
                    {/* Tarjeta de Horario del Profesional (Encima) */}
                    {filtroVerHorario && (
                      <div className="card-glass">
                        <div className="panel-title" style={{ color: 'var(--accent-teal)' }}>
                          <Clock size={18} />
                          Horario del Profesional
                        </div>
                        <p style={{ fontSize: '12px', color: 'var(--text-secondary)', marginBottom: '14px' }}>
                          Jornada regular de atención programada para este día.
                        </p>

                        {dataDia.turnosHorario.length === 0 ? (
                          <div style={{ color: 'var(--text-muted)', fontSize: '13px', padding: '20px 0' }}>
                            {dataDia.noLaboraFestivo ? 'No atiende domingos según su configuración.' : 'No tiene horario configurado para este día.'}
                          </div>
                        ) : (
                          <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                            {dataDia.turnosHorario.map((th, idx) => (
                              <div key={idx} className="registered-turno-row" style={{ padding: '12px 16px' }}>
                                <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                                  <Clock size={16} color="var(--accent-teal)" />
                                  <div>
                                    <div style={{ fontSize: '14px', fontWeight: 700, color: 'var(--text-highlight)' }}>
                                      {formatearHora12(th.hora_desde)} a {formatearHora12(th.hora_hasta)}
                                    </div>
                                    <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>
                                      {th.fecha_final ? 'Horario Personalizado' : 'Horario Base'}
                                    </div>
                                  </div>
                                </div>
                              </div>
                            ))}
                          </div>
                        )}
                      </div>
                    )}

                    {/* Tarjeta de Franjas de Atención */}
                    {(filtroVerVoluntario || filtroVerObligatorio) && (
                      <div className="card-glass">
                        <div className="panel-title" style={{ color: 'var(--accent-purple)' }}>
                          <Sparkles size={18} />
                          Franjas de Atención ({dataDia.franjasDia.length})
                        </div>
                        <p style={{ fontSize: '12px', color: 'var(--text-secondary)', marginBottom: '14px' }}>
                          Modalidades específicas de atención asignadas para cada rango horario.
                        </p>

                        {dataDia.franjasDia.length === 0 ? (
                          <div style={{ color: 'var(--text-muted)', fontSize: '13px', padding: '20px 0' }}>
                            No hay franjas de atención asignadas para este día según los filtros.
                          </div>
                        ) : (
                          <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                            {dataDia.franjasDia.map((fr, idx) => {
                              const confTipo = obtenerConfigTipoAtencion(fr.tipo_atencion);
                              return (
                                <div key={idx} className="registered-turno-row" style={{ padding: '12px 16px' }}>
                                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                                    <Clock size={16} color="var(--accent-purple)" />
                                    <div>
                                      <div style={{ fontSize: '14px', fontWeight: 700, color: 'var(--text-highlight)' }}>
                                        {formatearHora12(fr.hora_desde)} a {formatearHora12(fr.hora_hasta)}
                                      </div>
                                      <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>
                                        {fr.fecha_final ? 'Franja Personalizada' : 'Franja Base'}
                                      </div>
                                    </div>
                                  </div>
                                  <span className={`turno-atencion-pill ${confTipo.badgeClass}`}>
                                    {confTipo.nombre}
                                  </span>
                                </div>
                              );
                            })}
                          </div>
                        )}
                      </div>
                    )}

                    {!filtroVerHorario && !filtroVerVoluntario && !filtroVerObligatorio && (
                      <div className="card-glass" style={{ textAlign: 'center', padding: '30px' }}>
                        <p style={{ color: 'var(--text-muted)', fontSize: '13px' }}>
                          Las capas de horario y franjas están desactivadas en los filtros de la leyenda.
                        </p>
                      </div>
                    )}
                  </div>
                )}
              </div>
            );
          })()}

          {/* 4. VISTA TIPO AGENDA */}
          {vistaCalendario === 'agenda' && (
            <div className="calendar-agenda-list">
              {diasVistaAgenda.map((d, i) => {
                const dataDia = resolverDiaCalendario(d.fechaStr);
                const totalItems = dataDia.turnosHorario.length + dataDia.franjasDia.length;

                return (
                  <div key={i} className="agenda-day-item">
                    <div className={`agenda-date-badge ${d.esHoy ? 'is-today' : ''}`}>
                      <div className="agenda-date-num">{d.diaNumero}</div>
                      <div className="agenda-date-day">{d.nombreMes} • {d.nombreDia.substring(0, 3)}</div>
                    </div>

                    <div className="agenda-events-col">
                      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                        <span style={{ fontSize: '14px', fontWeight: 700, color: 'var(--text-highlight)' }}>
                          {d.nombreDia}, {d.fechaStr}
                        </span>
                        {dataDia.tieneAusencia && (
                          <span className="badge-absence-pill">
                            <CalendarOff size={11} /> Bloqueado por Ausencia
                          </span>
                        )}
                      </div>

                      {dataDia.tieneAusencia ? (
                        <div style={{ fontSize: '12px', color: 'var(--color-danger)' }}>
                          Agenda bloqueada para citas médicas
                        </div>
                      ) : totalItems === 0 ? (
                        <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                          {dataDia.noLaboraFestivo ? 'Día domingo no laborable para este profesional.' : 'Sin horarios ni franjas programadas.'}
                        </div>
                      ) : (
                        <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', marginTop: '4px' }}>
                          {/* Horario del Profesional Encima */}
                          {dataDia.turnosHorario.length > 0 && (
                            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', flexWrap: 'wrap' }}>
                              <span style={{ fontSize: '11px', color: 'var(--accent-teal)', fontWeight: 700 }}>
                                Jornada:
                              </span>
                              {dataDia.turnosHorario.map((th, idx) => (
                                <span key={idx} className="cal-event-horario" style={{ display: 'inline-flex' }}>
                                  <Clock size={11} /> {formatearHora12(th.hora_desde)} a {formatearHora12(th.hora_hasta)}
                                </span>
                              ))}
                            </div>
                          )}

                          {/* Franjas Debajo */}
                          {dataDia.franjasDia.length > 0 && (
                            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', flexWrap: 'wrap', marginTop: '2px' }}>
                              <span style={{ fontSize: '11px', color: 'var(--accent-purple)', fontWeight: 700 }}>
                                Franjas:
                              </span>
                              {dataDia.franjasDia.map((fr, idx) => {
                                const confTipo = obtenerConfigTipoAtencion(fr.tipo_atencion);
                                const claseTipo = fr.tipo_atencion === 'O' ? 'obligatorio' : fr.tipo_atencion === 'G' ? 'giris' : 'voluntario';
                                return (
                                  <span key={idx} className={`cal-event-franja ${claseTipo}`} style={{ display: 'inline-flex', padding: '3px 8px' }}>
                                    {formatearHora12(fr.hora_desde)} - {formatearHora12(fr.hora_hasta)} ({confTipo.nombre})
                                  </span>
                                );
                              })}
                            </div>
                          )}
                        </div>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          )}

          {/* Modal In-App de Detalle del Día al hacer clic en el mes */}
          {diaModalDetalle && (() => {
            const dataDia = resolverDiaCalendario(diaModalDetalle);

            return (
              <div className="modal-backdrop" onClick={() => setDiaModalDetalle(null)}>
                <div className="modal-dialog" onClick={(e) => e.stopPropagation()} style={{ maxWidth: '560px' }}>
                  <div className="modal-header-warning" style={{ background: 'rgba(0, 210, 255, 0.1)', borderColor: 'rgba(0, 210, 255, 0.3)' }}>
                    <Calendar size={22} color="var(--accent-cyan)" />
                    <h3 style={{ color: 'var(--accent-cyan)' }}>Detalle de Agenda: {diaModalDetalle}</h3>
                  </div>

                  <div className="modal-body-text">
                    <p style={{ marginBottom: '14px', fontSize: '13px', color: 'var(--text-secondary)' }}>
                      Profesional: <strong>{profesionalSeleccionado?.nombre_completo}</strong>
                    </p>

                    {dataDia.tieneAusencia ? (
                      <div className="modal-highlight-box" style={{ borderColor: 'var(--color-danger)' }}>
                        <div className="modal-highlight-title" style={{ color: 'var(--color-danger)' }}>
                          Bloqueado por Ausencia
                        </div>
                        <div className="modal-highlight-desc">
                          Este día se encuentra bloqueado por permiso o ausencia médica.
                        </div>
                      </div>
                    ) : (
                      <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
                        {/* Horario Profesional */}
                        {filtroVerHorario && (
                          <div>
                            <div style={{ fontSize: '12px', fontWeight: 700, color: 'var(--accent-teal)', marginBottom: '6px' }}>
                              Horario del Profesional (Encima)
                            </div>
                            {dataDia.turnosHorario.length === 0 ? (
                              <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                                {dataDia.noLaboraFestivo ? 'No labora domingo.' : 'Sin turnos asignados.'}
                              </div>
                            ) : (
                              dataDia.turnosHorario.map((th, idx) => (
                                <div key={idx} className="cal-event-horario" style={{ padding: '6px 10px', fontSize: '12px', marginBottom: '4px' }}>
                                  <Clock size={13} /> {formatearHora12(th.hora_desde)} a {formatearHora12(th.hora_hasta)}
                                </div>
                              ))
                            )}
                          </div>
                        )}

                        {/* Franjas de Atención */}
                        {(filtroVerVoluntario || filtroVerObligatorio) && (
                          <div>
                            <div style={{ fontSize: '12px', fontWeight: 700, color: 'var(--accent-purple)', marginBottom: '6px' }}>
                              Franjas de Atención ({dataDia.franjasDia.length})
                            </div>
                            {dataDia.franjasDia.length === 0 ? (
                              <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                                Sin franjas para los filtros activos.
                              </div>
                            ) : (
                              dataDia.franjasDia.map((fr, idx) => {
                                const confTipo = obtenerConfigTipoAtencion(fr.tipo_atencion);
                                const claseTipo = fr.tipo_atencion === 'O' ? 'obligatorio' : fr.tipo_atencion === 'G' ? 'giris' : 'voluntario';
                                return (
                                  <div key={idx} className={`cal-event-franja ${claseTipo}`} style={{ padding: '6px 10px', fontSize: '12px', marginBottom: '4px' }}>
                                    <span>{formatearHora12(fr.hora_desde)} a {formatearHora12(fr.hora_hasta)}</span>
                                    <span className={`turno-atencion-pill ${confTipo.badgeClass}`}>{confTipo.nombre}</span>
                                  </div>
                                );
                              })
                            )}
                          </div>
                        )}

                        {!filtroVerHorario && !filtroVerVoluntario && !filtroVerObligatorio && (
                          <div style={{ color: 'var(--text-muted)', fontSize: '12px', textAlign: 'center', padding: '16px 0' }}>
                            Las capas de visualización están desactivadas en los filtros del calendario.
                          </div>
                        )}
                      </div>
                    )}
                  </div>

                  <div className="modal-actions">
                    <button
                      type="button"
                      className="btn-modal-cancel"
                      onClick={() => setDiaModalDetalle(null)}
                    >
                      Cerrar
                    </button>
                    <button
                      type="button"
                      className="btn-add-slot"
                      onClick={() => {
                        const [y, m, d] = diaModalDetalle.split('-').map(Number);
                        setFechaCalendario(new Date(y, m - 1, d));
                        setVistaCalendario('dia');
                        setDiaModalDetalle(null);
                      }}
                    >
                      Ver en Vista Día
                    </button>
                  </div>
                </div>
              </div>
            );
          })()}
        </div>
      )}

      {/* Modal In-App de Confirmación de Borrado de Vigencia de Franjas */}
      {franjaVigenciaAEliminar && (
        <div className="modal-backdrop" onClick={() => setFranjaVigenciaAEliminar(null)}>
          <div className="modal-dialog" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header-danger">
              <AlertCircle size={22} color="var(--color-danger)" />
              <h3>Confirmar Eliminación de Vigencia de Franjas</h3>
            </div>

            <p className="modal-body-text">
              ¿Está seguro de que desea eliminar permanentemente todas las franjas de atención registradas para la vigencia del profesional{' '}
              <strong className="modal-highlight-name">
                {profesionalSeleccionado?.nombre_completo}
              </strong>?
            </p>

            <div className="modal-highlight-box">
              <div className="modal-highlight-title">Vigencia a eliminar:</div>
              <div className="modal-highlight-desc">{franjaVigenciaAEliminar.descripcion}</div>
              <div className="modal-highlight-subdesc">
                Esta acción borrará de la base de datos Oracle todas las franjas asociadas a este rango.
              </div>
            </div>

            <div className="modal-actions">
              <button
                type="button"
                className="btn-modal-cancel"
                onClick={() => setFranjaVigenciaAEliminar(null)}
                disabled={cargando}
              >
                Cancelar
              </button>

              <button
                type="button"
                className="btn-modal-confirm-delete"
                onClick={confirmarYEliminarFranjaVigencia}
                disabled={cargando}
              >
                <Trash2 size={15} />
                {cargando ? 'Eliminando en Oracle...' : 'Sí, Eliminar Franjas'}
              </button>
            </div>
          </div>
        </div>
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

