const js = require('@eslint/js');
const tseslint = require('typescript-eslint');

const globals = require('globals');

module.exports = tseslint.config(
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    ignores: ['dist/**', 'coverage/**', 'node_modules/**', 'ecosystem.config.js'],
    languageOptions: { globals: globals.node, parserOptions: { project: './tsconfig.json', tsconfigRootDir: __dirname } },
    rules: {
      '@typescript-eslint/no-explicit-any': 'error',
      '@typescript-eslint/no-floating-promises': 'error'
    }
  }
);
