## 使用方法：

###安装
```
bash <(curl -fsSL https://raw.githubusercontent.com/EAlyce/conf/main/Snell/install_snell.sh)
```
dev
```
bash <(curl -fsSL https://raw.githubusercontent.com/EAlyce/conf/main/Snell/install_snell_dev.sh)
```

###卸载

```
bash <(curl -fsSL https://github.com/EAlyce/conf/raw/main/Snell/deldocker.sh)
```


 ## 构建镜像：

```
mkdir -p /root/snell-docker
```
```
cd /root/snell-docker && \
curl -fsSL -o Dockerfile https://raw.githubusercontent.com/EAlyce/conf/main/Snell/Dockerfile && \
curl -fsSL -o entrypoint.sh https://raw.githubusercontent.com/EAlyce/conf/main/Snell/entrypoint.sh

```
```
sed -i 's/\r$//' entrypoint.sh
```
```
sed -i 's/\r$//' Dockerfile
```

```
docker buildx build --network host \
  --platform linux/386,linux/amd64,linux/arm/v7,linux/arm64 \
  --no-cache -t azurelane/snell:latest --push . \
  2>&1 | tee build.log

```


 ## 致谢：
 [ @vocrx](https://github.com/vocrx)
