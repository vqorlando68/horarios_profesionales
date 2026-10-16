import { NextRequest, NextResponse } from 'next/server';
import { executePlsqlContract, limpiarMensajeErrorOracle } from '@/lib/db';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);
    const id_usuario = searchParams.get('id_usuario');

    if (!id_usuario) {
      return NextResponse.json(
        { codigo: -20001, mensaje: 'id_usuario es obligatorio.' },
        { status: 400 }
      );
    }

    const payload = {
      id_usuario: Number(id_usuario),
      codigo_traza: 'WEB_CONSULTAR_TIEMPOS_' + Date.now(),
      ip_origen: req.headers.get('x-forwarded-for') || '127.0.0.1',
    };

    const resultado = await executePlsqlContract(
      'PKGLN_TIEMPOS_ATENCION',
      'p_consultar_tiempos',
      payload
    );

    return NextResponse.json(resultado);
  } catch (error: any) {
    console.error('Error en GET /api/tiempos-atencion:', error);
    return NextResponse.json(
      {
        codigo: -20000,
        mensaje: limpiarMensajeErrorOracle(error.message),
      },
      { status: 400 }
    );
  }
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();

    if (!body || !body.id_usuario) {
      return NextResponse.json(
        { codigo: -20001, mensaje: 'El id_usuario es obligatorio en el cuerpo de la petición.' },
        { status: 400 }
      );
    }

    if (!body.tiempos || !Array.isArray(body.tiempos) || body.tiempos.length === 0) {
      return NextResponse.json(
        { codigo: -20002, mensaje: 'El arreglo de tiempos es obligatorio y no puede estar vacío.' },
        { status: 400 }
      );
    }

    const payload = {
      id_usuario: Number(body.id_usuario),
      tiempos: body.tiempos,
      codigo_traza: 'WEB_GUARDAR_TIEMPOS_' + Date.now(),
      ip_origen: req.headers.get('x-forwarded-for') || '127.0.0.1',
    };

    const resultado = await executePlsqlContract(
      'PKGLN_TIEMPOS_ATENCION',
      'p_guardar_tiempos',
      payload
    );

    return NextResponse.json(resultado);
  } catch (error: any) {
    console.error('Error en POST /api/tiempos-atencion:', error);
    return NextResponse.json(
      {
        codigo: -20000,
        mensaje: limpiarMensajeErrorOracle(error.message),
      },
      { status: 400 }
    );
  }
}

export async function DELETE(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);
    const id_usuario = searchParams.get('id_usuario');
    const id_tipo_aseguramiento = searchParams.get('id_tipo_aseguramiento');

    if (!id_usuario || !id_tipo_aseguramiento) {
      return NextResponse.json(
        { codigo: -20001, mensaje: 'id_usuario e id_tipo_aseguramiento son obligatorios.' },
        { status: 400 }
      );
    }

    const payload = {
      id_usuario: Number(id_usuario),
      id_tipo_aseguramiento: Number(id_tipo_aseguramiento),
      codigo_traza: 'WEB_ELIMINAR_TIEMPO_' + Date.now(),
      ip_origen: req.headers.get('x-forwarded-for') || '127.0.0.1',
    };

    const resultado = await executePlsqlContract(
      'PKGLN_TIEMPOS_ATENCION',
      'p_eliminar_tiempo',
      payload
    );

    return NextResponse.json(resultado);
  } catch (error: any) {
    console.error('Error en DELETE /api/tiempos-atencion:', error);
    return NextResponse.json(
      {
        codigo: -20000,
        mensaje: limpiarMensajeErrorOracle(error.message),
      },
      { status: 400 }
    );
  }
}
