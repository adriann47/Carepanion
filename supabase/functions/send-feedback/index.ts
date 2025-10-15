// Supabase Edge Function: send-feedback
// This function expects a JSON POST body with fields:
// { user_id, role, subject, message, attachments, app_version, platform }
// It sends an email via SendGrid to the TO_EMAIL environment variable.

export default async (req: Request) => {
  try {
    if (req.method !== 'POST') return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405 });

    const body = await req.json();
    const {
      user_id, role, subject, message, attachments, app_version, platform
    } = body as Record<string, any>;

    if (!message || !user_id) {
      return new Response(JSON.stringify({ error: 'missing required fields' }), { status: 400 });
    }

    // Access environment variables (Supabase functions use Deno runtime)
    const env = (typeof Deno !== 'undefined' && Deno.env) ? Deno.env : null;
    const SENDGRID_API_KEY = env?.get('SENDGRID_API_KEY') ?? null;
    const TO_EMAIL = env?.get('TO_EMAIL') ?? 'carepanionph@gmail.com';
    const FROM_EMAIL = env?.get('FROM_EMAIL') ?? 'no-reply@carepanion.app';

    if (!SENDGRID_API_KEY) {
      return new Response(JSON.stringify({ error: 'SENDGRID_API_KEY not set' }), { status: 500 });
    }

    const subjectLine = subject ? `[Feedback] ${subject}` : '[Feedback] New report';

    const contentLines = [
      `User ID: ${user_id}`,
      `Role: ${role ?? 'unknown'}`,
      `App version: ${app_version ?? 'unknown'}`,
      `Platform: ${platform ?? 'unknown'}`,
      '',
      'Message:',
      message,
      '',
      'Attachments:',
      JSON.stringify(attachments ?? []),
    ];

    const payload = {
      personalizations: [{ to: [{ email: TO_EMAIL }] }],
      from: { email: FROM_EMAIL, name: 'Carepanion App' },
      subject: subjectLine,
      content: [{ type: 'text/plain', value: contentLines.join('\n') }],
    };

    const resp = await fetch('https://api.sendgrid.com/v3/mail/send', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${SENDGRID_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    });

    if (!resp.ok) {
      const text = await resp.text();
      return new Response(JSON.stringify({ error: 'sendgrid_error', detail: text }), { status: 502 });
    }

    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  } catch (err) {
    const msg = (err && typeof err === 'object' && 'message' in err) ? (err as any).message : String(err);
    return new Response(JSON.stringify({ error: msg }), { status: 500 });
  }
};
