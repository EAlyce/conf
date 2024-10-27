if ($response.statusCode !== 200) {
  $done(null);
}

var body = $response.body;
var obj = JSON.parse(body);

// 直接使用国家代码或者自行转换为国家名称
var title = obj['country'];
var subtitle = obj['org'];
var ip = obj['ip'];

var description = "国家代码" + ":" + obj['country'] + '\n' + 
                  "城市" + ":" + obj['city'] + '\n' + 
                  "地区" + ":" + obj['region'] + '\n' + 
                  "运营商" + ":" + obj['org'] + '\n' + 
                  "邮政编码" + ":" + obj['postal'] + '\n' + 
                  "坐标" + ":" + obj['loc'] + '\n' + 
                  "时区" + ":" + obj['timezone'];

$done({ title, subtitle, ip, description });