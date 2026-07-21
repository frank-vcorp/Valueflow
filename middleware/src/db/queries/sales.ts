import { pool } from '../firebird';
import { readRuntimeConfig } from '../../config/runtime';
import { buildLinePlaceholders } from '../filter';

export interface SalesRecord {
  invoice_number: string;
  invoice_date: Date | string;
  line_item: number;
  vendor_item_number: string;
  product_description: string | null;
  quantity: number;
  unit_price: number;
  extended_cost: number;
  branch_id: number;
}

export async function fetchSalesByDate(date: Date): Promise<SalesRecord[]> {
  const config = readRuntimeConfig();
  const lines = config.siemens_line_filter.lines;
  const placeholders = buildLinePlaceholders(lines);
  const dateStr = date.toISOString().slice(0, 10);
  const sql = `
    SELECT TRIM(f.CVE_DOC), f.FECHA_DOC, d.NUM_PAR, TRIM(d.CVE_ART), i.DESCR,
           d.CANT, d.PREC, d.IMPU1, COALESCE(d.NUM_ALM, f.NUM_ALMA, 1)
    FROM FACTF01 f
    INNER JOIN PAR_FACTF01 d ON d.CVE_DOC = f.CVE_DOC
    INNER JOIN INVE01 i ON i.CVE_ART = d.CVE_ART
    WHERE f.FECHA_DOC = ? AND f.STATUS <> 'C'
      AND TRIM(i.LIN_PROD) IN (${placeholders})
    ORDER BY f.CVE_DOC, d.NUM_PAR`;
  const rows = await pool.query<unknown[]>(sql, [dateStr, ...lines]);
  return rows.map((row) => ({
    invoice_number: String(row[0] ?? '').trim(), invoice_date: row[1] as Date | string,
    line_item: Number(row[2] ?? 0), vendor_item_number: String(row[3] ?? '').trim(),
    product_description: row[4] == null ? null : String(row[4]), quantity: Number(row[5] ?? 0),
    unit_price: Number(row[6] ?? 0), extended_cost: Number(row[7] ?? 0), branch_id: Number(row[8] ?? 1)
  }));
}
