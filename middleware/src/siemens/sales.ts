import { readRuntimeConfig } from '../config/runtime';
import type { SalesRecord } from '../db/queries/sales';

export interface SiemensSalesRecord {
  distributor_sender_id: string;
  distributor_invoice_number: string;
  distributor_invoice_line_item: string;
  distributor_invoice_date: string;
  distributor_order_taking_branch_id: string;
  vendor_item_number: string;
  quantity: number;
  unit_cost: number;
  extended_cost_of_goods_sold: number;
  currency_code: 'MXN';
  [key: string]: string | number | null;
}

function isoDate(value: Date | string): string {
  return (value instanceof Date ? value : new Date(value)).toISOString().slice(0, 10);
}

export function mapSalesRecord(record: SalesRecord): SiemensSalesRecord {
  const config = readRuntimeConfig();
  const result: SiemensSalesRecord = {
    distributor_sender_id: config.siemens.distributor_sender_id,
    distributor_invoice_number: record.invoice_number,
    distributor_invoice_line_item: String(record.line_item),
    distributor_invoice_date: isoDate(record.invoice_date),
    distributor_order_taking_branch_id: String(record.branch_id),
    vendor_item_number: record.vendor_item_number,
    quantity: record.quantity,
    // B7 (IMPL-20260806-07) — ISSUE PENDIENTE DE NEGOCIO, NO TOCAR SIN OK DE DATA STEWARD:
    // El campo `unit_cost` y `extended_cost_of_goods_sold` se computan actualmente
    // como `IMPU1 / CANT` e `IMPU1`. IMPU1 es el IVA (impuesto) y NO el costo.
    // Según MAPEO_CAMPO_A_CAMPO y PoSi Siemens, estos campos esperan `CANT × COST`.
    // Decisión pendiente: ¿es IMPU1 el campo equivocado en el SELECT de queries/sales.ts
    // (debería ser COST), o el cálculo de unit_cost/extended_cost_of_goods_sold aquí
    // es el equivocado (debería seguir el patrón del inventario: usar campo dedicado)?
    // ACCIÓN EXTERNA REQUERIDA: confirmar con Data Steward de Siemens antes de corregir.
    unit_cost: record.quantity === 0 ? 0 : record.extended_cost / record.quantity,
    extended_cost_of_goods_sold: record.extended_cost,
    currency_code: 'MXN'
  };
  const optional = config.optional_fields.sales;
  if (optional.product_description && record.product_description) result.product_description = record.product_description;
  return result;
}

export function transformSales(records: SalesRecord[]): SiemensSalesRecord[] {
  return records.filter((record) => record.invoice_number && record.vendor_item_number && Number.isFinite(record.quantity)).map(mapSalesRecord);
}
