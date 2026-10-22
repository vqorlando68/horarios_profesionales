import { NextResponse } from 'next/server';
import { getDbConnection, limpiarMensajeErrorOracle } from '@/lib/db';

export const dynamic = 'force-dynamic';

export async function GET() {
  let conn;
  try {
    conn = await getDbConnection();
    const result = await conn.execute(
      `SELECT c.id,
              c.nombre_convenio,
              c.id_entidad_hijo,
              e.tipo_aseguramiento
         FROM tkr_convenios c,
              tkr_entidades e
        WHERE e.id(+) = c.id_entidad_hijo
          AND (c.estado = 'A' OR c.estado IS NULL)
        ORDER BY c.nombre_convenio ASC`,
      [],
      { outFormat: 4002 /* oracledb.OUT_FORMAT_OBJECT */ }
    );

    const convenios = (result.rows || []).map((r: any) => {
      const tipoRaw = (r.TIPO_ASEGURAMIENTO ?? r.tipo_aseguramiento)?.toString().trim().toUpperCase();
      let idTipoAseg: number | null = null;
      let tipoAtenc: string | null = null;

      if (tipoRaw === 'V') {
        idTipoAseg = 1;
        tipoAtenc = 'V';
      } else if (tipoRaw === 'O') {
        idTipoAseg = 2;
        tipoAtenc = 'O';
      }

      return {
        id: Number(r.ID ?? r.id),
        nombre_convenio: String(r.NOMBRE_CONVENIO ?? r.nombre_convenio),
        id_entidad_hijo: r.ID_ENTIDAD_HIJO ?? r.id_entidad_hijo ? Number(r.ID_ENTIDAD_HIJO ?? r.id_entidad_hijo) : null,
        tipo_aseguramiento: tipoRaw || null,
        id_tipo_aseguramiento: idTipoAseg,
        tipo_atencion: tipoAtenc,
      };
    });

    return NextResponse.json({
      codigo: 0,
      mensaje: 'Convenios consultados exitosamente',
      convenios,
    });
  } catch (error: any) {
    console.error('Error en GET /api/convenios:', error);
    return NextResponse.json(
      {
        codigo: -20000,
        mensaje: limpiarMensajeErrorOracle(error.message || 'Error al consultar convenios.'),
        convenios: [],
      },
      { status: 500 }
    );
  } finally {
    if (conn) {
      try {
        await conn.close();
      } catch (e) {
        console.warn('Error al cerrar conexión:', e);
      }
    }
  }
}
