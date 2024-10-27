if ($response.statusCode != 200) {
  $done(null);
}

var body = $response.body;
var obj = JSON.parse(body);

var title = obj['country'];
var subtitle = obj['org'] + ' ' + obj['query'] + ' ' + obj['ip'];
var ip = obj['ip'];

var description = '------------------------------'+'\n'+'\n'+'服务商:'+obj['isp'] + '\n'+'\n'+'地区:' +obj['region']+ '\n'+ '\n' + 'IP地址:'+ obj['ip'] + '\n';
$done({title, subtitle, ip, description});