# Kamal Deployment Enhancements

This project integrates three intelligent scripts to simplify the Kamal deployment process and automatically handle common deployment issues.

## 🎯 Core Features

### 1. Automatic Environment Variable Sync
- **Script**: `bin/kamal_sync_env`
- **Purpose**: Automatically syncs `config/application.yml` to `config/deploy.yml`
- **Trigger**: Runs automatically before each `kamal deploy`

### 2. Docker Registry Mirror Smart Detection
- **Script**: `.kamal/hooks/docker-setup`
- **Purpose**: Automatically tests and configures the fastest Docker registry mirror (Chinese mirrors)
- **Trigger**: Runs during first `kamal setup`

### 3. SSH Key Automation Management
- **Script**: `bin/kamal_ssh_setup`
- **Purpose**: Automatically detects, generates, and injects SSH keys
- **Trigger**: Needs to be run manually once

## 🚀 Usage Guide

### First Deployment Workflow

```bash
# Step 1: Configure deployment target
# Edit config/deploy.yml, set server addresses and configuration
vim config/deploy.yml

# Step 2: Setup SSH connection (run once)
bin/kamal_ssh_setup
# Will automatically:
# - Check/generate SSH keys
# - Test server connections
# - Inject public keys to servers

# Step 3: First deployment
kamal setup
# Will automatically:
# - Configure Docker registry mirror on server
# - Sync environment variables
# - Deploy application

# Step 4: Subsequent deployments
kamal deploy
# Will automatically sync environment variables and deploy
```

### Daily Deployment Workflow

```bash
# After code changes, deploy directly
kamal deploy

# Environment variables will sync automatically, no manual configuration needed
```

## 📝 Detailed Explanation

### Environment Variable Sync How It Works

1. Reads all key-value pairs from `config/application.yml`
2. Parses ERB templates (e.g., `<%= ENV.fetch(...) %>`)
3. Compares with last snapshot, displays differences
4. Updates `env.clear` section of `config/deploy.yml` after confirmation

**Example Output**:
```
🔄 Kamal Environment Sync
============================================================
📊 Changes detected:

  ➕ Added (2):
     LLM_MODEL: gemini-2.5-flash
     IMAGE_GEN_SIZE: 1024x1024

  🔄 Modified (1):
     PUBLIC_HOST:
       - old.example.com
       + app.example.com

❓ Apply these changes to config/deploy.yml? [y/N]
```

### Docker Registry Mirror Detection Process

1. First tests Docker Hub direct connection (10-second timeout)
2. If failed, sequentially tests Chinese mirrors:
   - Tencent Cloud
   - Aliyun
   - NetEase
   - USTC
3. Selects the fastest responding mirror
4. Automatically configures `/etc/docker/daemon.json`

**Example Output**:
```
🐳 Docker Setup for Kamal Deployment
==================================================
🔍 Testing Docker Hub connectivity...
❌ Docker Hub is not accessible or too slow
🔄 Testing Chinese registry mirrors...

Testing Tencent Cloud (https://mirror.ccs.tencentyun.com)...
  ✅ Success - 1234ms
Testing Aliyun (https://registry.cn-hangzhou.aliyuncs.com)...
  ✅ Success - 2345ms

🏆 Best mirror: Tencent Cloud (1234ms)
✅ Docker registry mirror configured successfully
```

### SSH Key Setup Process

1. Checks for local SSH keys (prefers `~/.ssh/id_ed25519`)
2. If not found, automatically generates new key
3. Tests each server connection
4. For unreachable servers:
   - Prompts for password
   - Uses `ssh-copy-id` to inject public key
5. Creates marker file `.kamal/ssh_setup_done`

**Example Output**:
```
🔐 Kamal SSH Setup
============================================================
📋 Configuration:
   Servers: 43.139.83.103
   SSH User: ubuntu

🔍 Testing SSH connections...
   ✗ 43.139.83.103 - Failed

⚠️  Failed to connect to 1 server(s)
📤 Will attempt to inject SSH public key...

📤 Setting up SSH key for 43.139.83.103
   Enter password for ubuntu@43.139.83.103: ********
   ✅ Public key injected successfully

✅ SSH setup completed successfully!
```

## 🔧 Troubleshooting

### Issue: Environment Variables Not Syncing

**Solution**:
```bash
# Manually run sync script to see detailed information
bin/kamal_sync_env

# Check application.yml syntax
ruby -c config/application.yml
```

### Issue: SSH Connection Failed

**Solution**:
```bash
# Re-run SSH setup
bin/kamal_ssh_setup

# Manually test connection
ssh ubuntu@your-server-ip

# If still failing, check:
# 1. Is server online
# 2. Is firewall allowing SSH (port 22)
# 3. Is SSH service running
```

### Issue: Docker Image Pull Slow

**Solution**:
```bash
# SSH to server
ssh ubuntu@your-server-ip

# Re-run mirror detection
sudo /app/.kamal/hooks/docker-setup

# Or manually configure mirror
sudo vim /etc/docker/daemon.json
sudo systemctl restart docker
```

## 📁 Related Files

### Script Files
- `bin/kamal_sync_env` - Environment variable sync script
- `bin/kamal_ssh_setup` - SSH key setup script
- `.kamal/hooks/docker-setup` - Docker registry mirror configuration
- `.kamal/hooks/pre-deploy` - Pre-deploy hook (calls env sync)
- `.kamal/hooks/pre-connect` - Pre-connect hook (verifies SSH)

### Configuration Files
- `config/deploy.yml` - Kamal deployment configuration (automatically updated)
- `config/application.yml` - Application environment variables (source file)

### Generated Files (in .gitignore)
- `.kamal/env_snapshot.yml` - Environment variable snapshot
- `.kamal/ssh_setup_done` - SSH setup marker
- `.kamal/secrets` - Kamal secrets

## 🔒 Security Considerations

1. **Plaintext Storage**: All environment variables are stored as plaintext in `env.clear` section of `config/deploy.yml`
2. **Version Control**: 
   - ✅ `config/application.yml` is in `.gitignore`
   - ✅ `.kamal/env_snapshot.yml` is in `.gitignore`
   - ⚠️ Do not commit `config/deploy.yml` to public repositories
3. **SSH Keys**: Private keys are only stored locally in `~/.ssh/`, public keys stored on servers in `~/.ssh/authorized_keys`

## 📚 More Information

For detailed documentation, see: `.kamal/README.md`

Kamal Official Documentation: https://kamal-deploy.org/
