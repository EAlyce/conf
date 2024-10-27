if ($response.statusCode != 200) {
  $done(Null);
}

var body = $response.body;
var obj = JSON.parse(body);

// 提取ASN号
var asField = obj['as'];
var asn = asField.split(' ')[0]; // 提取 'AS400618' 这样的ASN号

// 获取当前系统时间
var currentTime = new Date().toLocaleString(); // 格式化为本地时间字符串

// 确保title显示国家和当前时间
var title = obj['country'] + " - " + currentTime; 
// subtitle保持显示ASN和ISP信息
var subtitle = asn + ' ' + obj['isp'];
var ip = obj['query'];

var description = "国家" + ":" + obj['country'] + '\n' + 
                  "城市" + ":" + obj['city'] + '\n' + 
                  "运营商" + ":" + obj['isp'] + '\n' + 
                  "数据中心" + ":" + obj['as'] + '\n' + 
                  "ASN" + ":" + asn;

$done({title, subtitle, ip, description});