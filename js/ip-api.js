if ($response.statusCode != 200) {
  $done(null);
}

var body = $response.body;
var obj = JSON.parse(body);

// Extract relevant fields
var title = obj['country'];
var subtitle = obj['query'] + ' ' + obj['country'];  // Only query (IP) and country
var ip = obj['query'];
var description = '------------------------------' + '\n' + '\n' + '服务商:' + obj['isp'] + '\n' + '\n' + '地区:' + obj['regionName'] + '\n' + '\n' + 'IP地址:' + obj['query'] + '\n';

// Finish the request
$done({ title, subtitle, ip, description });