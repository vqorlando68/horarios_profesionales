import { NextResponse } from 'next/server';
import { getDbConnection, limpiarMensajeErrorOracle } from '@/lib/db';

export const dynamic = 'force-dynamic';

export async function GET() {
  let conn;
  try {
    conn = await getDbConnection();
    const result = await conn.execute(
      `SELECT TO_CHAR(fecha_festivo, 'YYYY-MM-DD') AS fecha,
              nombre_festivo AS nombre
         FROM tkr_festivos
        WHERE id_pais = 1
        ORDER BY fecha_festivo ASC`,
      [],
      { outFormat: 4002 /* oracledb.OUT_FORMAT_OBJECT */ }
    );

    const festivos = (result.rows || []).map((r: any) => ({
      fecha: r.FECHA || r.fecha,
      nombre: r.NOMBRE || r.nombre,
    }));

    return NextResponse.json({
      codigo: 0,
      mensaje: 'Festivos consultados exitosamente',
      festivos,
    });
  } catch (error: any) {
    console.error('Error en GET /api/festivos:', error);
    return NextResponse.json(
      {
        codigo: -20000,
        mensaje: limpiarMensajeErrorOracle(error.message || 'Error al consultar festivos en Oracle.'),
        festivos: [],
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
