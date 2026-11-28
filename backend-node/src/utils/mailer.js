const nodemailer = require('nodemailer');

/**
 * Envoi d'emails. Ordre de priorité :
 *  1. BREVO_API_KEY  -> API HTTPS de Brevo (fonctionne sur Render gratuit : port 443, jamais bloqué)
 *  2. SMTP_HOST      -> SMTP classique (bloqué sur Render gratuit : ports 25/465/587)
 *  3. rien           -> le mail est affiché dans la console (mode dev)
 */
let transporter = null;
function getTransporter() {
  if (transporter) return transporter;
  if (!process.env.SMTP_HOST) return null;
  transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: Number(process.env.SMTP_PORT || 587),
    secure: process.env.SMTP_SECURE === 'true',
    auth: process.env.SMTP_USER ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS } : undefined,
  });
  return transporter;
}

const FROM_DEFAUT = 'PsyTech Pro <no-reply@psytech.local>';

/** "PsyTech Pro <a@b.com>" -> { name, email } */
function parseFrom(from) {
  const m = /^\s*"?(.*?)"?\s*<(.+?)>\s*$/.exec(from || '');
  return m ? { name: m[1] || 'PsyTech Pro', email: m[2].trim() } : { name: 'PsyTech Pro', email: String(from || '').trim() };
}

async function envoyerBrevo({ to, subject, text }) {
  const r = await fetch('https://api.brevo.com/v3/smtp/email', {
    method: 'POST',
    headers: { 'api-key': process.env.BREVO_API_KEY, 'content-type': 'application/json', accept: 'application/json' },
    body: JSON.stringify({ sender: parseFrom(process.env.MAIL_FROM || FROM_DEFAUT), to: [{ email: to }], subject, textContent: text }),
    signal: AbortSignal.timeout(10000),
  });
  if (!r.ok) throw new Error(`Brevo HTTP ${r.status}: ${(await r.text()).slice(0, 200)}`);
}

/** Retourne true si l'email est parti, false sinon (ne lève jamais d'erreur). */
async function sendMail({ to, subject, text }) {
  try {
    if (process.env.BREVO_API_KEY) {
      await envoyerBrevo({ to, subject, text });
      return true;
    }
    const t = getTransporter();
    if (!t) {
      console.log(`\n[mail simulé] À: ${to}\nSujet: ${subject}\n${text}\n`);
      return false;
    }
    await t.sendMail({ from: process.env.MAIL_FROM || FROM_DEFAUT, to, subject, text });
    return true;
  } catch (e) {
    console.error('[mail] échec:', e.message);
    return false;
  }
}
module.exports = { sendMail, parseFrom };
