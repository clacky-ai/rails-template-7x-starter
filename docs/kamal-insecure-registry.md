# Kamal Insecure/HTTP Registry Support

## 问题

当使用 Kamal 向只支持 HTTP 的 Docker registry 推送镜像时，BuildKit 会报错：

```
http: server gave HTTP response to HTTPS client
```

这是因为 BuildKit 默认只允许 HTTPS 连接，需要显式配置才能允许 HTTP。

## 解决方案

使用 monkey patch 为 Kamal 添加自定义 builder 名称支持，配合远程主机上的 BuildKit 配置文件。

### 架构

- **本地机器**: 运行 `bin/kamal` 命令
- **远程构建主机**: 运行 BuildKit 容器和 Docker registry
- **Registry**: HTTP-only registry (例如 `172.17.0.1:5000`)

## 快速开始

### 方式 1: 一键配置（推荐）

```bash
bin/setup-kamal-insecure-registry \
  --host 139.199.178.175 \
  --user ubuntu \
  --password your-password \
  --registry 172.17.0.1:5000
```

这个脚本会自动完成所有配置，包括：
- SSH 密钥配置
- 远程主机上创建 BuildKit 配置
- 更新本地配置文件
- 创建并配置 builder

### 方式 2: 手动配置

#### 步骤 1: 准备远程主机

```bash
ssh ubuntu@139.199.178.175

# 创建 BuildKit 配置目录
sudo mkdir -p /etc/buildkit

# 创建 insecure registry 配置文件
sudo tee /etc/buildkit/buildkitd.toml <<EOF
[registry."172.17.0.1:5000"]
  http = true
  insecure = true
EOF
```

#### 步骤 2: 配置 Kamal

编辑 `config/deploy.yml`:

```yaml
registry:
  server: 172.17.0.1:5000
  username: docker-registry
  password:
    - KAMAL_REGISTRY_PASSWORD

builder:
  remote: ssh://ubuntu@139.199.178.175
  name: my-insecure-builder  # 自定义 builder 名称
  local: false
  arch: amd64
```

#### 步骤 3: 创建 Builder

```bash
# 1. 创建 builder（会创建不带配置的 BuildKit 容器）
bin/kamal build create

# 2. 重新创建 BuildKit 容器并挂载配置
.kamal/scripts/recreate-buildkit-container.sh
```

## 使用

### 首次创建后

```bash
# 构建并推送镜像
bin/kamal build push

# 完整部署
bin/kamal deploy
```

### 删除 Builder 后

如果你用 `bin/kamal build remove` 删除了 builder，需要重新创建：

```bash
bin/kamal build create
.kamal/scripts/recreate-buildkit-container.sh
```

## 工作原理

### 1. Monkey Patches

三个最小化的 Ruby monkey patch 扩展 Kamal 功能：

#### `lib/kamal_patches/configuration_builder_patch.rb`
添加 `custom_name` 方法读取 `builder.name` 配置：
```ruby
def custom_name
  builder_config["name"]
end
```

#### `lib/kamal_patches/commands_builder_remote_patch.rb`
覆盖 `builder_name` 方法使用自定义名称：
```ruby
def builder_name
  config.builder.custom_name || default_builder_name
end
```

#### `lib/kamal_patches/configuration_docs_builder_patch.rb`
绕过 Kamal 配置验证器，允许 `builder.name` 字段。

#### `lib/kamal_patches.rb`
按正确顺序加载所有 patches。

### 2. Wrapper 脚本

`bin/kamal` 是一个包装脚本：
1. 加载 Kamal gem
2. 加载 monkey patches
3. 执行 Kamal 命令

使用方法：
```bash
# 替代: kamal build push
bin/kamal build push

# 替代: kamal deploy
bin/kamal deploy
```

### 3. BuildKit 容器重建

`.kamal/scripts/recreate-buildkit-container.sh` 脚本：
1. 从 `config/deploy.yml` 读取配置
2. 连接到远程服务器
3. 停止并删除现有的 BuildKit 容器
4. 重新创建容器，挂载 `/etc/buildkit/buildkitd.toml` 配置文件
5. 验证配置文件在容器中可访问

脚本会动态读取配置，无需硬编码服务器信息。

### 4. BuildKit 配置

`/etc/buildkit/buildkitd.toml` 文件告诉 BuildKit：
- 允许 HTTP 连接到指定 registry
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
ssh ubuntu@139.199.178.175 "curl -s http://172.17.0.1:5000/v2/_catalog"
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

1. **零 gem 修改**: 所有更改都在项目文件中
2. **版本控制**: Patches 和配置是仓库的一部分
3. **无 sudo 自动化**: BuildKit 配置手动设置一次
4. **灵活**: 适用于任何 BuildKit 配置，不仅限于 insecure registries
5. **清晰分离**: BuildKit 配置独立于 Kamal 配置
6. **易维护**: 简单的 patches，容易更新以适配新版本 Kamal
7. **动态配置**: 所有脚本从 `config/deploy.yml` 动态读取配置，无硬编码

## 相关文件

### 创建/修改的文件
- `lib/kamal_patches.rb` - Patch 加载器
- `lib/kamal_patches/configuration_builder_patch.rb` - 自定义名称支持
- `lib/kamal_patches/commands_builder_remote_patch.rb` - Builder 名称覆盖
- `lib/kamal_patches/configuration_docs_builder_patch.rb` - 验证器绕过
- `bin/kamal` - 包装脚本
- `bin/setup-kamal-insecure-registry` - 一键配置脚本
- `.kamal/scripts/recreate-buildkit-container.sh` - 辅助脚本
- `config/deploy.yml` - 添加 `builder.name` 配置

## 向上游贡献

如果这个功能有用，可以考虑向官方 Kamal 仓库提交 PR：https://github.com/basecamp/kamal

这里的实现可以作为概念验证。
