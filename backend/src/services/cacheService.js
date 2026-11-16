const redis = require('../config/redis');

/**
 * Shared read cache.
 *
 * - Redis available  → stored in Redis, shared by every backend instance, so an
 *                       invalidation on server A is seen by server B immediately.
 * - Redis unavailable → per-process in-memory Map (the original behaviour).
 *
 * All keys are namespaced under PREFIX so clearAll() never touches other Redis data.
 */

const PREFIX = 'automate:cache:';

// In-memory fallback (single-instance mode or Redis temporarily down)
const memory = new Map();

const memoryGet = (key) => {
  const entry = memory.get(key);
  if (!entry) return null;
  if (Date.now() > entry.expiry) {
    memory.delete(key);
    return null;
  }
  return entry.value;
};

const cacheService = {
  async get(key) {
    if (redis.isReady()) {
      try {
        const raw = await redis.getClient().get(PREFIX + key);
        return raw ? JSON.parse(raw) : null;
      } catch (err) {
        console.error('Cache get error (falling back to memory):', err.message);
      }
    }
    return memoryGet(key);
  },

  async set(key, value, ttlMs = 10000) {
    if (redis.isReady()) {
      try {
        await redis.getClient().set(PREFIX + key, JSON.stringify(value), 'PX', ttlMs);
        return;
      } catch (err) {
        console.error('Cache set error (falling back to memory):', err.message);
      }
    }
    memory.set(key, { value, expiry: Date.now() + ttlMs });
  },

  // Invalidate every cached entry (across ALL instances when Redis is on)
  async clearAll() {
    memory.clear();
    if (!redis.isReady()) return;

    try {
      const client = redis.getClient();
      const stream = client.scanStream({ match: `${PREFIX}*`, count: 200 });
      const deletions = [];

      for await (const keys of stream) {
        if (keys.length > 0) deletions.push(client.unlink(...keys));
      }
      await Promise.all(deletions);
    } catch (err) {
      console.error('Cache clear error:', err.message);
    }
  },
};

module.exports = cacheService;
