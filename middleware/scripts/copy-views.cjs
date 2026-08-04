const fs = require('node:fs');
const path = require('node:path');

// Copiar vistas HTML estáticas
const viewsSource = path.resolve('src/ui/views');
const viewsDest = path.resolve('dist/ui/views');
fs.cpSync(viewsSource, viewsDest, { recursive: true });

// Copiar manual HTML generado + screenshots a dist/docs/
const docsHtmlSource = path.resolve('docs/MANUAL_USUARIO.html');
const docsDestDir = path.resolve('dist/docs');
const docsHtmlDest = path.resolve('dist/docs/MANUAL_USUARIO.html');

if (fs.existsSync(docsHtmlSource)) {
  fs.mkdirSync(docsDestDir, { recursive: true });
  fs.cpSync(docsHtmlSource, docsHtmlDest);
  console.log(`[copy-views] Copied ${docsHtmlSource} → ${docsHtmlDest}`);
} else {
  console.warn('[copy-views] Manual HTML no encontrado. Ejecute "npm run build:docs" antes de "npm run build".');
}

// Copiar screenshots al dist (rutas relativas del manual: ../docs/screenshots/*.png
// resuelven desde dist/docs/MANUAL_USUARIO.html → dist/docs/screenshots/*.png)
const screenshotsSource = path.resolve('docs/screenshots');
const screenshotsDest = path.resolve('dist/docs/screenshots');
if (fs.existsSync(screenshotsSource)) {
  fs.mkdirSync(screenshotsDest, { recursive: true });
  fs.cpSync(screenshotsSource, screenshotsDest, { recursive: true });
  console.log(`[copy-views] Copied ${screenshotsSource} → ${screenshotsDest}`);
}