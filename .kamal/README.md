# Kamal Deployment Enhancement Scripts

This project's Kamal deployment tool includes three intelligent enhancement features that automate common deployment issues, plus bundle mirror configuration for faster builds.

## 🎯 Feature Overview

### 1. 📦 Smart Environment Variable Sync (`.kamal/scripts/kamal_sync_env`)

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
.kamal/scripts/kamal_sync_env

# Automatic integration: runs before every kamal deploy
```

### 2. 🐳 Docker Registry Mirror Auto-Detection

Automatically detects and configures the fastest Docker registry mirror on remote servers.

**Features**:
- ✅ Tests multiple registry mirrors with actual response time
- ✅ Selects the fastest responding mirror automatically
- ✅ Configures Docker daemon with the best mirror
- ✅ Falls back to Docker Hub if all mirrors fail
- ✅ Integrated into both manual setup and Kamal hooks
- ✅ China mirror support for Docker installation (Aliyun, Tencent)
- ✅ Silent error handling for container environments

**Execution**: Runs on **local machine**, executes commands on **remote servers** via SSH

**Supported Mirrors**:
- Docker Hub Direct: `registry-1.docker.io`
- Tencent Cloud: `mirror.ccs.tencentyun.com`
- DockerProxy: `dockerproxy.com`
- USTC: `docker.mirrors.ustc.edu.cn`
- NetEase: `hub-mirror.c.163.com`

**Docker Installation Mirrors** (for China network):
- Aliyun: `mirrors.aliyun.com/docker-ce`
- Tencent: `mirrors.tencent.com/docker-ce`
- Docker Official: `download.docker.com` (fallback)

**Integration**:
- Integrated into `.kamal/scripts/setup-docker-registry` (Step 3)
- Runs during manual Docker registry setup
- Configures mirror before pulling registry image
- Prevents slow downloads when setting up registry
- Works in all environments (containers, VMs, bare metal)

**Usage**:
```bash
# Automatically runs during registry setup
.kamal/scripts/setup-docker-registry --host <IP> --user <USER>
```

### 3. 🚀 Bundle Mirror for Faster Builds (Dockerfile + `config/deploy.yml`)

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

# 2. Setup SSH keys (if needed)
ssh-keygen -t ed25519
ssh-copy-id user@host

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

All Kamal hooks run on the **local machine**, not on remote servers. Current hooks:

| Hook | Runs On | What It Does |
|------|---------|--------------|
| `pre-deploy` | Local | Syncs environment variables locally in `config/deploy.yml` |

**Important**: All hooks run on your local machine. Scripts can execute commands on remote servers via SSH when needed.

## 🔧 Troubleshooting

### Environment Variable Sync Failed

```bash
# Check application.yml syntax
ruby -c config/application.yml

# Manually run sync to see detailed errors
.kamal/scripts/kamal_sync_env
```

### SSH Connection Failed

```bash
# Setup SSH keys manually
ssh-keygen -t ed25519
ssh-copy-id ubuntu@your-server-ip

# Test connection
ssh ubuntu@your-server-ip
```

### Docker Installation Issues

#### Systemd Error in Containers

If you see this error during Docker installation:
```
System has not been booted with systemd as init system (PID 1). Can't operate.
Failed to connect to bus: Host is down
invoke-rc.d: policy-rc.d denied execution of start.
```

**Root Cause**: When installing Docker packages, the Debian/Ubuntu package manager automatically tries to start services using systemd. In container environments (without systemd), this causes errors.

**Solution**: The script now silently filters out these harmless error messages during installation. The installation completes successfully, and the error messages are hidden from output. This approach is simple and works in all environments (containers, VMs, bare metal).

#### GPG Key Download Failed (China Network)

If you see repeated GPG key download failures:
```
curl: (35) Recv failure: Connection reset by peer
⚠ GPG key import failed, retrying (1/3)...
```

**Solution**: The script now automatically tries China mirrors (Aliyun, Tencent) before falling back to Docker official sources. The retry logic will attempt multiple sources:

1. Aliyun Mirror: `mirrors.aliyun.com/docker-ce`
2. Tencent Mirror: `mirrors.tencent.com/docker-ce`
3. Docker Official: `download.docker.com`

If all sources fail, check your network connection and firewall settings.

### Docker Image Pull Slow

Docker registry mirrors are automatically configured when you run `.kamal/scripts/setup-docker-registry`. If you need to reconfigure:

```bash
# SSH to server and configure manually
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
- Use `.kamal/scripts/kamal_sync_env` to preview changes without deploying
- SSH keys setup usually only needs to be done once per server
- Docker registry mirror configuration happens automatically during `.kamal/scripts/setup-docker-registry`
- All hooks run on your local machine with proper SSH credentials

## 🔍 How Kamal Hooks Work

Kamal hooks are shell scripts that run on your **local development machine** at specific points in the deployment process:

- **Local execution**: All hooks run locally, not on servers
- **SSH access**: Scripts can execute commands on servers via SSH
- **Environment variables**: Kamal provides variables like `$KAMAL_HOSTS`, `$KAMAL_ROLE`, etc.
- **Exit codes**: Non-zero exit codes can stop deployment

## 📚 Related Documentation

- [Insecure/HTTP Registry Support](../docs/kamal-insecure-registry.md) - Setup Docker registry and configure Kamal for HTTP registries
- [Kamal Official Documentation](https://kamal-deploy.org/)
- [Kamal Hooks Documentation](https://kamal-deploy.org/docs/hooks)

## 🐳 Additional Tools

### Docker Registry Setup

If you need to set up a Docker registry on a remote server:

```bash
# Install Docker and create registry (for new servers)
.kamal/scripts/setup-docker-registry \
  --host 139.199.178.175 \
  --user ubuntu \
  --password your-password
```

This is useful when:
- You want a private registry for your images
- You need HTTP registry support (for internal networks)
- You're setting up a build server from scratch

See [Insecure/HTTP Registry Support](../docs/kamal-insecure-registry.md) for complete setup guide.
