// API di Civis su Cloudflare Workers: login, documenti, scadenze, analisi AI.
// Database e foto delle pagine: D1 (binding DB). Segreti: JWT_SECRET, ANTHROPIC_API_KEY.

import { hashPassword, signToken, verifyPassword, verifyToken } from './auth.js';
import {
  AiError,
  analysisSystemPrompt,
  callClaude,
  chatSystemPrompt,
  draftSystemPrompt,
  extractJson,
  isRealDate,
  normalizeAnalysis,
  toBase64,
} from './ai.js';

const MAX_PAGE_BYTES = 1200 * 1024; // D1 accetta righe fino a 2 MB: la foto è salvata in base64 (+33%)
const MAX_PAGES = 12;
const PAGE_TYPES = ['image/jpeg', 'image/png'];

class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

const CORS = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization, content-type',
  'access-control-allow-methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
  'access-control-max-age': '86400',
};

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store', ...CORS },
  });
}

const nowIso = () => new Date().toISOString();
const today = () => new Date().toISOString().slice(0, 10);
const thisMonth = () => new Date().toISOString().slice(0, 7);

async function body(request) {
  try {
    const data = await request.json();
    if (data && typeof data === 'object') return data;
  } catch {
    /* corpo non valido */
  }
  throw new HttpError(400, 'Richiesta non valida.');
}

function cleanText(v, max, field) {
  if (typeof v !== 'string' || !v.trim()) throw new HttpError(400, `Manca ${field}.`);
  return v.trim().slice(0, max);
}

// ---------- accesso ----------

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

function publicUser(u) {
  return { id: u.id, email: u.email, name: u.name };
}

async function register(request, env) {
  const b = await body(request);
  const email = String(b.email || '').trim().toLowerCase();
  const password = String(b.password || '');
  const name = String(b.name || '').trim().slice(0, 80);
  if (!EMAIL_RE.test(email) || email.length > 200) throw new HttpError(400, 'Indirizzo email non valido.');
  if (password.length < 8 || password.length > 200) {
    throw new HttpError(400, 'La password deve avere almeno 8 caratteri.');
  }
  const exists = await env.DB.prepare('SELECT id FROM users WHERE email = ?').bind(email).first();
  if (exists) throw new HttpError(409, 'Esiste già un account con questa email.');
  const user = { id: crypto.randomUUID(), email, name };
  await env.DB.prepare('INSERT INTO users (id, email, name, pass_hash, created_at) VALUES (?, ?, ?, ?, ?)')
    .bind(user.id, email, name, await hashPassword(password), nowIso())
    .run();
  const token = await signToken({ sub: user.id }, env.JWT_SECRET);
  return json({ token, user: publicUser(user) }, 201);
}

async function login(request, env) {
  const b = await body(request);
  const email = String(b.email || '').trim().toLowerCase();
  const password = String(b.password || '');
  const since = Date.now() - 15 * 60 * 1000;
  const recent = await env.DB.prepare('SELECT COUNT(*) AS n FROM login_attempts WHERE email = ? AND ts > ?')
    .bind(email, since)
    .first();
  if ((recent?.n || 0) >= 10) throw new HttpError(429, 'Troppi tentativi. Riprova tra 15 minuti.');
  const user = await env.DB.prepare('SELECT * FROM users WHERE email = ?').bind(email).first();
  // Si verifica sempre una password, anche se l'utente non esiste, per non rivelare quali email sono registrate.
  const ok = user
    ? await verifyPassword(password, user.pass_hash)
    : (await verifyPassword(password, 'pbkdf2$100000$AAAAAAAAAAAAAAAAAAAAAA$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'), false);
  if (!ok) {
    await env.DB.prepare('INSERT INTO login_attempts (email, ts) VALUES (?, ?)').bind(email, Date.now()).run();
    throw new HttpError(401, 'Email o password non corrette.');
  }
  await env.DB.prepare('DELETE FROM login_attempts WHERE email = ?').bind(email).run();
  const token = await signToken({ sub: user.id }, env.JWT_SECRET);
  return json({ token, user: publicUser(user) });
}

