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
      codigo_traza: 'WEB_CONSULTAR_FRANJAS_' + Date.now(),
      ip_origen: req.headers.get('x-forwarded-for') || '127.0.0.1',
    };

    const resultado = await executePlsqlContract(
      'PKGLN_FRANJAS',
      'p_consultar_franjas',
      payload
    );

    return NextResponse.json(resultado);
  } catch (error: any) {
    console.error('Error en GET /api/franjas:', error);
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

    const payload = {
      id_usuario: body.id_usuario,
      reemplazar_todo: body.reemplazar_todo !== undefined ? body.reemplazar_todo : 1,
      reemplazar_vigencia: body.reemplazar_vigencia !== undefined ? body.reemplazar_vigencia : 0,
      fecha_inicial_origen: body.fecha_inicial_origen || null,
      fecha_final_origen: body.fecha_final_origen || null,
      franjas: body.franjas || [],
      codigo_traza: 'WEB_GUARDAR_FRANJAS_' + Date.now(),
      ip_origen: req.headers.get('x-forwarded-for') || '127.0.0.1',
    };

    const resultado = await executePlsqlContract(
      'PKGLN_FRANJAS',
      'p_guardar_franjas',
      payload
    );

    return NextResponse.json(resultado);
  } catch (error: any) {
    console.error('Error en POST /api/franjas:', error);
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
      codigo_traza: 'WEB_ELIMINAR_FRANJA_VIGENCIA_' + Date.now(),
      ip_origen: req.headers.get('x-forwarded-for') || '127.0.0.1',
    };

    const resultado = await executePlsqlContract(
      'PKGLN_FRANJAS',
      'p_eliminar_franjas_vigencia',
      payload
    );

    return NextResponse.json(resultado);
  } catch (error: any) {
    console.error('Error en DELETE /api/franjas:', error);
    return NextResponse.json(
      {
        codigo: -20000,
        mensaje: limpiarMensajeErrorOracle(error.message),
      },
      { status: 400 }
    );
  }
}
