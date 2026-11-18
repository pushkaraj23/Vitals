// VitalWatch demo seed script (Level 0).
// Usage: cd seed && npm init -y && npm install firebase-admin && node seed.js
// Needs seed/serviceAccountKey.json (keep it out of git).

const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');

initializeApp({ credential: cert(require('./serviceAccountKey.json')) });
const db = getFirestore();
const auth = getAuth();

const DAYS = 42;
const CALIBRATION_DAYS = 14;
const DEMO_PASSWORD = 'Demo@12345'; // change if you like

// ---------- deterministic random so reruns give the same data ----------
function rng(seed) {
  let s = seed >>> 0;
  return () => {
    s = (s + 0x6d2b79f5) >>> 0;
    let t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
function gauss(r) {
  const u = Math.max(r(), 1e-9), v = r();
  return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v);
}
const round = (x, d = 0) => Math.round(x * 10 ** d) / 10 ** d;

function dateStr(offsetFromStart, start) {
  const d = new Date(start);
  d.setUTCDate(d.getUTCDate() + offsetFromStart);
  return d.toISOString().slice(0, 10);
}

// ---------- users ----------
const USERS = [
  {
    uid: 'demo_healthy',
    email: 'healthy@demo.vitalwatch.app',
    seed: 11,
    gaps: [9, 23, 33],
    profile: {
      name: 'Aarav Deshmukh', age: 29, sex: 'male', heightCm: 176, weightKg: 70,
      conditions: [], medications: [], allergies: [], surgeries: [],
      familyHistory: [], isDemo: true, scenario: 'healthy',
    },
    pattern: { rhr: 0, hrv: 0, deep: 0, spo2: 0, steps: +0.05 },
  },
  {
    uid: 'demo_concerning',
    email: 'concerning@demo.vitalwatch.app',
    seed: 29,
    gaps: [6, 20, 35],
    profile: {
      name: 'Rohan Kulkarni', age: 41, sex: 'male', heightCm: 172, weightKg: 82,
      conditions: [], medications: [], allergies: ['Penicillin'], surgeries: [],
      familyHistory: [
        { relation: 'Father', condition: 'Hypertension', ageAtOnset: 52 },
        { relation: 'Mother', condition: 'Type 2 diabetes', ageAtOnset: 58 },
      ],
      isDemo: true, scenario: 'concerning',
    },
    // total change reached by the last day
    pattern: { rhr: +8.5, hrv: -16, deep: -27, spo2: -1.3, steps: -0.32 },
  },
];

function generateDaily(user, start) {
  const r = rng(user.seed);
  const out = [];
  for (let d = 0; d < DAYS; d++) {
    if (user.gaps.includes(d)) continue; // gap = missing, never zero
    const date = dateStr(d, start);
    const dow = new Date(date + 'T00:00:00Z').getUTCDay();
    const weekend = dow === 0 || dow === 6;
    // drift ramps in only after calibration, gradually
    const p = d < CALIBRATION_DAYS ? 0 : (d - CALIBRATION_DAYS) / (DAYS - 1 - CALIBRATION_DAYS);
    const pat = user.pattern;

    const restingHr = 62 + pat.rhr * p + gauss(r) * 1.5;
    const hrv = 55 + pat.hrv * p + gauss(r) * 6;
    const sleepDeep = 85 + pat.deep * p + (weekend ? 8 : 0) + gauss(r) * 12;
    const sleepTotal = 420 + (weekend ? 35 : 0) + (pat.deep * p) * 1.2 + gauss(r) * 25;
    const spo2 = 97 + pat.spo2 * p * p + gauss(r) * 0.7; // dip mostly late
    const steps = 8000 * (1 + pat.steps * p) * (weekend ? 0.85 : 1) + gauss(r) * 1500;

    out.push({
      date,
      restingHr: round(restingHr, 1),
      hrv: round(Math.max(hrv, 10), 1),
      sleepDeep: round(Math.max(sleepDeep, 20)),
      sleepTotal: round(Math.max(sleepTotal, 240)),
      spo2: round(Math.min(spo2, 100), 1),
      steps: Math.max(Math.round(steps), 500),
      source: 'synthetic',
    });
  }
  return out;
}

function baselines(daily) {
  const cal = daily.filter(x => x.date <= daily[0].date || true).slice(0, 12); // first ~14 days minus gaps
  const metrics = ['restingHr', 'hrv', 'sleepDeep', 'spo2', 'steps'];
  const res = {};
  for (const m of metrics) {
    const v = cal.map(x => x[m]);
    const mean = v.reduce((a, b) => a + b, 0) / v.length;
    const std = Math.sqrt(v.reduce((a, b) => a + (b - mean) ** 2, 0) / v.length);
    res[m] = { mean: round(mean, 2), std: round(std, 2), n: v.length };
  }
  return res;
}

// ---------- rules (content lives in Firestore, not in the app) ----------
const RULES = [
  {
    id: 'rhr_drift', metric: 'restingHr', direction: 'up', title: 'Resting heart rate drifting up',
    minDeltaAbs: 4, amberDays: 7, redDays: 21, minDataDays: 14, requires: ['restingHr'],
    specialist: 'General physician / cardiologist',
    explanation: 'Your resting heart rate has stayed above your personal baseline for several weeks.',
    symptoms: ['Feeling tired more easily', 'Occasional palpitations', 'Trouble recovering after exercise'],
    impacts: [
      { timeframe: '1-3 months', text: 'A sustained higher resting rate can mean your body is under extra load, which may affect energy and recovery.' },
    ],
    remedies: ['Aim for consistent sleep and wake times', 'Cut back on caffeine after noon', 'Add 20 minutes of easy walking daily'],
  },
  {
    id: 'hrv_decline', metric: 'hrv', direction: 'down', title: 'Heart rate variability declining',
    minDeltaPct: 15, amberDays: 7, redDays: 21, minDataDays: 14, requires: ['hrv'],
    specialist: 'General physician',
    explanation: 'Your HRV has been lower than your usual range, which often goes with stress or poor recovery.',
    symptoms: ['Feeling stressed or wound up', 'Poor concentration', 'Low energy in the morning'],
    impacts: [
      { timeframe: '1-3 months', text: 'Lower HRV over time is often linked with reduced recovery and higher stress load.' },
    ],
    remedies: ['Try 10 minutes of slow breathing before bed', 'Limit alcohol late in the evening', 'Keep a regular sleep schedule'],
  },
  {
    id: 'deep_sleep_reduction', metric: 'sleepDeep', direction: 'down', title: 'Deep sleep shrinking',
    minDeltaPct: 20, amberDays: 7, redDays: 21, minDataDays: 14, requires: ['sleepDeep'],
    specialist: 'General physician / sleep specialist',
    explanation: 'The deep sleep you get each night has been shrinking compared with your own baseline.',
    symptoms: ['Waking up unrefreshed', 'Daytime sleepiness', 'Difficulty focusing'],
    impacts: [
      { timeframe: '1-3 months', text: 'Less deep sleep can affect mood, focus and physical recovery.' },
    ],
    remedies: ['Keep the bedroom cool and dark', 'Avoid screens for 45 minutes before bed', 'Finish dinner 2-3 hours before sleep'],
  },
  {
    id: 'spo2_dip', metric: 'spo2', direction: 'down', title: 'Blood oxygen reading dipping',
    minDeltaAbs: 1, amberDays: 5, redDays: 14, minDataDays: 14, requires: ['spo2'],
    specialist: 'General physician',
    explanation: 'Your overnight SpO2 readings have dipped slightly below your usual level. Wrist sensors are noisy, so treat this as a prompt to check in, not a conclusion.',
    symptoms: ['Feeling breathless on stairs', 'Waking up with a dry mouth', 'Morning headaches'],
    impacts: [
      { timeframe: '1-2 months', text: 'If a dip continues, it is worth having a doctor check it with a clinical-grade device.' },
    ],
    remedies: ['Check the watch fit and sensor cleanliness', 'Avoid sleeping on your back if you snore', 'Mention this at your next checkup'],
  },
  {
    id: 'activity_decline', metric: 'steps', direction: 'down', title: 'Daily activity declining',
    minDeltaPct: 25, amberDays: 10, redDays: 21, minDataDays: 14, requires: ['steps'],
    specialist: 'General physician',
    explanation: 'Your daily step count has fallen well below your own usual level.',
    symptoms: ['Low motivation to move', 'Feeling sluggish', 'Joint stiffness'],
    impacts: [
      { timeframe: '2-3 months', text: 'Sustained low activity can reduce fitness and may affect mood and sleep.' },
    ],
    remedies: ['Take a 10-minute walk after each meal', 'Use stairs where possible', 'Set a small daily step target and build up'],
  },
].map(r => ({ ...r, version: 1, reviewedBy: 'demo-clinician (simulated)' }));

const HABIT_TEMPLATES = [
  { id: 'walk_after_meals', title: '10-minute walk after meals', linkedRule: 'activity_decline', targetPerDay: 3, durationDays: 14 },
  { id: 'wind_down', title: 'Screens off 45 min before bed', linkedRule: 'deep_sleep_reduction', targetPerDay: 1, durationDays: 14 },
  { id: 'slow_breathing', title: '10 minutes of slow breathing', linkedRule: 'hrv_decline', targetPerDay: 1, durationDays: 14 },
];

// ---------- seeded flags (backup if Dart engine misbehaves) ----------
function flagsFor(user, start) {
  if (user.uid === 'demo_healthy') {
    return [{
      id: 'flag_stable', ruleId: 'overall_stable', level: 'green', metric: 'overall',
      startDate: dateStr(0, start), durationDays: DAYS, severity: 0, confidence: 'high',
      title: 'Your patterns look stable',
      explanation: 'Your resting heart rate, HRV, sleep and activity are all within your personal baseline range.',
      dataUsed: ['restingHr', 'hrv', 'sleepDeep', 'spo2', 'steps'], source: 'seed',
    }];
  }
  const s = dateStr(CALIBRATION_DAYS + 3, start);
  const mk = (ruleId, level, metric, severity, days, conf, extra) => ({
    id: 'flag_' + ruleId, ruleId, level, metric, startDate: s, durationDays: days,
    severity, confidence: conf,
    title: RULES.find(r => r.id === ruleId).title,
    explanation: RULES.find(r => r.id === ruleId).explanation,
    dataUsed: [metric], source: 'seed', ...extra,
  });
  return [
    mk('rhr_drift', 'red', 'restingHr', 3, 24, 'high', { baselineValue: 62, currentValue: 70.5 }),
    mk('hrv_decline', 'red', 'hrv', 3, 24, 'high', { baselineValue: 55, currentValue: 39 }),
    mk('deep_sleep_reduction', 'amber', 'sleepDeep', 2, 18, 'medium', { baselineValue: 85, currentValue: 58 }),
    mk('activity_decline', 'amber', 'steps', 2, 16, 'medium', { baselineValue: 8000, currentValue: 5440 }),
    mk('spo2_dip', 'amber', 'spo2', 1, 8, 'low', { baselineValue: 97, currentValue: 95.7 }),
  ];
}

// ---------- batched writer ----------
const ops = [];
const set = (path, data) => ops.push({ path, data });
async function commit() {
  for (let i = 0; i < ops.length; i += 400) {
    const batch = db.batch();
    ops.slice(i, i + 400).forEach(o => batch.set(db.doc(o.path), o.data));
    await batch.commit();
  }
  console.log(`Wrote ${ops.length} documents.`);
}

async function ensureAuthUser(u) {
  const base = { email: u.email, password: DEMO_PASSWORD, displayName: u.profile.name, emailVerified: true };
  try { await auth.updateUser(u.uid, base); }
  catch (e) {
    if (e.code === 'auth/user-not-found') await auth.createUser({ uid: u.uid, ...base });
    else throw e;
  }
}

async function main() {
  const today = new Date();
  today.setUTCHours(0, 0, 0, 0);
  const start = new Date(today);
  start.setUTCDate(start.getUTCDate() - (DAYS - 1));

  RULES.forEach(r => { const { id, ...rest } = r; set(`rules/${id}`, rest); });
  HABIT_TEMPLATES.forEach(h => { const { id, ...rest } = h; set(`habitTemplates/${id}`, rest); });

  for (const u of USERS) {
    await ensureAuthUser(u);
    set(`users/${u.uid}`, { ...u.profile, email: u.email, dataStart: dateStr(0, start), dataEnd: dateStr(DAYS - 1, start) });

    const daily = generateDaily(u, start);
    daily.forEach(d => { const { date, ...rest } = d; set(`users/${u.uid}/daily/${date}`, { date, ...rest }); });

    const base = baselines(daily);
    Object.entries(base).forEach(([m, v]) =>
      set(`users/${u.uid}/baselines/${m}`, { ...v, calibratedUntil: dateStr(CALIBRATION_DAYS - 1, start) }));

    flagsFor(u, start).forEach(f => { const { id, ...rest } = f; set(`users/${u.uid}/flags/${id}`, rest); });
  }

  // concerning user only: symptoms, one partial habit, one simulated review
  const c = 'demo_concerning';
  set(`users/${c}/symptoms/s1`, { symptom: 'Feeling tired more easily', date: dateStr(30, start), flagId: 'flag_rhr_drift' });
  set(`users/${c}/symptoms/s2`, { symptom: 'Waking up unrefreshed', date: dateStr(34, start), flagId: 'flag_deep_sleep_reduction' });
  set(`users/${c}/symptoms/s3`, { symptom: 'Low motivation to move', date: dateStr(38, start), flagId: 'flag_activity_decline' });

  const progress = [];
  for (let i = 0; i < 7; i++) progress.push({ date: dateStr(DAYS - 7 + i, start), done: i !== 2 && i !== 5 });
  set(`users/${c}/habits/h1`, {
    templateId: 'walk_after_meals', title: '10-minute walk after meals', linkedFlag: 'flag_activity_decline',
    startDate: dateStr(DAYS - 7, start), durationDays: 14, progress,
    metricBefore: 5440, metricAfter: 6100, metric: 'steps',
  });

  set(`users/${c}/reviews/flag_rhr_drift`, {
    verdict: 'Needs consultation',
    note: 'Sustained upward drift in resting HR with falling HRV and deep sleep. Recommend a general physician check, given the family history of hypertension.',
    reviewerName: 'Dr. Demo Reviewer', reviewedAt: dateStr(DAYS - 1, start),
    simulated: true,
  });

  await commit();
  console.log('\nDemo logins (password: ' + DEMO_PASSWORD + ')');
  USERS.forEach(u => console.log(' ', u.email));
}

main().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