async function authenticate(request, env) {
  const header = request.headers.get('authorization') || '';
  const m = /^Bearer (.+)$/.exec(header);
  const payload = m ? await verifyToken(m[1], env.JWT_SECRET) : null;
  if (!payload?.sub) throw new HttpError(401, 'Accesso scaduto. Accedi di nuovo.');
  const user = await env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(payload.sub).first();
  if (!user) throw new HttpError(401, 'Accesso scaduto. Accedi di nuovo.');
  return user;
}

// ---------- documenti ----------


function docView(d) {
  return {
    id: d.id,
    title: d.title,
    pages: d.pages,
    status: d.status,
    createdAt: d.created_at,
    analyzedAt: d.analyzed_at,
    analysis: d.analysis ? JSON.parse(d.analysis) : null,
  };
}

async function ownDoc(env, user, id) {
  const d = await env.DB.prepare('SELECT * FROM documents WHERE id = ? AND user_id = ?').bind(id, user.id).first();
  if (!d) throw new HttpError(404, 'Documento non trovato.');
  return d;
}

async function deleteDocFiles(env, user, doc) {
  await env.DB.prepare('DELETE FROM pages WHERE doc_id = ? AND user_id = ?').bind(doc.id, user.id).run();
}

async function createDocument(request, env, user) {
  const b = await body(request);
  const title = cleanText(b.title, 120, 'il titolo');
  const pages = Number(b.pages);
  if (!Number.isInteger(pages) || pages < 1 || pages > MAX_PAGES) {
    throw new HttpError(400, `Il documento può avere da 1 a ${MAX_PAGES} pagine.`);
  }
  const id = crypto.randomUUID();
  await env.DB.prepare('INSERT INTO documents (id, user_id, title, pages, status, created_at) VALUES (?, ?, ?, ?, ?, ?)')
    .bind(id, user.id, title, pages, 'draft', nowIso())
    .run();
  return json(docView(await ownDoc(env, user, id)), 201);
}

async function uploadPage(request, env, user, id, n) {
  const doc = await ownDoc(env, user, id);
  if (!Number.isInteger(n) || n < 1 || n > doc.pages) throw new HttpError(400, 'Numero di pagina non valido.');
  const type = (request.headers.get('content-type') || '').split(';')[0].trim().toLowerCase();
  if (!PAGE_TYPES.includes(type)) throw new HttpError(415, 'Sono accettate solo immagini JPEG o PNG.');
  const declared = Number(request.headers.get('content-length') || 0);
  if (declared > MAX_PAGE_BYTES) throw new HttpError(413, 'La foto è troppo grande (massimo 1,2 MB: l’app la riduce da sola).');
  const data = await request.arrayBuffer();
  if (data.byteLength === 0) throw new HttpError(400, 'File vuoto.');
  if (data.byteLength > MAX_PAGE_BYTES) throw new HttpError(413, 'La foto è troppo grande (massimo 1,2 MB: l’app la riduce da sola).');
  await env.DB.prepare(
    'INSERT INTO pages (doc_id, n, user_id, type, data) VALUES (?, ?, ?, ?, ?) ON CONFLICT(doc_id, n) DO UPDATE SET type = excluded.type, data = excluded.data',
  )
    .bind(id, n, user.id, type, toBase64(data))
    .run();
  return json({ ok: true, page: n });
}

async function getPage(env, user, id, n) {
  const doc = await ownDoc(env, user, id);
  if (!Number.isInteger(n) || n < 1 || n > doc.pages) throw new HttpError(404, 'Pagina non trovata.');
  const row = await env.DB.prepare('SELECT type, data FROM pages WHERE doc_id = ? AND n = ? AND user_id = ?')
    .bind(id, n, user.id)
    .first();
  if (!row) throw new HttpError(404, 'Pagina non trovata.');
  const bin = atob(row.data);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return new Response(bytes, {
    headers: {
      'content-type': row.type || 'image/jpeg',
      'cache-control': 'private, max-age=3600',
      ...CORS,
    },
  });
}

