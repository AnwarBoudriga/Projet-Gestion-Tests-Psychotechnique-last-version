const router = require('express').Router();
const { z } = require('zod');
const rateLimit = require('express-rate-limit');
const validate = require('../../middlewares/validate');
const { genererQuestions } = require('../../utils/ia');
const { logAction } = require('../../utils/audit');

// Les appels IA coûtent de l'argent: limite par entreprise (token) et par heure.
const limiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: Number(process.env.AI_RATE_LIMIT || 20),
  keyGenerator: (req) => `ent-${req.user?.id ?? req.ip}`,
  message: { message: "Limite de générations IA atteinte, réessayez plus tard." },
});

const schema = z.object({
  sujet: z.string().trim().min(3, 'Sujet requis (3 caractères minimum)').max(500),
  nombre: z.coerce.number().int().min(1, 'Entre 1 et 20 questions').max(20, 'Entre 1 et 20 questions').default(5),
  difficulte: z.enum(['facile', 'moyen', 'difficile']).default('moyen'),
  points: z.coerce.number().int().min(1).max(1000).default(1),
});

// POST /api/entreprise/ia/questions   { sujet, nombre, difficulte, points }
// -> { data: [ { enonce, optionA..D, reponseCorrecte, points } ] }   (rien n'est enregistré)
router.post('/questions', limiter, validate(schema), async (req, res) => {
  const questions = await genererQuestions(req.valid);
  await logAction(req, { action: 'QUESTIONS_IA_GENEREES', details: { sujet: req.valid.sujet, nombre: questions.length } });
  res.json({ data: questions });
});

module.exports = router;
