import { NextRequest, NextResponse } from 'next/server';
import { executePlsqlContract, limpiarMensajeErrorOracle } from '@/lib/db';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);
    const idUsuarioStr = searchParams.get('id_usuario');

    if (!idUsuarioStr) {
      return NextResponse.json(
        { codigo: -20001, mensaje: 'El parámetro id_usuario es obligatorio.' },
        { status: 400 }
      );
    }

    const payload = {
      id_usuario: parseInt(idUsuarioStr, 10),
      codigo_traza: 'WEB_CONSULTAR_AGENDA_' + Date.now(),
      ip_origen: req.headers.get('x-forwarded-for') || '127.0.0.1',
    };

    const resultado = await executePlsqlContract(
      'PKGLN_HORARIOS',
      'p_consultar_agenda',
      payload
    );

    return NextResponse.json(resultado);
  } catch (error: any) {
    console.error('Error en GET /api/agenda:', error);
    return NextResponse.json(
      {
        codigo: -20000,
        mensaje: limpiarMensajeErrorOracle(error.message || 'Error al consultar la agenda en el Sistema.'),
      },
      { status: 500 }
    );
  }
}