async function analyzeDocument(env, user, id) {
  const doc = await ownDoc(env, user, id);

  const usage = await env.DB.prepare('SELECT docs FROM usage WHERE user_id = ? AND month = ?')
    .bind(user.id, thisMonth())
    .first();
  const limit = Number(env.FREE_DOCS_PER_MONTH || 30);
  if ((usage?.docs || 0) >= limit) {
    throw new HttpError(402, `Hai raggiunto il limite di ${limit} documenti analizzati questo mese.`);
  }

  const rows = (
    await env.DB.prepare('SELECT n, type, data FROM pages WHERE doc_id = ? AND user_id = ? ORDER BY n')
      .bind(id, user.id)
      .all()
  ).results;
  const content = [];
  for (let n = 1; n <= doc.pages; n++) {
    const row = rows.find((r) => r.n === n);
    if (!row) throw new HttpError(409, `Manca la pagina ${n}. Ricarica il documento.`);
    content.push({ type: 'image', source: { type: 'base64', media_type: row.type || 'image/jpeg', data: row.data } });
  }
  content.push({
    type: 'text',
    text: `Questo documento ha ${doc.pages} ${doc.pages === 1 ? 'pagina' : 'pagine'}. Analizzalo e rispondi con il JSON richiesto.`,
  });

  let analysis;
  try {
    const text = await callClaude(env, {
      system: analysisSystemPrompt(today()),
      messages: [{ role: 'user', content }],
      maxTokens: 3000,
    });
    analysis = normalizeAnalysis(extractJson(text));
  } catch (e) {
    await env.DB.prepare("UPDATE documents SET status = 'failed' WHERE id = ?").bind(id).run();
    throw e;
  }

  const stmts = [
    env.DB.prepare('UPDATE documents SET status = ?, analysis = ?, analyzed_at = ? WHERE id = ?').bind(
      analysis.leggibile ? 'analyzed' : 'failed',
      JSON.stringify(analysis),
      nowIso(),
      id,
    ),
    // Una nuova analisi sostituisce le scadenze create dalla precedente (non quelle dell'utente).
    env.DB.prepare('DELETE FROM deadlines WHERE doc_id = ? AND auto = 1').bind(id),
  ];
  if (analysis.leggibile) {
    for (const s of analysis.scadenze) {
      if (!s.data) continue;
      stmts.push(
        env.DB.prepare(
          'INSERT INTO deadlines (id, user_id, doc_id, title, date, note, done, auto, created_at) VALUES (?, ?, ?, ?, ?, ?, 0, 1, ?)',
        ).bind(crypto.randomUUID(), user.id, id, s.etichetta, s.data, s.regola || '', nowIso()),
      );
    }
    stmts.push(
      env.DB.prepare(
        'INSERT INTO usage (user_id, month, docs) VALUES (?, ?, 1) ON CONFLICT(user_id, month) DO UPDATE SET docs = docs + 1',
      ).bind(user.id, thisMonth()),
    );
  }
  await env.DB.batch(stmts);
  return json(docView(await ownDoc(env, user, id)));
}

// ---------- scadenze ----------

function deadlineView(d) {
  return { id: d.id, docId: d.doc_id, title: d.title, date: d.date, note: d.note, done: !!d.done, auto: !!d.auto };
}

function checkDate(v) {
  if (!isRealDate(v)) throw new HttpError(400, 'Data non valida (formato AAAA-MM-GG).');
  return v;
}

async function createDeadline(request, env, user) {
  const b = await body(request);
  const title = cleanText(b.title, 160, 'il titolo');
  const date = checkDate(b.date);
  const note = typeof b.note === 'string' ? b.note.slice(0, 1000) : '';
  let docId = null;
  if (b.docId) docId = (await ownDoc(env, user, String(b.docId))).id;
  const id = crypto.randomUUID();
  await env.DB.prepare(
    'INSERT INTO deadlines (id, user_id, doc_id, title, date, note, done, auto, created_at) VALUES (?, ?, ?, ?, ?, ?, 0, 0, ?)',
  )
    .bind(id, user.id, docId, title, date, note, nowIso())
    .run();
  const row = await env.DB.prepare('SELECT * FROM deadlines WHERE id = ?').bind(id).first();
  return json(deadlineView(row), 201);
}

async function updateDeadline(request, env, user, id) {
  const cur = await env.DB.prepare('SELECT * FROM deadlines WHERE id = ? AND user_id = ?').bind(id, user.id).first();
  if (!cur) throw new HttpError(404, 'Scadenza non trovata.');
  const b = await body(request);
  const title = b.title === undefined ? cur.title : cleanText(b.title, 160, 'il titolo');
  const date = b.date === undefined ? cur.date : checkDate(b.date);
  const note = b.note === undefined ? cur.note : String(b.note).slice(0, 1000);
  const done = b.done === undefined ? cur.done : b.done ? 1 : 0;
  await env.DB.prepare('UPDATE deadlines SET title = ?, date = ?, note = ?, done = ? WHERE id = ?')
    .bind(title, date, note, done, id)
    .run();
  const row = await env.DB.prepare('SELECT * FROM deadlines WHERE id = ?').bind(id).first();
  return json(deadlineView(row));
}

