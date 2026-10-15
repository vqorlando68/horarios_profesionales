import { NextRequest, NextResponse } from 'next/server';
import { executePlsqlContract } from '@/lib/db';

export const dynamic = 'force-dynamic';

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();

    const payload = {
      id_usuario: body.id_usuario,
      fecha_inicial: body.fecha_inicial,
      fecha_final: body.fecha_final,
      motivo: body.motivo || 'Ausencia programada',
      codigo_traza: 'WEB_REGISTRAR_AUSENCIA_' + Date.now(),
      ip_origen: req.headers.get('x-forwarded-for') || '127.0.0.1',
    };

    const resultado = await executePlsqlContract(
      'PKGLN_HORARIOS',
      'p_registrar_ausencia',
      payload
    );

    return NextResponse.json(resultado);
  } catch (error: any) {
    console.error('Error en POST /api/ausencias:', error);
    return NextResponse.json(
      {
        codigo: -20000,
        mensaje: error.message || 'Error al registrar la ausencia en Oracle.',
      },
      { status: 500 }
    );
  }
}

export async function DELETE(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);
    const id = searchParams.get('id');

    if (!id) {
      return NextResponse.json(
        { codigo: -20001, mensaje: 'El parámetro id de la ausencia es obligatorio.' },
        { status: 400 }
      );
    }

    const payload = {
      id: parseInt(id, 10),
      codigo_traza: 'WEB_ELIMINAR_AUSENCIA_' + Date.now(),
      ip_origen: req.headers.get('x-forwarded-for') || '127.0.0.1',
    };

    const resultado = await executePlsqlContract(
      'PKGLN_HORARIOS',
      'p_eliminar_ausencia',
      payload
    );

    return NextResponse.json(resultado);
  } catch (error: any) {
    console.error('Error en DELETE /api/ausencias:', error);
    return NextResponse.json(
      {
        codigo: -20000,
        mensaje: error.message || 'Error al eliminar la ausencia en Oracle.',
      },
      { status: 500 }
    );
  }
}
