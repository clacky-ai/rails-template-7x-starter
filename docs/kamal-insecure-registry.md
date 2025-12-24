# Kamal Insecure/HTTP Registry Support

## 问题

当使用 Kamal 向只支持 HTTP 的 Docker registry 推送镜像时，BuildKit 会报错：

```
http: server gave HTTP response to HTTPS client
```

这是因为 BuildKit 默认只允许 HTTPS 连接，需要显式配置才能允许 HTTP。

## 解决方案

配置远程主机上的 BuildKit 支持 HTTP registry，然后使用辅助脚本重建 BuildKit 容器并挂载配置文件。

### 架构

- **本地机器**: 运行 `kamal` 命令
- **远程构建主机**: 运行 BuildKit 容器和 Docker registry
- **Registry**: HTTP-only registry (推荐使用公网 IP，如 `139.199.178.175:5000`)

## 快速开始

### 步骤 1: 设置 Docker Registry（新机器）

如果远程服务器还没有 Docker registry，先运行：

```bash
# 安装 Docker 并创建 registry
bin/setup-docker-registry \
  --host 139.199.178.175 \
  --user ubuntu \
  --password your-password
```

这个脚本会：
- 检查并安装 Docker（如果未安装）
- 创建 Docker registry 容器
- 配置持久化存储
- 返回 registry 地址（推荐使用公网 IP：`139.199.178.175:5000`）

**已有 registry？** 跳过此步骤，直接使用现有 registry 地址。

**Registry 地址选择：**
- ✅ **推荐**：使用公网 IP（如 `139.199.178.175:5000`）- 更通用，性能相同
- ⚠️ 不推荐：使用 Docker bridge IP（`172.17.0.1:5000`）- 仅限同机器

### 步骤 2: 配置 Kamal 支持 HTTP Registry（一键配置）

使用上一步返回的 registry 地址：

```bash
bin/setup-kamal-insecure-registry \
  --host 139.199.178.175 \
  --user ubuntu \
  --password your-password \
  --registry 139.199.178.175:5000
```

这个脚本会自动完成所有配置，包括：
- SSH 密钥配置
- 远程主机上创建 BuildKit 配置
- 更新本地配置文件
- 创建并配置 builder

### 方式 2: 手动配置

#### 步骤 1: 设置 Docker Registry（如果还没有）

```bash
ssh ubuntu@139.199.178.175

# 安装 Docker（如果未安装）
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# 创建 registry 容器
docker volume create registry-data
docker run -d \
  --name registry \
  --restart=unless-stopped \
  -p 5000:5000 \
  -v registry-data:/var/lib/registry \
  registry:2

# 获取服务器公网 IP 作为 registry 地址
# 例如: 139.199.178.175:5000
# 推荐使用公网 IP 而不是 Docker bridge IP (172.17.0.1)
# 因为公网 IP 更通用且性能相同（内核自动路由优化）
```

#### 步骤 2: 配置 BuildKit 支持 HTTP Registry

```bash
ssh ubuntu@139.199.178.175

# 创建 BuildKit 配置目录
sudo mkdir -p /etc/buildkit

# 创建 insecure registry 配置文件
# 使用服务器公网 IP
sudo tee /etc/buildkit/buildkitd.toml <<EOF
[registry."139.199.178.175:5000"]
  http = true
  insecure = true
EOF
```

#### 步骤 3: 配置 Kamal

编辑 `config/deploy.yml`:

```yaml
registry:
  server: 139.199.178.175:5000
  username: docker-registry
  password:
    - KAMAL_REGISTRY_PASSWORD

builder:
  remote: ssh://ubuntu@139.199.178.175
  local: false
  arch: amd64
```

#### 步骤 4: 创建 Builder

```bash
# 1. 创建 builder（会创建不带配置的 BuildKit 容器）
kamal build create

# 2. 重新创建 BuildKit 容器并挂载配置
.kamal/scripts/recreate-buildkit-container.sh
```

## 使用

### 首次创建后

```bash
# 构建并推送镜像
kamal build push

# 完整部署
kamal deploy
```

