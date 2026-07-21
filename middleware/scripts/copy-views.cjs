const fs = require('node:fs');
const path = require('node:path');
const source = path.resolve('src/ui/views');
const destination = path.resolve('dist/ui/views');
fs.cpSync(source, destination, { recursive: true });