// ---------- chat e bozze ----------

async function docAnalysis(env, user, docId) {
  if (!docId) return null;
  const d = await ownDoc(env, user, String(docId));
  return d.analysis ? JSON.parse(d.analysis) : null;
}

async function chat(request, env, user) {
  const b = await body(request);
  const msgs = Array.isArray(b.messages) ? b.messages : [];
  if (msgs.length === 0 || msgs.length > 20) throw new HttpError(400, 'Conversazione non valida.');
  const messages = msgs.map((m) => {
    if (!m || !['user', 'assistant'].includes(m.role)) throw new HttpError(400, 'Conversazione non valida.');
    return { role: m.role, content: cleanText(m.content, 4000, 'il messaggio') };
  });
  if (messages[0].role !== 'user' || messages[messages.length - 1].role !== 'user') {
    throw new HttpError(400, 'Conversazione non valida.');
  }
  const analysis = await docAnalysis(env, user, b.docId);
  const reply = await callClaude(env, {
    system: chatSystemPrompt(today(), analysis),
    messages,
    maxTokens: 900,
  });
  return json({ reply });
}

async function draft(request, env, user) {
  const b = await body(request);
  const kind = ['pec', 'email', 'lettera'].includes(b.kind) ? b.kind : null;
  if (!kind) throw new HttpError(400, 'Tipo di bozza non valido.');
  const analysis = await docAnalysis(env, user, b.docId);
  if (!analysis) throw new HttpError(400, 'Analizza prima il documento.');
  const purpose = cleanText(b.purpose, 600, 'lo scopo della bozza');
  const text = await callClaude(env, {
    system: draftSystemPrompt(today(), analysis),
    messages: [{ role: 'user', content: `Tipo: ${kind}. Cosa voglio ottenere: ${purpose}` }],
    maxTokens: 1800,
  });
  const d = extractJson(text);
  return json({
    oggetto: typeof d.oggetto === 'string' ? d.oggetto.slice(0, 300) : '',
    corpo: typeof d.corpo === 'string' ? d.corpo.slice(0, 8000) : '',
    allegati: Array.isArray(d.allegati_suggeriti)
      ? d.allegati_suggeriti.filter((x) => typeof x === 'string').slice(0, 10)
      : [],
    avviso:
      typeof d.avviso === 'string' && d.avviso
        ? d.avviso.slice(0, 300)
        : 'Controlla e modifica la bozza prima di inviarla.',
  });
}

// ---------- dati personali ----------

async function exportAll(env, user) {
  const docs = (await env.DB.prepare('SELECT * FROM documents WHERE user_id = ? ORDER BY created_at').bind(user.id).all())
    .results;
  const deadlines = (await env.DB.prepare('SELECT * FROM deadlines WHERE user_id = ? ORDER BY date').bind(user.id).all())
    .results;
  return json({
    esportatoIl: nowIso(),
    utente: { email: user.email, nome: user.name, creatoIl: user.created_at },
    documenti: docs.map(docView),
    scadenze: deadlines.map(deadlineView),
    nota: 'Le foto delle pagine si scaricano da /v1/documents/{id}/pages/{n}.',
  });
}

async function deleteAccount(env, user) {
  const docs = (await env.DB.prepare('SELECT * FROM documents WHERE user_id = ?').bind(user.id).all()).results;
  for (const d of docs) await deleteDocFiles(env, user, d);
  await env.DB.batch([
    env.DB.prepare('DELETE FROM deadlines WHERE user_id = ?').bind(user.id),
    env.DB.prepare('DELETE FROM documents WHERE user_id = ?').bind(user.id),
    env.DB.prepare('DELETE FROM usage WHERE user_id = ?').bind(user.id),
    env.DB.prepare('DELETE FROM login_attempts WHERE email = ?').bind(user.email),
    env.DB.prepare('DELETE FROM users WHERE id = ?').bind(user.id),
  ]);
  return json({ ok: true });
}

// ---------- instradamento ----------

