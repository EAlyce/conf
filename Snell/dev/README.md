```
mkdir -p /root/snell-docker && cd /root/snell-docker
```
```
docker buildx build --platform linux/386,linux/amd64,linux/arm/v7,linux/arm64 -t azurelane/snell:latest --push .
```
