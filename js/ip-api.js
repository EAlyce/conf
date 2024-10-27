if ($response.statusCode != 200) {
  $done(null);
}

var body = $response.body;
var obj = JSON.parse(body);

// 正则表达式提取AS信息
var asInfo = obj['org'].match(/AS\d+/) ? obj['org'].match(/AS\d+/)[0] : 'AS信息不可用';

var title = obj['country'];
// 在 subtitle 中加入 org, AS 信息, IP 地址
var subtitle = obj['org'] + ' ' + asInfo + ' ' + obj['ip'];

var ip = obj['ip'];

var description = '------------------------------'+'\n'+'\n'+'服务商:'+obj['org'] + '\n'+'\n'+'AS 信息:' + asInfo + '\n' + '地区:' +obj['region']+ '\n'+ '\n' + 'IP地址:'+ obj['ip'] + '\n';

$done({title, subtitle, ip, description});