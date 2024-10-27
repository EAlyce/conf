if ($response.statusCode != 200) {
  $done(null);
}

var body = $response.body;
var obj = JSON.parse(body);

// Extract relevant fields
var title = obj['country'];  // Country code (e.g., JP)
var subtitle = obj['ip'] + ' ' + obj['country'];  // IP and country code only
var ip = obj['ip'];
var description = '------------------------------' + '\n' + '\n' + '服务商:' + obj['org'] + '\n' + '\n' + '地区:' + obj['region'] + '\n' + '\n' + 'IP地址:' + obj['ip'] + '\n';

// Finish the request
$done({ title, subtitle, ip, description });