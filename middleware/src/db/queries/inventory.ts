import { pool } from '../firebird';
import { readRuntimeConfig } from '../../config/runtime';
import { buildLinePlaceholders } from '../filter';

export interface InventoryRecord {
  vendor_item_number: string;
  product_description: string | null;
  line: string;
  unit_of_measure: string | null;
  quantity_on_hand: number;
}

export async function fetchInventorySnapshot(): Promise<InventoryRecord[]> {
  const config = readRuntimeConfig();
  const lines = config.siemens_line_filter.lines;
  const placeholders = buildLinePlaceholders(lines);
  const sql = `
    SELECT TRIM(CVE_ART), TRIM(DESCR), TRIM(LIN_PROD), TRIM(UNI_MED), EXIST
    FROM INVE01
    WHERE TRIM(LIN_PROD) IN (${placeholders})
      ${config.siemens_line_filter.include_inactive_products ? '' : "AND STATUS = 'A'"}
      AND EXIST IS NOT NULL
    ORDER BY CVE_ART`;
  const rows = await pool.query<unknown[]>(sql, lines);
  return rows.map((row) => ({
    vendor_item_number: String(row[0] ?? '').trim(),
    product_description: row[1] == null ? null : String(row[1]),
    line: String(row[2] ?? '').trim(),
    unit_of_measure: row[3] == null ? null : String(row[3]).trim(),
    quantity_on_hand: Number(row[4] ?? 0)
  }));
}
