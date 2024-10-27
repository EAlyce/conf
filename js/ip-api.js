if ($response.statusCode != 200) {
  $done(null);
}

var body = $response.body;
var obj = JSON.parse(body);

// Extract relevant fields based on the ipinfo.io structure
var title = obj['country'];  // Country code (e.g., JP for Japan)
var subtitle = obj['ip'] + ' ' + obj['country'];  // Only IP and country
var ip = obj['ip'];
var description = '------------------------------' + '\n\n' + 
                  '服务商: ' + obj['org'] + '\n\n' + 
                  '地区: ' + obj['region'] + '\n\n' + 
                  'IP地址: ' + obj['ip'] + '\n';

// Complete the response
$done({ title, subtitle, ip, description });