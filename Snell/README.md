 ## 使用方法：

安装
```
bash <(curl -fsSL https://raw.githubusercontent.com/EAlyce/conf/main/Snell/install_snell.sh)
```

卸载

```
bash <(curl -fsSL https://github.com/EAlyce/conf/raw/main/Snell/uninstall_snell.sh)
```


 ## 构建镜像：

```
cd /root/snell-docker && \
docker buildx build --network host --platform linux/386,linux/amd64,linux/arm/v7,linux/arm64 --no-cache -t azurelane/snell:latest --push . 2>&1 | tee /root/snell-docker/build.log
```


 ## 参考自：
 [ @vocrx](https://github.com/vocrx)
