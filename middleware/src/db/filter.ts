export const SIEMENS_LINE_CODES = [
  'BAJA', 'SINU', 'SIMAT', 'LP', 'DRIVE', 'MOTOR', 'SINUM', 'SERVI', 'OBSO',
  'SENSO', 'SERVO', 'INSTR', 'UPS', 'SIMA', 'ESPE'
] as const;

export function normalizedLines(lines: readonly string[]): string[] {
  return [...new Set(lines.map((line) => line.trim().toUpperCase()).filter(Boolean))];
}

export function buildLinePlaceholders(lines: readonly string[]): string {
  if (lines.length === 0) throw new Error('El filtro de líneas Siemens no puede estar vacío');
  return lines.map(() => '?').join(',');
}
