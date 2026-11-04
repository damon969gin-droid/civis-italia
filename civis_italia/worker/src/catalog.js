// Catalogo delle scadenze generali (uguali per tutti), con la fonte e la data dell'ultimo controllo.
// REGOLA: qui si inserisce una scadenza solo se è fissata da una norma e confermata da più fonti.
// Le scadenze che dipendono dal comune, dalla regione o dalla data di notifica NON stanno qui:
// quelle le legge l'AI dai documenti dell'utente.

const FONTE_ENTRATE = { nome: 'Agenzia delle Entrate', url: 'https://www.agenziaentrate.gov.it' };

/** Ultima verifica del catalogo: da aggiornare ogni volta che si ricontrolla. */
export const CATALOG_VERIFIED_ON = '2026-11-02';

const RULES = [
  {
    id: 'imu-acconto',
    titolo: 'IMU: acconto',
    mese: 6,
    giorno: 16,
    chi: 'Chi possiede immobili diversi dall’abitazione principale (le abitazioni principali non di lusso sono escluse).',
    come: 'Si paga con F24 o con il modulo di pagamento PagoPA. L’importo dipende dall’aliquota del tuo comune.',
    fonte: FONTE_ENTRATE,
    norma: 'Legge 160/2019, art. 1, comma 762',
  },
  {
    id: 'imu-saldo',
    titolo: 'IMU: saldo',
    mese: 12,
    giorno: 16,
    chi: 'Chi possiede immobili diversi dall’abitazione principale (le abitazioni principali non di lusso sono escluse).',
    come: 'Si paga con F24 o con il modulo di pagamento PagoPA. L’importo dipende dall’aliquota del tuo comune.',
    fonte: FONTE_ENTRATE,
    norma: 'Legge 160/2019, art. 1, comma 762',
  },
  {
    id: 'acconto-imposte-novembre',
    titolo: 'Seconda rata (o unica) dell’acconto delle imposte sui redditi',
    mese: 11,
    giorno: 30,
    chi: 'Chi presenta il modello Redditi o ha cedolare secca, IVIE o IVAFE. Dipendenti e pensionati con il 730: di solito lo trattiene il datore di lavoro o l’ente pensionistico.',
    come: 'Si paga con F24, in un’unica soluzione. Sotto 257,52 euro l’acconto si paga tutto a novembre.',
    fonte: FONTE_ENTRATE,
    norma: 'DPR 435/2001 e norme successive',
  },
];

// ---------- giorni lavorativi ----------

function easterMonday(year) {
  // Algoritmo di Gauss per la Pasqua (calendario gregoriano).
  const a = year % 19;
  const b = Math.floor(year / 100);
  const c = year % 100;
  const d = Math.floor(b / 4);
  const e = b % 4;
  const f = Math.floor((b + 8) / 25);
  const g = Math.floor((b - f + 1) / 3);
  const h = (19 * a + b - d - g + 15) % 30;
  const i = Math.floor(c / 4);
  const k = c % 4;
  const l = (32 + 2 * e + 2 * i - h - k) % 7;
  const m = Math.floor((a + 11 * h + 22 * l) / 451);
  const month = Math.floor((h + l - 7 * m + 114) / 31); // 3 = marzo, 4 = aprile
  const day = ((h + l - 7 * m + 114) % 31) + 1;
  return new Date(Date.UTC(year, month - 1, day + 1));
}

const FIXED_HOLIDAYS = ['01-01', '01-06', '04-25', '05-01', '06-02', '08-15', '11-01', '12-08', '12-25', '12-26'];

function isHoliday(d) {
  const dow = d.getUTCDay();
  if (dow === 0 || dow === 6) return true;
  const key = d.toISOString().slice(5, 10);
  if (FIXED_HOLIDAYS.includes(key)) return true;
  return d.toISOString().slice(0, 10) === easterMonday(d.getUTCFullYear()).toISOString().slice(0, 10);
}

/** Se la scadenza cade di sabato, domenica o festivo, passa al primo giorno lavorativo dopo. */
export function nextBusinessDay(year, month, day) {
  const d = new Date(Date.UTC(year, month - 1, day));
  while (isHoliday(d)) d.setUTCDate(d.getUTCDate() + 1);
  return d.toISOString().slice(0, 10);
}

/** Scadenze generali per un anno. */
export function catalogForYear(year) {
  return RULES.map((r) => {
    const nominale = `${year}-${String(r.mese).padStart(2, '0')}-${String(r.giorno).padStart(2, '0')}`;
    const data = nextBusinessDay(year, r.mese, r.giorno);
    return {
      id: `${r.id}-${year}`,
      titolo: r.titolo,
      data,
      spostata: data !== nominale,
      chi: r.chi,
      come: r.come,
      fonte: r.fonte,
      norma: r.norma,
      verificataIl: CATALOG_VERIFIED_ON,
    };
  });
}
