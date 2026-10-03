# Tempo production API proxy

The App Store build must call this backend instead of containing GOAL or Gemini keys.

1. Create a Cloudflare Workers account and install Wrangler.
2. From this directory, store both provider keys as encrypted Worker secrets:

   `wrangler secret put GOAL_API_KEY`

   `wrangler secret put GEMINI_API_KEY`

3. Deploy with `wrangler deploy`.
4. Set `TEMPO_API_BASE_URL` to the deployed HTTPS origin in the Footballlive Release build configuration. The value is a public URL, not a secret.
5. Do not add either provider key to an Info.plist, asset, source file, or Release scheme.

Do not ship the example URL. An actual deployed Worker URL is required. Also
confirm that the selected GOAL API plan has enough quota for all app users;
the free plan's allowance is shared by every installation using this Worker.

The Worker allow-lists GOAL resources, applies a basic client rate limit, validates AI request size, and keeps both upstream keys server-side. For a high-volume public launch, replace the in-memory limiter with Cloudflare Rate Limiting or Durable Objects and add App Store receipt/account validation.
