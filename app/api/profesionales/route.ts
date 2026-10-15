import { NextRequest, NextResponse } from 'next/server';
import { executePlsqlContract, limpiarMensajeErrorOracle } from '@/lib/db';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);
    const filtro = searchParams.get('filtro') || '';

    const payload = {
      filtro: filtro,
      codigo_traza: 'WEB_LISTAR_PROFESIONALES_' + Date.now(),
      ip_origen: req.headers.get('x-forwarded-for') || '127.0.0.1',
    };

    const resultado = await executePlsqlContract(
      'PKGLN_HORARIOS',
      'p_listar_profesionales',
      payload
    );

    return NextResponse.json(resultado);
  } catch (error: any) {
    console.error('Error en GET /api/profesionales:', error);
    return NextResponse.json(
      {
        codigo: -20000,
        mensaje: limpiarMensajeErrorOracle(error.message),
        datos: [],
      },
      { status: 500 }
    );
  }
}

export async function PATCH(req: NextRequest) {
  try {
    const body = await req.json();
    const { id_usuario, trabaja_festivos, borrar_domingos } = body;

    if (!id_usuario) {
      return NextResponse.json(
        { codigo: -20001, mensaje: 'El ID de usuario es obligatorio.' },
        { status: 400 }
      );
    }

    if (trabaja_festivos !== 'S' && trabaja_festivos !== 'N') {
      return NextResponse.json(
        { codigo: -20009, mensaje: "El valor de trabaja_festivos debe ser 'S' o 'N'." },
        { status: 400 }
      );
    }

    const payload = {
      id_usuario: Number(id_usuario),
      trabaja_festivos: trabaja_festivos,
      borrar_domingos: borrar_domingos ? 1 : 0,
      codigo_traza: 'WEB_UPD_FESTIVOS_' + Date.now(),
      ip_origen: req.headers.get('x-forwarded-for') || '127.0.0.1',
    };

    const resultado = await executePlsqlContract(
      'PKGLN_HORARIOS',
      'p_actualizar_trabaja_festivos',
      payload
    );

    return NextResponse.json(resultado);
  } catch (error: any) {
    console.error('Error en PATCH /api/profesionales:', error);
    return NextResponse.json(
      {
        codigo: -20000,
        mensaje: limpiarMensajeErrorOracle(error.message),
      },
      { status: 400 }
    );
  }
}


