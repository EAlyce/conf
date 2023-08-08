const wifiDontNeedProxys = ['xiaomi_Alan_5G_1'];
const currentWifiSSIDKey = 'current_wifi_ssid';

function main() {
  const ssid = $network.wifi.ssid;
  if (wifiChanged(currentWifiSSIDKey, ssid)) {
    const mode = wifiDontNeedProxys.includes(ssid) ? 'direct' : 'rule';
    $surge.setOutboundMode(mode);
    $notification.post('Surge', `Wi-Fi changed to ${ssid || 'cellular'}`, `use ${mode} mode`);
  }
}

function wifiChanged(ssidKey, ssid) {
  const currentWifiSSID = $persistentStore.read(ssidKey);
  const changed = currentWifiSSID !== ssid;
  if (changed) {
    $persistentStore.write(ssid, ssidKey);
  }
  return changed;
}

main();
$done();