async function route(request, env) {
  const url = new URL(request.url);
  const method = request.method;
  const path = url.pathname.replace(/\/+$/, '') || '/';

  if (method === 'GET' && path === '/health') return json({ ok: true });
  if (!env.JWT_SECRET || env.JWT_SECRET.length < 16) {
    throw new HttpError(503, 'Il server non è configurato (manca JWT_SECRET).');
  }

  if (method === 'POST' && path === '/v1/auth/register') return register(request, env);
  if (method === 'POST' && path === '/v1/auth/login') return login(request, env);

  const user = await authenticate(request, env);
  let m;

  if (path === '/v1/me') {
    if (method === 'GET') return json(publicUser(user));
    if (method === 'PATCH') {
      const b = await body(request);
      const name = String(b.name ?? '').trim().slice(0, 80);
      await env.DB.prepare('UPDATE users SET name = ? WHERE id = ?').bind(name, user.id).run();
      return json(publicUser({ ...user, name }));
    }
    if (method === 'DELETE') return deleteAccount(env, user);
  }
  if (method === 'GET' && path === '/v1/me/export') return exportAll(env, user);

  if (path === '/v1/documents') {
    if (method === 'GET') {
      const rows = (await env.DB.prepare('SELECT * FROM documents WHERE user_id = ? ORDER BY created_at DESC').bind(user.id).all())
        .results;
      return json(rows.map(docView));
    }
    if (method === 'POST') return createDocument(request, env, user);
  }
  if ((m = /^\/v1\/documents\/([\w-]+)$/.exec(path))) {
    if (method === 'GET') return json(docView(await ownDoc(env, user, m[1])));
    if (method === 'PATCH') {
      const doc = await ownDoc(env, user, m[1]);
      const b = await body(request);
      const title = cleanText(b.title, 120, 'il titolo');
      await env.DB.prepare('UPDATE documents SET title = ? WHERE id = ?').bind(title, doc.id).run();
      return json(docView(await ownDoc(env, user, doc.id)));
    }
    if (method === 'DELETE') {
      const doc = await ownDoc(env, user, m[1]);
      await deleteDocFiles(env, user, doc);
      await env.DB.batch([
        env.DB.prepare('DELETE FROM deadlines WHERE doc_id = ? AND auto = 1').bind(doc.id),
        env.DB.prepare('UPDATE deadlines SET doc_id = NULL WHERE doc_id = ?').bind(doc.id),
        env.DB.prepare('DELETE FROM documents WHERE id = ?').bind(doc.id),
      ]);
      return json({ ok: true });
    }
  }
  if ((m = /^\/v1\/documents\/([\w-]+)\/pages\/(\d+)$/.exec(path))) {
    if (method === 'PUT') return uploadPage(request, env, user, m[1], Number(m[2]));
    if (method === 'GET') return getPage(env, user, m[1], Number(m[2]));
  }
  if (method === 'POST' && (m = /^\/v1\/documents\/([\w-]+)\/analyze$/.exec(path))) {
    return analyzeDocument(env, user, m[1]);
  }

  if (path === '/v1/deadlines') {
    if (method === 'GET') {
      const rows = (await env.DB.prepare('SELECT * FROM deadlines WHERE user_id = ? ORDER BY date').bind(user.id).all()).results;
      return json(rows.map(deadlineView));
    }
    if (method === 'POST') return createDeadline(request, env, user);
  }
  if ((m = /^\/v1\/deadlines\/([\w-]+)$/.exec(path))) {
    if (method === 'PATCH') return updateDeadline(request, env, user, m[1]);
    if (method === 'DELETE') {
      const r = await env.DB.prepare('DELETE FROM deadlines WHERE id = ? AND user_id = ?').bind(m[1], user.id).run();
      if (!r.meta?.changes) throw new HttpError(404, 'Scadenza non trovata.');
      return json({ ok: true });
    }
  }

  if (method === 'POST' && path === '/v1/chat') return chat(request, env, user);
  if (method === 'POST' && path === '/v1/drafts') return draft(request, env, user);

  throw new HttpError(404, 'Non trovato.');
}

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS });
    try {
      return await route(request, env);
    } catch (e) {
      if (e instanceof HttpError || e instanceof AiError) return json({ error: e.message }, e.status);
      console.error('errore interno', e?.stack || e);
      return json({ error: 'Errore del server. Riprova.' }, 500);
    }
  },
};
