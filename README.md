# Football Live

Native macOS football scores, match analysis, highlights, followed-team alerts,
menu-bar scores, localization, and StoreKit 2 subscriptions.

## Requirements

- macOS 26 or later
- Xcode 26 or later
- A production Tempo backend configured with `TEMPO_API_BASE_URL`

For local development, API credentials are loaded from the macOS Keychain or
local ignored configuration. Never commit provider API keys to this repository.

See `Backend/README.md` for the production proxy setup and
`Production.example.xcconfig` for the non-secret client configuration template.
