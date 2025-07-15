# 🚀 Snell 安装与使用指南

## 🌐 官网链接

👉 [点击前往 Snell 官方文档](https://kb.nssurge.com/surge-knowledge-base/zh/release-notes/snell)

---

## 🛠 使用方法

### ✅ 快速安装（推荐）

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/EAlyce/conf/main/Snell/install_snell.sh)
```

### ⚠️ 实验性安装（不推荐）

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/EAlyce/conf/main/Snell/install_snell_dev.sh)
```

### 🧹 卸载 Snell

```bash
bash <(curl -fsSL https://github.com/EAlyce/conf/raw/main/Snell/deldocker.sh)
```

---

## 🧱 构建 Snell 镜像（Docker）

```bash
# 创建工作目录
mkdir -p /root/snell-docker
cd /root/snell-docker
```

```bash
# 下载 Dockerfile 和启动脚本
curl -fsSL -o Dockerfile https://raw.githubusercontent.com/EAlyce/conf/main/Snell/Dockerfile
curl -fsSL -o entrypoint.sh https://raw.githubusercontent.com/EAlyce/conf/main/Snell/entrypoint.sh
```

```bash
# 修正换行符（防止在 Linux 下执行报错）
sed -i 's/\r$//' entrypoint.sh
sed -i 's/\r$//' Dockerfile
```

```bash
# 构建多平台镜像并推送到 Docker Hub
docker buildx build --network host \
  --platform linux/386,linux/amd64,linux/arm/v7,linux/arm64 \
  --no-cache -t azurelane/snell:latest --push . \
  2>&1 | tee build.log
```

---

## 🙏 致谢

- 感谢 [@vocrx](https://github.com/vocrx)
