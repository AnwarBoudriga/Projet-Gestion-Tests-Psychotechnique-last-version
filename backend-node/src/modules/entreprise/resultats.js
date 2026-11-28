const router = require('express').Router();
const PDFDocument = require('pdfkit');
const { z } = require('zod');
const db = require('../../config/db');
const validate = require('../../middlewares/validate');
const AppError = require('../../utils/AppError');
const { toCsv } = require('../../utils/csv');
const { logAction } = require('../../utils/audit');
const { parseId } = require('./helpers');
const proctoring = require('../../utils/proctoring');
const { sendMail } = require('../../utils/mailer');

const listSchema = z.object({
  testId: z.coerce.number().int().min(1).optional(),
  search: z.string().trim().optional(),
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(200).default(50),
});

const fmtRow = (r) => ({
  invitationId: r.invitation_id,
  candidat: r.candidat_nom,
  email: r.candidat_email,
  testId: r.test_id,
  test: r.test_titre,
  score: r.score,
  scoreMax: r.score_max,
  pourcentage: Number(r.pourcentage),
  reussi: Boolean(r.reussi),
  dureeSecondes: r.duree_secondes,
  soumisAt: r.soumis_at,
});

/** Validations manuelles faites par l'entreprise (journal d'activité): Map invitationId -> date. */
async function lireValidations(ids) {
  const map = new Map();
  if (!ids.length) return map;
  const [rows] = await db.query(
    `SELECT entite_id, MAX(created_at) AS at FROM audit_logs
     WHERE action = 'CANDIDAT_VALIDE' AND entite = 'invitation' AND entite_id IN (?)
     GROUP BY entite_id`,
    [ids]
  );
  for (const r of rows) map.set(r.entite_id, r.at);
  return map;
}
const champsValidation = (at) => ({ valide: at != null, valideLe: at || null });

function filtre(req, q) {
  const where = ['entreprise_id = ?'];
  const params = [req.user.id];
  if (q.testId) { where.push('test_id = ?'); params.push(q.testId); }
  if (q.search) { where.push('(candidat_nom LIKE ? OR candidat_email LIKE ?)'); params.push(`%${q.search}%`, `%${q.search}%`); }
  return { w: `WHERE ${where.join(' AND ')}`, params };
}

// GET /api/entreprise/resultats?testId=&search=   -> liste des candidats ayant un résultat
router.get('/', validate(listSchema, 'query'), async (req, res) => {
  const { w, params } = filtre(req, req.valid);
  const { page, limit } = req.valid;
  const [[{ total }]] = await db.query(`SELECT COUNT(*) AS total FROM v_resultats_detail ${w}`, params);
  const [rows] = await db.query(`SELECT * FROM v_resultats_detail ${w} ORDER BY soumis_at DESC LIMIT ? OFFSET ?`, [...params, limit, (page - 1) * limit]);
  const risques = await proctoring.lireResumes(rows.map((r) => r.invitation_id));
  const validations = await lireValidations(rows.map((r) => r.invitation_id));
  res.json({
    data: rows.map((r) => ({
      ...fmtRow(r),
      risque: risques.get(r.invitation_id) || null,
      ...champsValidation(validations.get(r.invitation_id)),
    })),
    pagination: { page, limit, total: Number(total) },
  });
});

// GET /api/entreprise/resultats/export.csv?testId=   -> tous les résultats
router.get('/export.csv', validate(listSchema, 'query'), async (req, res) => {
  const { w, params } = filtre(req, req.valid);
  const [rows] = await db.query(`SELECT * FROM v_resultats_detail ${w} ORDER BY soumis_at DESC`, params);
  const csv = toCsv([
    ['Candidat', 'Email', 'Test', 'Score', 'Score max', 'Pourcentage', 'Réussi', 'Durée (s)', 'Soumis le'],
    ...rows.map((r) => [r.candidat_nom, r.candidat_email, r.test_titre, r.score, r.score_max, r.pourcentage, r.reussi ? 'Oui' : 'Non', r.duree_secondes, r.soumis_at]),
  ]);
  await logAction(req, { action: 'RESULTATS_EXPORTES', details: { format: 'csv', lignes: rows.length } });
  res.setHeader('Content-Type', 'text/csv; charset=utf-8');
  res.setHeader('Content-Disposition', 'attachment; filename="resultats.csv"');
  res.send(csv);
});

