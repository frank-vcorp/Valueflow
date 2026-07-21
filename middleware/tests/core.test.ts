import { describe, expect, it } from 'vitest';
import { maskApiKey, safeError } from '../src/logger/winston';
import { buildLinePlaceholders, normalizedLines } from '../src/db/filter';
import { mapInventoryRecord, mapUnitOfMeasure } from '../src/siemens/inventory';
import { mapSalesRecord, transformSales } from '../src/siemens/sales';
import { validateRuntimeConfig, readRuntimeConfig } from '../src/config/runtime';

describe('seguridad y filtro', () => {
  it('enmascara API keys sin conservar el valor completo', () => {
    expect(maskApiKey('abcdef1234567890')).toBe('abc****890');
    expect(maskApiKey(undefined)).toBe('[NOT SET]');
    expect(maskApiKey('123456')).toBe('****');
  });
  it('normaliza líneas y crea placeholders parametrizados', () => {
    expect(normalizedLines([' simat ', 'SIMAT', 'LP'])).toEqual(['SIMAT', 'LP']);
    expect(buildLinePlaceholders(['SIMAT', 'LP'])).toBe('?,?');
    expect(() => buildLinePlaceholders([])).toThrow();
  });
  it('mantiene errores sin filtrar secretos', () => {
    expect(safeError(new Error('BD no accesible')).message).toBe('BD no accesible');
  });
});

describe('configuración', () => {
  it('lee el ejemplo y rechaza estructura inválida', () => {
    expect(readRuntimeConfig().batch_size).toBe(3000);
    expect(() => validateRuntimeConfig({})).toThrow();
  });
});

describe('transformadores', () => {
  it('mantiene campos mínimos de inventario y unidad por defecto', () => {
    const mapped = mapInventoryRecord({ vendor_item_number: 'SKU', product_description: null, line: 'SIMAT', unit_of_measure: null, quantity_on_hand: 3 });
    expect(mapped).toMatchObject({ vendor_item_number: 'SKU', quantity: 3, quantity_unit_of_measure: 'PZA' });
    expect(Object.keys(mapped)).toEqual(expect.arrayContaining(['distributor_sender_id', 'distributor_inventory_date', 'vendor_item_number', 'quantity', 'quantity_unit_of_measure']));
    expect(mapUnitOfMeasure('pz')).toBe('pz');
  });
  it('omite payload cuando una factura no tiene líneas Siemens', () => {
    expect(transformSales([])).toEqual([]);
  });
  it('calcula costo unitario cero para línea sin cantidad', () => {
    const mapped = mapSalesRecord({ invoice_number: 'F-1', invoice_date: '2026-07-20', line_item: 1, vendor_item_number: 'SKU', product_description: null, quantity: 0, unit_price: 0, extended_cost: 20, branch_id: 1 });
    expect(mapped.unit_cost).toBe(0);
    expect(mapped.distributor_invoice_line_item).toBe('1');
  });
});
