# Kamal Deployment Enhancement Scripts

This project's Kamal deployment tool includes three intelligent enhancement features that automate common deployment issues, plus bundle mirror configuration for faster builds.

## 🎯 Feature Overview

### 1. 📦 Smart Environment Variable Sync (`bin/kamal_sync_env`)

Automatically syncs environment variables from `config/application.yml` to `config/deploy.yml`.

**Features**:
- ✅ Automatic ERB template parsing
- ✅ Intelligent diff detection (added, modified, deleted)
- ✅ Interactive change confirmation
- ✅ Preserves deploy.yml comments and formatting
- ✅ All values stored as plaintext in `env.clear`

**Execution**: Runs on **local machine** via `pre-deploy` hook

**Usage**:
```bash
# Run sync manually
bin/kamal_sync_env

# Automatic integration: runs before every kamal deploy
```

### 2. 🐳 Docker Registry Mirror Auto-Detection (`.kamal/hooks/docker-setup`)

Automatically detects and configures the fastest Docker registry mirror on remote servers.

**Features**:
- ✅ First tests Docker Hub direct connection
- ✅ If failed, automatically tests multiple Chinese registry mirrors
- ✅ Selects the fastest responding mirror
- ✅ Automatically configures Docker daemon on remote servers

**Execution**: Runs on **local machine**, executes commands on **remote servers** via SSH

**Supported Mirrors**:
- Tencent Cloud: `mirror.ccs.tencentyun.com`
- Aliyun: `registry.cn-hangzhou.aliyuncs.com`
- NetEase: `hub-mirror.c.163.com`
- USTC: `docker.mirrors.ustc.edu.cn`

**Usage**:
```bash
# Kamal automatically calls during first setup
kamal setup

# The hook runs locally but configures Docker on remote servers
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

**Execution**: Runs on **local machine**

**Usage**:
```bash
# Run before first deployment
bin/kamal_ssh_setup

# Will automatically:
# 1. Check/generate SSH keys
# 2. Test all server connections
# 3. Inject public keys to unreachable servers
```

### 4. 🚀 Bundle Mirror for Faster Builds (Dockerfile + `config/deploy.yml`)

Automatically uses Tsinghua RubyGems mirror during Docker builds for faster gem installation.

**Features**:
- ✅ 3-5x faster gem installation (China networks)
- ✅ Configurable via build arguments
- ✅ Only affects build time, not runtime
- ✅ Easy to enable/disable

**Execution**: During **Docker image build**

**Usage**:
```bash
# Normal deployment (uses mirror automatically)
kamal deploy

# Disable mirror if needed
KAMAL_USE_CHINA_MIRROR=false kamal deploy
```

**Documentation**: See [BUNDLE_MIRROR.md](./BUNDLE_MIRROR.md) for details

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

## 📋 Hook Execution Model

All Kamal hooks run on the **local machine**, not on remote servers. Here's how our scripts handle this:

| Hook | Runs On | What It Does |
|------|---------|--------------|
| `pre-deploy` | Local | Syncs environment variables locally in `config/deploy.yml` |
| `pre-connect` | Local | Tests SSH connection from local machine to servers |
| `docker-setup` | Local | **Executes remote commands via SSH** to configure Docker on servers |

**Important**: The `docker-setup` hook runs locally but sends commands to remote servers via SSH. It:
1. Detects the target server from `$KAMAL_HOSTS` environment variable
2. Creates a setup script
3. Executes the script on the remote server via `ssh`
4. Reports results back to local terminal

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

The `docker-setup` hook should automatically configure mirrors during `kamal setup`. If you need to reconfigure:

```bash
# Manually trigger docker-setup for a specific host
KAMAL_HOSTS=your-server-ip KAMAL_SSH_USER=ubuntu .kamal/hooks/docker-setup

# Or SSH to server and configure manually
ssh ubuntu@your-server-ip
sudo vim /etc/docker/daemon.json
sudo systemctl restart docker
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
- ✅ All hooks run locally - no scripts are permanently stored on remote servers

## 💡 Tips

- After modifying `config/application.yml`, the next `kamal deploy` will automatically sync
- Use `bin/kamal_sync_env` to preview changes without deploying
- SSH setup usually only needs to run once, unless changing servers or keys
- Docker registry mirror configuration happens automatically during first `kamal setup`
- All hooks run on your local machine with proper SSH credentials

## 🔍 How Kamal Hooks Work

Kamal hooks are shell scripts that run on your **local development machine** at specific points in the deployment process:

- **Local execution**: All hooks run locally, not on servers
- **SSH access**: Scripts can execute commands on servers via SSH
- **Environment variables**: Kamal provides variables like `$KAMAL_HOSTS`, `$KAMAL_ROLE`, etc.
- **Exit codes**: Non-zero exit codes can stop deployment (our docker-setup uses `exit 0` to continue even on failure)

## 📚 Related Documentation

- [Insecure/HTTP Registry Support](../docs/kamal-insecure-registry.md)
- [Kamal Official Documentation](https://kamal-deploy.org/)
- [Kamal Hooks Documentation](https://kamal-deploy.org/docs/hooks)
