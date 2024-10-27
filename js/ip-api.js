if ($response.statusCode != 200) {
  $done(null);
}


var title = obj['country']; 
var subtitle = obj['org'];  
var ip = obj['loc'];

var description = '------------------------------' + '\n\n' + 
                  '服务商: ' + obj['org'] + '\n\n' + 
                  '地区: ' + obj['region'] + '\n\n' + 
                  'IP地址: ' + obj['loc'] + '\n';

// Complete the response
$done({ title, subtitle, ip, description });