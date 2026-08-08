// B7: cwd dinamico via __dirname para que funcione sin importar donde se instale.
// F1 fix (IMPL-20260807-03): se elimino wait_ready. El middleware NUNCA emite
// process.send('ready') tras app.listen(), por lo que PM2 OSS quedaba en
// deadlock esperando la senal (puerto 4567 nunca bindeaba). Con wait_ready=false
// PM2 marca 'online' cuando el proceso arranca y deja que Express haga su
// bind() normal. listen_timeout se mantiene por documentacion (PM2 lo ignora
// sin wait_ready, pero es inofensivo y refleja el tiempo maximo esperado de
// inicializacion del proceso antes del primer evento de PM2).
module.exports = {
  apps: [{
    name: 'siemens-middleware',
    script: 'dist/index.js',
    cwd: __dirname,
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '512M',
    listen_timeout: 5000,
    env: { NODE_ENV: 'production' }
  }]
};
