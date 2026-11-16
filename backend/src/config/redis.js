const os = require('os');
const Redis = require('ioredis');

/**
 * Redis connection manager.
 *
 * Redis is the shared layer that lets multiple backend instances behave as one:
 *   - `client` → shared cache + distributed locks (cron)
 *   - `pub` / `sub` → Socket.io Redis adapter (cross-instance event fan-out)
 *
 * If REDIS_URL is not set, or Redis can't be reached at boot, the server runs in
 * SINGLE-INSTANCE MODE (in-memory cache + in-memory socket adapter), exactly like
 * before Redis was introduced. Redis is therefore never a hard dependency.
 */

// Unique id for this process. Render sets RENDER_INSTANCE_ID per instance.
const instanceId =
  process.env.RENDER_INSTANCE_ID || `${os.hostname()}-${process.pid}`;

let client = null;
let pub = null;
let sub = null;
let enabled = false;

const attachLogging = (conn, name) => {
  conn.on('error', (err) => console.error(`❌ Redis [${name}] error:`, err.message));
  conn.on('reconnecting', () => console.warn(`🔄 Redis [${name}] reconnecting...`));
  conn.on('ready', () => console.log(`✅ Redis [${name}] ready`));
};

const init = async () => {
  const url = process.env.REDIS_URL;

  if (!url) {
    console.warn('⚠️ REDIS_URL not set → running in single-instance mode (in-memory cache & sockets).');
    return false;
  }

  try {
    // Command client: fail fast when Redis is down so the cache can fall back to memory
    client = new Redis(url, {
      lazyConnect: true,
      connectTimeout: 5000,
      maxRetriesPerRequest: 1,
      enableOfflineQueue: false,
    });
    attachLogging(client, 'cache');
    await client.connect();

    // Pub/Sub clients for the Socket.io adapter (default retry behaviour: keep reconnecting)
    pub = new Redis(url, { lazyConnect: true, connectTimeout: 5000 });
    sub = pub.duplicate();
    attachLogging(pub, 'pub');
    attachLogging(sub, 'sub');
    await Promise.all([pub.connect(), sub.connect()]);

    enabled = true;
    console.log(`✅ Redis connected (instance: ${instanceId})`);
    return true;
  } catch (err) {
    console.error('❌ Redis connection failed → falling back to single-instance mode:', err.message);
    await close();
    return false;
  }
};

const close = async () => {
  enabled = false;
  await Promise.allSettled(
    [client, pub, sub].filter(Boolean).map((c) => c.quit().catch(() => c.disconnect()))
  );
  client = pub = sub = null;
};

module.exports = {
  init,
  close,
  instanceId,
  getClient: () => client,
  getPubSub: () => ({ pub, sub }),
  // True only when Redis was configured AND the command connection is currently live
  isReady: () => enabled && client !== null && client.status === 'ready',
  // For /health: 'disabled' (no Redis configured / failed at boot), 'up', or 'down'
  status: () => {
    if (!enabled) return 'disabled';
    return client && client.status === 'ready' ? 'up' : 'down';
  },
};