async function detail(entrepriseId, invitationId) {
  const [[r]] = await db.query('SELECT * FROM v_resultats_detail WHERE invitation_id = ? AND entreprise_id = ?', [invitationId, entrepriseId]);
  if (!r) throw new AppError(404, 'Résultat introuvable.');
  const [qs] = await db.query(
    `SELECT q.id, tq.position, q.enonce, q.option_a, q.option_b, q.option_c, q.option_d, q.reponse_correcte, q.points, c.lettre AS choix
     FROM test_questions tq JOIN v_questions q ON q.id = tq.question_id
     LEFT JOIN passages p ON p.invitation_id = ?
     LEFT JOIN reponses rp ON rp.question_id = q.id AND rp.passage_id = p.id
     LEFT JOIN choix c ON c.id = rp.choix_id
     WHERE tq.test_id = ? ORDER BY tq.position`,
    [invitationId, r.test_id]
  );
  return {
    ...fmtRow(r),
    risque: await proctoring.lire(invitationId),
    ...champsValidation((await lireValidations([invitationId])).get(invitationId)),
    questions: qs.map((q) => ({
      position: q.position,
      enonce: q.enonce,
      options: { A: q.option_a, B: q.option_b, C: q.option_c, D: q.option_d },
      reponseCandidat: q.choix,
      reponseCorrecte: q.reponse_correcte,
      correcte: q.choix == null ? null : q.choix === q.reponse_correcte,
      points: q.points,
      pointsObtenus: q.choix === q.reponse_correcte ? q.points : 0,
    })),
  };
}

// GET /api/entreprise/resultats/:invitationId   -> résultat détaillé d'un candidat
router.get('/:invitationId', async (req, res) => {
  const id = parseId(req.params.invitationId);
  const d = await detail(req.user.id, id);
  // Surveillance : rafraîchit le rapport depuis Spring si possible (sinon on garde la copie locale)
  try {
    if (await proctoring.collecter(id)) d.risque = await proctoring.lire(id);
  } catch (e) {
    console.warn(`[proctoring] service injoignable: ${e.message}`);
  }
  res.json(d);
});

// GET /api/entreprise/resultats/:invitationId/risque   -> rapport de surveillance (score de risque + raisons)
// Interroge le service Spring en direct ; s'il est arrêté, renvoie la dernière copie enregistrée.
router.get('/:invitationId/risque', async (req, res) => {
  const id = parseId(req.params.invitationId);
  const [[ok]] = await db.query('SELECT 1 AS ok FROM v_resultats_detail WHERE invitation_id = ? AND entreprise_id = ?', [id, req.user.id]);
  if (!ok) throw new AppError(404, 'Résultat introuvable.');

  let source = 'service';
  try {
    if (!(await proctoring.collecter(id))) source = 'copie';
  } catch (e) {
    console.warn(`[proctoring] service injoignable: ${e.message}`);
    source = 'copie';
  }
  const rapport = await proctoring.lire(id);
  if (!rapport) throw new AppError(404, 'Aucune donnée de surveillance pour ce candidat.');
  await logAction(req, { action: 'RISQUE_CONSULTE', entite: 'invitation', entiteId: id });
  res.json({ ...rapport, source });
});

