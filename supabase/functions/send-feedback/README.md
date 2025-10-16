Send-feedback Edge Function
==========================

This Edge Function receives feedback payloads from the mobile app and sends an email to the team via SendGrid.

Environment variables required:
- SENDGRID_API_KEY: SendGrid API key (set as Supabase function secret)
- TO_EMAIL: Recipient email address (set to carepanionph@gmail.com)
- FROM_EMAIL: Optional from address (defaults to no-reply@carepanion.app)

Deploy (Supabase CLI):

```powershell
supabase functions deploy send-feedback
supabase secrets set SENDGRID_API_KEY=your_sendgrid_api_key
supabase secrets set TO_EMAIL=carepanionph@gmail.com
supabase secrets set FROM_EMAIL=no-reply@yourdomain.com
```

Test (CLI):

```powershell
supabase functions invoke send-feedback --body '{"user_id":"<id>","message":"test","subject":"test"}'
```

Notes:
- Ensure you verify your sending domain with SendGrid and configure SPF/DKIM to improve deliverability to Gmail.
- Do not store API keys in the client app.
