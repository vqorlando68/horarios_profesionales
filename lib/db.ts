import oracledb from 'oracledb';

// Configurar modo THIN por defecto (pure JavaScript, sin Oracle Instant Client)
// Esencial para funcionar nativamente en Vercel Serverless Functions
try {
  // En oracledb v6+, thin mode es el modo por defecto si no se llama initOracleClient()
  oracledb.autoCommit = true;
  oracledb.fetchAsString = [oracledb.CLOB];
} catch (err) {
  console.warn('Configuración de oracledb:', err);
}

export interface OracleConfig {
  user: string;
  password: string;
  connectString: string;
}

export function getOracleConfig(): OracleConfig {
  const user = process.env.ORACLE_DB_USER || 'TEKER_DEV';
  let password = process.env.ORACLE_DB_PASSWORD || 'T3k3r_2025_D3v_$ecur3';

  // Proteger contra truncamiento de dotenv ($ecur3 tratado como variable)
  if (password === 'T3k3r_2025_D3v_' || !password.includes('$ecur3')) {
    password = 'T3k3r_2025_D3v_$ecur3';
  }
  if (password.includes('\\$')) {
    password = password.replace('\\$', '$');
  }

  const connectString = process.env.ORACLE_DB_CONNECTION_STRING || 'tekerapp-db.maxapex.net:1521/orclpdb1';

  return { user, password, connectString };
}

/**
 * Obtiene una conexión a Oracle Database
 */
export async function getDbConnection(): Promise<any> {
  const config = getOracleConfig();
  return await oracledb.getConnection(config);
}

/**
 * Helper para leer un CLOB (String o Lob) a string plano
 */
async function clobToString(clob: any): Promise<string> {
  if (!clob) return '';
  if (typeof clob === 'string') return clob;
  if (typeof clob.getData === 'function') {
    return await clob.getData();
  }
  return String(clob);
}

/**
 * Limpia y humaniza mensajes de error emitidos por Oracle
 * Elimina:
 *   - ORA-XXXXX: (códigos de error de base de datos)
 *   - ORA-06512: at ... (trazas de pila internas de ejecución)
 *   - Enlaces de ayuda Help: https://...
 */
export function limpiarMensajeErrorOracle(mensaje: string | null | undefined): string {
  if (!mensaje) return 'Error inesperado al procesar la operación.';

  let limpio = String(mensaje);

  // 1. Quitar enlaces de ayuda introducidos por Oracle 23c
  limpio = limpio.replace(/Help:\s*https?:\/\/\S+/gi, '');

  // 2. Quitar la traza ORA-06512: at "<owner>.<pkg>", line <N> y ORA-06512: at line <N>
  limpio = limpio.replace(/ORA-06512:\s*at\s+["'\w\s.]+,?\s*line\s+\d+/gi, '');
  limpio = limpio.replace(/ORA-06512:\s*at\s+line\s+\d+/gi, '');
  limpio = limpio.replace(/ORA-06512:\s*at\s+[^\n]+/gi, '');

  // 3. Quitar códigos de aplicación y de Oracle (ORA-20008, ORA-20000, etc.)
  limpio = limpio.replace(/ORA-\d{5}:\s*/gi, '');

  // 4. Limpiar saltos de línea y dobles espacios
  limpio = limpio.replace(/\s+/g, ' ').trim();

  // 5. Si quedó vacío, devolver un mensaje por defecto
  return limpio || 'Ocurrió un error al procesar la solicitud en el servidor.';
}

/**
 * Ejecuta un procedimiento del estándar PKGLN_ con contrato (p_json_entrada, p_json_salida)
 */
export async function executePlsqlContract(

  packageName: string,
  methodName: string,
  payloadEntrada: object | string
): Promise<any> {
  let connection: any = null;
  const jsonEntradaString =
    typeof payloadEntrada === 'string'
      ? payloadEntrada
      : JSON.stringify(payloadEntrada);

  try {
    connection = await getDbConnection();

    const plsql = `
      BEGIN
        ${packageName}.${methodName}(
          p_json_entrada => :p_json_entrada,
          p_json_salida  => :p_json_salida
        );
      END;
    `;

    const binds: any = {
      p_json_entrada: {
        val: jsonEntradaString,
        type: oracledb.CLOB,
        dir: oracledb.BIND_IN,
      },
      p_json_salida: {
        type: oracledb.CLOB,
        dir: oracledb.BIND_OUT,
      },
    };

    const result = await connection.execute(plsql, binds, {
      autoCommit: true,
    });

    const outClob = result.outBinds?.p_json_salida;
    const salidaString = await clobToString(outClob);

    if (!salidaString || salidaString.trim() === '') {
      return { codigo: 0, mensaje: 'Operación ejecutada sin respuesta de salida' };
    }

    try {
      return JSON.parse(salidaString);
    } catch {
      return { codigo: 0, raw: salidaString };
    }
  } catch (error: any) {
    console.error(`Error en llamada PL/SQL ${packageName}.${methodName}:`, error);
    throw error;
  } finally {
    if (connection) {
      try {
        await connection.close();
      } catch (closeErr) {
        console.error('Error cerrando conexión a Oracle:', closeErr);
      }
    }
  }
}
