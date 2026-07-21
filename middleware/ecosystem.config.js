module.exports = {
  apps: [{
    name: 'siemens-middleware',
    script: 'dist/index.js',
    cwd: 'C:/apps/siemens-middleware',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '512M',
    env: { NODE_ENV: 'production' }
  }]
};
