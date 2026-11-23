require('dotenv').config();
const mysql = require('mysql2/promise');

module.exports = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  port: Number(process.env.DB_PORT || 3306),
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'psytech_pro',
  waitForConnections: true,
  connectionLimit: 10,
  charset: 'utf8mb4',
  // TiDB Cloud (et la plupart des MySQL en ligne) exigent TLS : DB_SSL=true
  ssl: process.env.DB_SSL === 'true' ? { minVersion: 'TLSv1.2', rejectUnauthorized: true } : undefined,
});
