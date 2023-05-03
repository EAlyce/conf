const wifiDontNeedProxys = ['xiaomi_Alan_5G_1'];
const currentWifiSSIDKey = 'current_wifi_ssid';

function main() {
  if (wifiChanged(currentWifiSSIDKey)) {
    const mode = wifiDontNeedProxys.includes($network.wifi.ssid) ? 'direct' : 'rule';
    $surge.setOutboundMode(mode);
    $notification.post(
      'Surge',
      `Wi-Fi changed to ${$network.wifi.ssid || 'cellular'}`,
      `use ${mode} mode`
    );
  }
}

function wifiChanged(ssidKey) {
  const currentWifiSSID = $persistentStore.read(ssidKey);
  const changed = currentWifiSSID !== $network.wifi.ssid;
  changed && $persistentStore.write($network.wifi.ssid, ssidKey);
  return changed;
}

main();
$done();
