import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    coverage: {
      provider: 'v8',
      include: [
        'src/config/runtime.ts',
        'src/db/filter.ts',
        'src/logger/winston.ts',
        'src/siemens/inventory.ts',
        'src/siemens/sales.ts'
      ],
      thresholds: { lines: 70, functions: 70, statements: 70, branches: 60 }
    }
  }
});
