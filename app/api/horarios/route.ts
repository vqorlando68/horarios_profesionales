import { NextRequest, NextResponse } from 'next/server';
import { executePlsqlContract, limpiarMensajeErrorOracle } from '@/lib/db';

export const dynamic = 'force-dynamic';

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();

    if (!body || !body.id_usuario) {
      return NextResponse.json(
        { codigo: -20001, mensaje: 'El id_usuario es obligatorio en el cuerpo de la petición.' },
        { status: 400 }
      );
    }

    const payload = {
      id_usuario: body.id_usuario,
      reemplazar_todo: body.reemplazar_todo !== undefined ? body.reemplazar_todo : 0,
      reemplazar_vigencia: body.reemplazar_vigencia !== undefined ? body.reemplazar_vigencia : 0,
      fecha_inicial_origen: body.fecha_inicial_origen || null,
      fecha_final_origen: body.fecha_final_origen || null,
      horarios: body.horarios || [],
      codigo_traza: 'WEB_GUARDAR_HORARIOS_' + Date.now(),
      ip_origen: req.headers.get('x-forwarded-for') || '127.0.0.1',
    };

    const resultado = await executePlsqlContract(
      'PKGLN_HORARIOS',
      'p_guardar_horarios',
      payload
    );

    return NextResponse.json(resultado);
  } catch (error: any) {
    console.error('Error en POST /api/horarios:', error);
    const mensajeLimpio = limpiarMensajeErrorOracle(error.message);
    return NextResponse.json(
      {
        codigo: -20000,
        mensaje: mensajeLimpio,
      },
      { status: 400 }
    );
  }
}

export async function DELETE(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);
    const id_usuario = searchParams.get('id_usuario');
    const fecha_inicial = searchParams.get('fecha_inicial');
    const fecha_final = searchParams.get('fecha_final');
    const trabaja_festivos = searchParams.get('trabaja_festivos');

    if (!id_usuario || !fecha_inicial) {
      return NextResponse.json(
        { codigo: -20001, mensaje: 'id_usuario y fecha_inicial son obligatorios.' },
        { status: 400 }
      );
    }

    const payload = {
      id_usuario: Number(id_usuario),
      fecha_inicial: fecha_inicial,
      fecha_final: (!fecha_final || fecha_final === 'null' || fecha_final === 'undefined') ? null : fecha_final,
      trabaja_festivos: trabaja_festivos || null,
      codigo_traza: 'WEB_ELIMINAR_VIGENCIA_' + Date.now(),
      ip_origen: req.headers.get('x-forwarded-for') || '127.0.0.1',
    };

    const resultado = await executePlsqlContract(
      'PKGLN_HORARIOS',
      'p_eliminar_horarios_vigencia',
      payload
    );

    return NextResponse.json(resultado);
  } catch (error: any) {
    console.error('Error en DELETE /api/horarios:', error);
    return NextResponse.json(
      {
        codigo: -20000,
        mensaje: limpiarMensajeErrorOracle(error.message),
      },
      { status: 400 }
    );
  }
}
