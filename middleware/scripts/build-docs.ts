import { marked } from 'marked';
import * as fs from 'node:fs';
import * as path from 'node:path';

const SOURCE = path.resolve('docs/MANUAL_USUARIO.md');
const OUTPUT = path.resolve('docs/MANUAL_USUARIO.html');

const md = fs.readFileSync(SOURCE, 'utf-8');
const html = marked.parse(md, { gfm: true }) as string;

// Envolver en HTML completo con estilos embebidos
const styled = `<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Manual de Usuario — Middleware Repaga × Siemens PoSi</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
      max-width: 900px;
      margin: 40px auto;
      padding: 0 20px 40px;
      line-height: 1.65;
      color: #1f2937;
      background: #ffffff;
    }
    h1 {
      color: #009999;
      border-bottom: 3px solid #009999;
      padding-bottom: 10px;
      margin-bottom: 24px;
      font-size: 2em;
    }
    h2 {
      color: #009999;
      margin-top: 36px;
      border-left: 5px solid #009999;
      padding-left: 14px;
      font-size: 1.5em;
    }
    h3 {
      color: #374151;
      margin-top: 26px;
      font-size: 1.2em;
    }
    h4 {
      color: #4b5563;
      margin-top: 20px;
      font-size: 1.05em;
    }
    img {
      max-width: 100%;
      height: auto;
      border: 1px solid #e5e7eb;
      border-radius: 8px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.08);
      display: block;
      margin: 24px auto;
    }
    code {
      background: #f3f4f6;
      padding: 2px 7px;
      border-radius: 4px;
      font-family: 'Courier New', Menlo, monospace;
      font-size: 0.92em;
      color: #be185d;
    }
    pre {
      background: #1f2937;
      color: #f9fafb;
      padding: 16px;
      border-radius: 8px;
      overflow-x: auto;
      line-height: 1.5;
    }
    pre code {
      background: transparent;
      color: inherit;
      padding: 0;
    }
    table {
      border-collapse: collapse;
      width: 100%;
      margin: 18px 0;
      font-size: 0.95em;
    }
    th, td {
      border: 1px solid #d1d5db;
      padding: 9px 13px;
      text-align: left;
    }
    th {
      background: #f3f4f6;
      font-weight: 600;
    }
    blockquote {
      border-left: 4px solid #009999;
      margin: 18px 0;
      padding: 6px 18px;
      color: #4b5563;
      background: #f0fdfa;
      border-radius: 0 6px 6px 0;
    }
    a {
      color: #009999;
      text-decoration: none;
      font-weight: 500;
    }
    a:hover {
      text-decoration: underline;
    }
    hr {
      border: none;
      border-top: 1px solid #e5e7eb;
      margin: 32px 0;
    }
    ul, ol {
      padding-left: 24px;
    }
    li {
      margin: 4px 0;
    }
    p {
      margin: 12px 0;
    }
    strong {
      color: #111827;
    }
    @media (max-width: 720px) {
      body { margin: 20px auto; padding: 0 14px 30px; }
      h1 { font-size: 1.6em; }
      h2 { font-size: 1.25em; }
    }
  </style>
</head>
<body>
${html}
</body>
</html>`;

fs.writeFileSync(OUTPUT, styled, 'utf-8');
console.log(`[build-docs] Generated ${OUTPUT} (${styled.length} bytes)`);