# Lovable Agent Worker (Railway)

Background worker that runs autonomous Computer-Use jobs queued by your Lovable app.

## 1. Deploy to Railway (5 min)

1. Go to https://railway.app → **New Project → Empty Project**.
2. Click **+ New → GitHub Repo** OR **+ New → Empty Service** → drag & drop this folder.
   (Or push the folder to a new GitHub repo and "Deploy from GitHub".)
3. Open the service → **Variables** tab → add:

| Variable | Value |
|---|---|
| `SUPABASE_FUNCTIONS_URL` | `https://wxriqujkusncquznsusr.supabase.co/functions/v1` |
| `WORKER_SHARED_SECRET` | *(same string you saved in Lovable)* |
| `ANTHROPIC_API_KEY` | *(your key from console.anthropic.com)* |
| `BROWSERBASE_API_KEY` | *(from browserbase.com)* |
| `BROWSERBASE_PROJECT_ID` | *(from browserbase.com)* |

4. **Settings → Start Command**: `node index.js`
5. Deploy. Logs should show `Worker started, polling…`.

## 2. Test

In Telegram, send your Big Brain bot:
> "Buch mir einen Arzttermin in Hannover für Freitag 13 Uhr"

You should see:
- "🧠 Alles klar, ich kümmere mich darum…" instantly
- Within a minute: status updates in the DB
- Whenever Claude needs input ("Welche Postleitzahl?", "Krankenversichertennummer?") it asks via Telegram
- "✅ Erledigt" when done.

## Costs
- Railway: ~$5/month
- Browserbase: ~$0.10–0.30/job
- Anthropic Computer Use: ~$0.50–3 per job depending on complexity
