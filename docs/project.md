# Project Conventions

This project follows Rails 7.2 standard architecture with specific conventions optimized for stable AI-assisted code generation.

**Design Philosophy**: Built for non-coders - prioritizing simplicity and maintainability over powerful features.

## Environment

**Runtime Environment**: Runs by default in a Cloud-native environment (Clacky CDE), accessible via public URLs

## Environment Variables

### Out-of-the-Box Configuration
The following services are **pre-configured** and ready to use:

| Service | Variables | Status |
|---------|-----------|--------|
| **Email** | SMTP_ADDRESS, SMTP_PORT, SMTP_USERNAME, SMTP_PASSWORD, SMTP_DOMAIN | ✅ Ready |
| **LLM** | LLM_BASE_URL, LLM_API_KEY, LLM_MODEL | ✅ Ready (DeepSeek-V3) |
| **Stripe** | STRIPE_PUBLISHABLE_KEY, STRIPE_SECRET_KEY | ✅ Ready (Test mode) |

### CLACKY_* Variables
`CLACKY_*` variables are **platform-injected** and should **NEVER** be used directly in code.

## Deployment

**Status**: ✅ Production-ready with zero configuration

- **Database**: PostgreSQL pre-configured
- **Storage**: Cloud storage (S3/GCS) would be used, already handled
- **Deployment**: One-click via `Dockerfile` - push to trigger automatic builds

## Port Detection

Auto-detects port in priority order:
1. `ENV['APP_PORT']`
2. `ENV['PORT']`
3. `config/application.yml` APP_PORT
4. Auto: 3001 (submodule) / 3000 (standalone)

Use `EnvChecker.get_app_port` in code - never hardcode ports.

## Generator Auto-Configuration

Running these generators **automatically** updates `config/application.yml`:
- `rails g authentication` - OAuth providers
- `rails g stripe_pay` - Payment configuration
- `rails g llm` - LLM service setup

Check the generated config - if defaults exist, no manual setup needed.

