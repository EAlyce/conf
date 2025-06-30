![20250630_205417](https://github.com/user-attachments/assets/cea2aeb3-2e25-4f3e-a793-d80d67de37d3) ## 使用方法：

安装
```
bash <(curl -fsSL https://raw.githubusercontent.com/EAlyce/conf/main/Snell/install_snell.sh)
```
dev
```
bash <(curl -fsSL https://raw.githubusercontent.com/EAlyce/conf/main/Snell/install_snell_dev.sh)
```

卸载

```
bash <(curl -fsSL https://github.com/EAlyce/conf/raw/main/Snell/deldocker.sh)
```


 ## 构建镜像：

```
cd /root/snell-docker && \
curl -fsSL -o Dockerfile https://raw.githubusercontent.com/EAlyce/conf/main/Snell/Dockerfile && \
sed -i 's/; fi;/esac;/' Dockerfile && \
curl -fsSL -o entrypoint.sh https://raw.githubusercontent.com/EAlyce/conf/main/Snell/entrypoint.sh && \
chmod +x entrypoint.sh && \
docker buildx build --network host --platform linux/386,linux/amd64,linux/arm/v7,linux/arm64 --no-cache -t azurelane/snell:latest --push . 2>&1 | tee build.log

```


 ## 致谢：
 [ @vocrx](https://github.com/vocrx)
