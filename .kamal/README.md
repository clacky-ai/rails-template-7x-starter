# Kamal Deployment Enhancement Scripts

This project's Kamal deployment tool includes three intelligent enhancement features that automate common deployment issues.

## 🎯 Feature Overview

### 1. 📦 Smart Environment Variable Sync (`bin/kamal_sync_env`)

Automatically syncs environment variables from `config/application.yml` to `config/deploy.yml`.

**Features**:
- ✅ Automatic ERB template parsing
- ✅ Intelligent diff detection (added, modified, deleted)
- ✅ Interactive change confirmation
- ✅ Preserves deploy.yml comments and formatting
- ✅ All values stored as plaintext in `env.clear`

**Usage**:
```bash
# Run sync manually
bin/kamal_sync_env

# Automatic integration: runs before every kamal deploy
```

### 2. 🐳 Docker Registry Mirror Auto-Detection (`.kamal/hooks/docker-setup`)

Automatically detects and configures the fastest Docker registry mirror on servers.

**Features**:
- ✅ First tests Docker Hub direct connection
- ✅ If failed, automatically tests multiple Chinese registry mirrors
- ✅ Selects the fastest responding mirror
- ✅ Automatically configures Docker daemon

**Supported Mirrors**:
- Tencent Cloud: `mirror.ccs.tencentyun.com`
- Aliyun: `registry.cn-hangzhou.aliyuncs.com`
- NetEase: `hub-mirror.c.163.com`
- USTC: `docker.mirrors.ustc.edu.cn`

**Usage**:
```bash
# Kamal automatically calls during first setup
kamal setup

# Or manually run on server
.kamal/hooks/docker-setup
```

### 3. 🔐 SSH Key Auto-Management (`bin/kamal_ssh_setup`)

Automatically detects, generates, and injects SSH keys to servers.

**Features**:
- ✅ Checks for local SSH keys (prefers ed25519)
- ✅ Automatically generates new keys if not found
- ✅ Tests SSH connections to all servers
- ✅ Automatically injects public keys to failed servers
- ✅ Supports `ssh-copy-id` and `sshpass`
- ✅ Provides manual operation instructions

**Usage**:
```bash
# Run before first deployment
bin/kamal_ssh_setup

# Will automatically:
# 1. Check/generate SSH keys
# 2. Test all server connections
# 3. Inject public keys to unreachable servers
```

## 🚀 Quick Start

### First Deployment

```bash
# 1. Configure deploy.yml
vim config/deploy.yml

# 2. Setup SSH connection
bin/kamal_ssh_setup

# 3. Deploy application (automatically syncs env vars and configures Docker)
kamal setup
kamal deploy
```

### Subsequent Deployments

```bash
# One-command deployment (all features run automatically)
kamal deploy
```

## 📋 Hook Trigger Timing

Kamal automatically calls these hooks at the following times:

| Hook | Trigger Timing | Purpose |
|------|---------------|---------|
| `pre-deploy` | Before deployment starts | Sync environment variables |
| `pre-connect` | Before SSH connection | Verify SSH connection |
| `docker-setup` | During first setup | Configure Docker registry mirror |

## 🔧 Troubleshooting

### Environment Variable Sync Failed

```bash
# Check application.yml syntax
ruby -c config/application.yml

# Manually run sync to see detailed errors
bin/kamal_sync_env
```

### SSH Connection Failed

```bash
# Re-run SSH setup
bin/kamal_ssh_setup

# Manually test connection
ssh ubuntu@your-server-ip
```

### Docker Image Pull Slow

```bash
# Re-run docker-setup on server
ssh ubuntu@your-server-ip
sudo .kamal/hooks/docker-setup
```

## 📁 Generated Files

The following files are automatically generated and added to `.gitignore`:

- `.kamal/env_snapshot.yml` - Environment variable snapshot (for diff detection)
- `.kamal/ssh_setup_done` - SSH setup completion marker
- `.kamal/secrets` - Kamal secrets file

## 🔒 Security Notes

According to project configuration, all environment variables are stored as plaintext in the `env.clear` section of `config/deploy.yml`.

**Notes**:
- ⚠️ `deploy.yml` contains sensitive configuration, do not commit to public repositories
- ✅ Snapshot files are automatically excluded from version control
- ✅ SSH keys are only stored locally and on servers

## 💡 Tips

- After modifying `config/application.yml`, the next `kamal deploy` will automatically sync
- Use `bin/kamal_sync_env` to preview changes without deploying
- SSH setup usually only needs to run once, unless changing servers or keys
- Docker registry mirror configuration is automatically completed during first setup

## 📚 Related Documentation

- [Kamal Official Documentation](https://kamal-deploy.org/)
- [Kamal Hooks Documentation](https://kamal-deploy.org/docs/hooks)
