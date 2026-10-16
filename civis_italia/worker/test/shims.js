// Sostituti locali di D1 e R2 per provare l'API senza Cloudflare.
// D1 -> SQLite di Node (node:sqlite). R2 -> mappa in memoria.
import { DatabaseSync } from 'node:sqlite';
import { readFileSync } from 'node:fs';

export function makeD1() {
  const db = new DatabaseSync(':memory:');
  db.exec('PRAGMA foreign_keys = ON');
  db.exec(readFileSync(new URL('../schema.sql', import.meta.url), 'utf8'));
  const norm = (args) => args.map((a) => (a === undefined ? null : a));
  const stmt = (sql, args = []) => ({
    bind: (...a) => stmt(sql, norm(a)),
    first: async () => db.prepare(sql).get(...args) ?? null,
    all: async () => ({ results: db.prepare(sql).all(...args) }),
    run: async () => {
      const r = db.prepare(sql).run(...args);
      return { success: true, meta: { changes: Number(r.changes) } };
    },
    _run: () => db.prepare(sql).run(...args),
  });
  return {
    raw: db,
    prepare: (sql) => stmt(sql),
    batch: async (stmts) => {
      db.exec('BEGIN');
      try {
        for (const s of stmts) s._run();
        db.exec('COMMIT');
      } catch (e) {
        db.exec('ROLLBACK');
        throw e;
      }
      return stmts.map(() => ({ success: true }));
    },
  };
}

export function makeR2() {
  const store = new Map();
  return {
    store,
    put: async (key, data, opts = {}) => {
      store.set(key, { data: Buffer.from(data), httpMetadata: opts.httpMetadata || {} });
    },
    get: async (key) => {
      const o = store.get(key);
      if (!o) return null;
      return {
        httpMetadata: o.httpMetadata,
        body: new Blob([o.data]).stream(),
        arrayBuffer: async () => o.data.buffer.slice(o.data.byteOffset, o.data.byteOffset + o.data.byteLength),
      };
    },
    delete: async (keys) => {
      for (const k of Array.isArray(keys) ? keys : [keys]) store.delete(k);
    },
  };
}