// POST /api/entreprise/resultats/:invitationId/valider
// Validation MANUELLE par l'entreprise (après avoir consulté le score et le rapport de surveillance):
// envoie l'email de félicitations au candidat. Rien n'est envoyé automatiquement.
router.post('/:invitationId/valider', async (req, res) => {
  const id = parseId(req.params.invitationId);
  const [[r]] = await db.query(
    'SELECT * FROM v_resultats_detail WHERE invitation_id = ? AND entreprise_id = ?',
    [id, req.user.id]
  );
  if (!r) throw new AppError(404, 'Résultat introuvable.');
  if ((await lireValidations([id])).get(id)) throw new AppError(409, 'Ce candidat a déjà été validé.');

  const [[ent]] = await db.query('SELECT nom FROM entreprises WHERE id = ?', [req.user.id]);
  const entreprise = ent ? ent.nom : 'L’entreprise';
  const pct = Math.round(Number(r.pourcentage));

  const envoye = await sendMail({
    to: r.candidat_email,
    subject: `Félicitations : votre candidature est validée (test « ${r.test_titre} »)`,
    text:
      `Bonjour ${r.candidat_nom},\n\n` +
      `Après examen de votre test « ${r.test_titre} » (score : ${r.score}/${r.score_max}, soit ${pct} %), ` +
      `${entreprise} a le plaisir de vous informer que votre candidature est validée.\n\n` +
      `${entreprise} vous contactera prochainement pour la suite du processus.\n\n` +
      `Cordialement,\nPsyTech Pro`,
  });
  if (!envoye) throw new AppError(502, 'L’email n’a pas pu être envoyé. Le candidat n’a pas été validé, réessayez dans un instant.');

  await logAction(req, { action: 'CANDIDAT_VALIDE', entite: 'invitation', entiteId: id, details: { email: r.candidat_email } });
  res.json({ ok: true, valide: true, valideLe: new Date().toISOString(), emailEnvoye: true });
});

// GET /api/entreprise/resultats/:invitationId/export.csv
router.get('/:invitationId/export.csv', async (req, res) => {
  const d = await detail(req.user.id, parseId(req.params.invitationId));
  const csv = toCsv([
    ['Candidat', d.candidat], ['Email', d.email], ['Test', d.test],
    ['Score', `${d.score} / ${d.scoreMax}`], ['Pourcentage', `${d.pourcentage} %`], ['Réussi', d.reussi ? 'Oui' : 'Non'],
    [],
    ['N°', 'Question', 'Réponse du candidat', 'Bonne réponse', 'Correcte', 'Points obtenus'],
    ...d.questions.map((q) => [q.position, q.enonce, q.reponseCandidat || '—', q.reponseCorrecte, q.correcte == null ? 'Sans réponse' : q.correcte ? 'Oui' : 'Non', q.pointsObtenus]),
  ]);
  await logAction(req, { action: 'RESULTAT_EXPORTE', entite: 'invitation', entiteId: d.invitationId, details: { format: 'csv' } });
  res.setHeader('Content-Type', 'text/csv; charset=utf-8');
  res.setHeader('Content-Disposition', `attachment; filename="resultat-${d.invitationId}.csv"`);
  res.send(csv);
});

// GET /api/entreprise/resultats/:invitationId/export.pdf
router.get('/:invitationId/export.pdf', async (req, res) => {
  const d = await detail(req.user.id, parseId(req.params.invitationId));
  await logAction(req, { action: 'RESULTAT_EXPORTE', entite: 'invitation', entiteId: d.invitationId, details: { format: 'pdf' } });
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `attachment; filename="resultat-${d.invitationId}.pdf"`);
  const doc = new PDFDocument({ margin: 50, info: { Title: `Résultat - ${d.candidat}` } });
  doc.pipe(res);
  doc.fontSize(20).fillColor('#1E2B4A').text('PsyTech Pro — Résultat du candidat');
  doc.moveDown(0.8).fontSize(12).fillColor('#000');
  doc.text(`Candidat : ${d.candidat}`).text(`Email : ${d.email}`).text(`Test : ${d.test}`);
  doc.moveDown(0.5).fontSize(16).fillColor(d.reussi ? '#0E8C87' : '#B42318')
    .text(`Score : ${d.score} / ${d.scoreMax} (${d.pourcentage} %) — ${d.reussi ? 'Réussi' : 'Non réussi'}`);
  doc.moveDown(0.8).fontSize(13).fillColor('#1E2B4A').text('Détail des réponses');
  doc.moveDown(0.3).fontSize(10).fillColor('#000');
  for (const q of d.questions) {
    const etat = q.correcte == null ? 'sans réponse' : q.correcte ? 'correcte' : 'incorrecte';
    doc.text(`${q.position}. ${q.enonce}`, { continued: false });
    doc.fillColor('#555').text(`   Réponse: ${q.reponseCandidat || '—'}   |   Bonne réponse: ${q.reponseCorrecte}   |   ${etat}   |   ${q.pointsObtenus}/${q.points} pt`).fillColor('#000');
    doc.moveDown(0.3);
  }
  doc.end();
});

module.exports = router;