### 删除 Builder 后

如果你用 `kamal build remove` 删除了 builder，需要重新创建：

```bash
kamal build create
.kamal/scripts/recreate-buildkit-container.sh
```

## 工作原理

### 1. Kamal 默认命名

Kamal 根据 `builder.remote` 自动生成 builder 名称：

```ruby
# builder_name = "kamal-remote-#{remote.gsub(/[^a-z0-9_-]/, "-")}"
# 例如: ssh://ubuntu@139.199.178.175
# 生成: kamal-remote-ssh---ubuntu-139-199-178-175
```

### 2. BuildKit 容器重建

`.kamal/scripts/recreate-buildkit-container.sh` 脚本：
1. 从 `config/deploy.yml` 读取 `builder.remote`
2. 自动计算 Kamal 默认的 builder 名称
3. 连接到远程服务器
4. 停止并删除现有的 BuildKit 容器
5. 重新创建容器，挂载 `/etc/buildkit/buildkitd.toml` 配置文件
6. 验证配置文件在容器中可访问

**优点**：
- 零代码修改，只使用 Kamal 原生功能
- 配置动态读取，无需硬编码
- IP 或用户名变更时，重新运行脚本即可

### 3. BuildKit 配置

`/etc/buildkit/buildkitd.toml` 文件告诉 BuildKit：
- 允许 HTTP 连接到指定 registry（推荐使用公网 IP）
- 信任该 registry，不进行 TLS 验证

## 验证

### 检查 BuildKit 容器运行状态

```bash
ssh ubuntu@139.199.178.175

# 检查容器运行状态
docker ps --filter name=buildx_buildkit

# 验证配置文件已挂载
docker exec buildx_buildkit_my-insecure-builder0 cat /etc/buildkit/buildkitd.toml
```

### 测试推送到 Registry

```bash
# 构建并推送
bin/kamal build push

# 验证镜像在 registry 中
ssh ubuntu@139.199.178.175 "curl -s http://139.199.178.175:5000/v2/_catalog"
```

## 故障排查

### 错误: "http: server gave HTTP response to HTTPS client"

BuildKit 容器没有挂载配置文件，运行：
```bash
.kamal/scripts/recreate-buildkit-container.sh
```

### 错误: "No such file or directory" 重建容器时

远程主机上不存在 `/etc/buildkit/buildkitd.toml` 文件，完成步骤 1 的一次性设置。

### Builder 未找到

先创建 builder：
```bash
bin/kamal build create
.kamal/scripts/recreate-buildkit-container.sh
```

### 错误: 找不到 config/deploy.yml

确保在项目根目录运行脚本。

### 错误: SSH 连接失败

检查 SSH 配置：
```bash
# 测试连接
ssh ubuntu@139.199.178.175

# 检查 deploy.yml 中的 builder.remote 配置
cat config/deploy.yml | grep -A 5 builder
```

## 优势

1. **零代码修改**: 只使用 Kamal 原生功能，无需 monkey patch
2. **版本控制**: 配置和脚本是仓库的一部分
3. **无 sudo 自动化**: BuildKit 配置手动设置一次
4. **灵活**: 适用于任何 BuildKit 配置，不仅限于 insecure registries
5. **清晰分离**: BuildKit 配置独立于 Kamal 配置
6. **易维护**: Kamal 升级无影响
7. **动态配置**: 所有脚本从 `config/deploy.yml` 动态读取配置，无硬编码
8. **公网 IP**: 使用公网 IP 而不是 Docker bridge IP，更通用且性能相同

## 相关文件

### 创建的文件
- `bin/setup-docker-registry` - Docker registry 设置脚本
- `bin/setup-kamal-insecure-registry` - 一键配置脚本
- `.kamal/scripts/recreate-buildkit-container.sh` - BuildKit 容器重建脚本

### 修改的文件
- `config/deploy.yml` - 配置 registry 和 builder 信息

### 远程服务器文件
- `/etc/buildkit/buildkitd.toml` - BuildKit insecure registry 配置
