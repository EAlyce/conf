function operator(proxies, targetPlatform) {
    const fingerprint = "fd:65:e5:8d:9c:c4:fa:7e:c8:65:6a:cc:93:2a:49:a5:97:d6:04:46:5f:3a:9e:75:3d:5b:dc:5c:ce:51:77:28";
    proxies.forEach(proxy => {
        if (targetPlatform === "Surge") {
            proxy.tfo = `${proxy.tfo || false}, server-cert-fingerprint-sha256=${fingerprint}`;
        } else if (targetPlatform === "QX") {
            proxy.tfo = `${proxy.tfo || false}, tls-cert-sha256=${fingerprint}`;
        }
    });
    return proxies;
}