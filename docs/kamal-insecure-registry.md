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
.kamal/scripts/setup-docker-registry \
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
- ✅ **单服务器部署**：使用 Docker bridge IP（`172.17.0.1:5000`）- 所有流量保持本地，最快
- ✅ **多服务器部署**：使用公网 IP（如 `139.199.178.175:5000`）- 其他服务器也能访问

**关于 Docker bridge IP 的稳定性：**

`172.17.0.1` 是 Docker 的默认 bridge 网关，稳定性评级 ⭐⭐⭐⭐ (4/5)：
- ✓ Docker 官方默认值，自早期版本至今未变
- ✓ 所有 Linux 发行版一致
- ✓ 不受 Docker 版本影响（测试到 29.x）
- ⚠️ 用户可在 `/etc/docker/daemon.json` 中修改 `bip` 参数（罕见）

**验证你的 bridge IP：**
```bash
ssh ubuntu@139.199.178.175 "docker network inspect bridge --format '{{(index .IPAM.Config 0).Gateway}}'"
# 应该输出: 172.17.0.1
```

如果输出不是 `172.17.0.1`，请在配置中使用实际输出的 IP。

**重要**：如果使用公网 IP，Docker pull 可能会通过网络路由而不是本地回环，导致速度变慢（2-3 分钟）。这是因为云服务器的公网 IP 通常是 NAT 映射，内核会将流量路由到网关。检查方法：
```bash
ssh ubuntu@139.199.178.175 "ip route get 139.199.178.175"
# 如果看到 "via <gateway>" 说明会走网络，应改用 Docker bridge IP
```

### 步骤 2: 配置 Kamal 支持 HTTP Registry（一键配置）

使用上一步返回的 registry 地址：

```bash
.kamal/scripts/setup-kamal-insecure-registry \
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

# 获取 registry 地址
# 单服务器部署：推荐使用 Docker bridge IP (172.17.0.1:5000) - 最快
# 多服务器部署：使用公网 IP (例如: 139.199.178.175:5000) - 支持远程访问
#
# 注意：云服务器的公网 IP 通常是 NAT 映射，访问自己的公网 IP 会通过网络路由，
# 导致 Docker pull 变慢（2-3 分钟）。单服务器部署时必须使用 Docker bridge IP。
#
# 验证 Docker bridge IP（通常是 172.17.0.1，除非自定义配置）：
# docker network inspect bridge --format '{{(index .IPAM.Config 0).Gateway}}'
```

#### 步骤 2: 配置 BuildKit 支持 HTTP Registry

```bash
ssh ubuntu@139.199.178.175

# 创建 BuildKit 配置目录
sudo mkdir -p /etc/buildkit

# 创建 insecure registry 配置文件
# 注意：使用与 deploy.yml 中相同的 registry 地址
# 单服务器部署：使用 172.17.0.1:5000 (Docker bridge IP)
# 多服务器部署：使用公网 IP
sudo tee /etc/buildkit/buildkitd.toml <<EOF
[registry."172.17.0.1:5000"]
  http = true
  insecure = true
EOF
```

#### 步骤 3: 配置 Kamal

编辑 `config/deploy.yml`:

```yaml
registry:
  server: 172.17.0.1:5000  # 单服务器部署使用 bridge IP，多服务器使用公网 IP
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
- 允许 HTTP 连接到指定 registry
- 信任该 registry，不进行 TLS 验证
- **注意**：单服务器部署使用 Docker bridge IP（172.17.0.1），多服务器部署使用公网 IP

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

# 验证镜像在 registry 中（使用 Docker bridge IP）
ssh ubuntu@139.199.178.175 "curl -s http://172.17.0.1:5000/v2/_catalog"
```

## 故障排查

### 错误: Docker pull 非常慢（2-3 分钟）

**症状**: 从 registry pull 镜像花费 2-3 分钟，即使 registry 和应用在同一服务器。

**原因**: 使用公网 IP 作为 registry 地址时，云服务器的公网 IP 是 NAT 映射，Docker 会通过网关路由流量，而不是本地回环。

**检查方法**:
```bash
ssh ubuntu@139.199.178.175 "ip route get 139.199.178.175"
# 如果输出包含 "via <gateway>" 说明流量会走网络
```

**解决方案**:
- **单服务器部署**: 改用 Docker bridge IP（`172.17.0.1:5000`）
- **多服务器部署**: 必须使用公网 IP，接受较慢的速度或使用内网 IP

步骤：
1. 更新 `/etc/buildkit/buildkitd.toml` 中的 registry 地址为 `172.17.0.1:5000`
2. 更新 `config/deploy.yml` 中的 `registry.server` 为 `172.17.0.1:5000`
3. 重新创建 BuildKit 容器：`.kamal/scripts/recreate-buildkit-container.sh`

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
8. **性能优化**: 支持 Docker bridge IP（单服务器）和公网 IP（多服务器）两种模式

## 相关文件

### 创建的文件
- `.kamal/scripts/setup-docker-registry` - Docker registry 设置脚本
- `.kamal/scripts/setup-kamal-insecure-registry` - 一键配置脚本
- `.kamal/scripts/recreate-buildkit-container.sh` - BuildKit 容器重建脚本

### 修改的文件
- `config/deploy.yml` - 配置 registry 和 builder 信息

### 远程服务器文件
- `/etc/buildkit/buildkitd.toml` - BuildKit insecure registry 配置
