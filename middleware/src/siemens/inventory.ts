import { readRuntimeConfig } from '../config/runtime';
import type { InventoryRecord } from '../db/queries/inventory';

export interface SiemensInventoryRecord {
  distributor_sender_id: string;
  distributor_inventory_date: string;
  vendor_item_number: string;
  quantity: number;
  quantity_unit_of_measure: string;
  [key: string]: string | number | null;
}

function today(): string { return new Date().toISOString().slice(0, 10); }
export function mapUnitOfMeasure(unit: string | null): string { return unit?.trim() || 'PZA'; }

export function mapInventoryRecord(record: InventoryRecord): SiemensInventoryRecord {
  const config = readRuntimeConfig();
  const result: SiemensInventoryRecord = {
    distributor_sender_id: config.siemens.distributor_sender_id,
    distributor_inventory_date: today(),
    vendor_item_number: record.vendor_item_number,
    quantity: record.quantity_on_hand,
    quantity_unit_of_measure: mapUnitOfMeasure(record.unit_of_measure)
  };
  const optional = config.optional_fields.inventory;
  if (optional.product_description && record.product_description) result.product_description = record.product_description;
  if (optional.vendor_item_options && record.vendor_item_number) result.vendor_item_options = '';
  if (optional.stock_item) result.stock_item = 'Y';
  if (optional.abc_segmentation) result.abc_segmentation = 'A';
  return result;
}

export function transformInventory(records: InventoryRecord[]): SiemensInventoryRecord[] {
  return records.filter((record) => record.vendor_item_number.length > 0 && Number.isFinite(record.quantity_on_hand)).map(mapInventoryRecord);
}
