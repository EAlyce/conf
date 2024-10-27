if ($response.statusCode !== 200) {
  console.error("请求失败，状态码：" + $response.statusCode);
  $done(null);
}

var body = $response.body;
console.log("响应体：" + body); // 调试输出响应体
var obj;

try {
  obj = JSON.parse(body);
} catch (e) {
  console.error("JSON 解析错误：" + e);
  $done(null);
}

// 检查解析后的对象
console.log("解析后的对象：" + JSON.stringify(obj)); // 调试输出解析后的对象

var title = obj['country'] || '未知国家'; // 若没有国家代码则使用默认值
var subtitle = obj['org'] || '未知运营商'; // 若没有组织则使用默认值
var ip = obj['ip'] || '未知IP'; // 若没有IP则使用默认值

var description = "国家代码" + ":" + (obj['country'] || '未知') + '\n' + 
                  "城市" + ":" + (obj['city'] || '未知') + '\n' + 
                  "地区" + ":" + (obj['region'] || '未知') + '\n' + 
                  "运营商" + ":" + (obj['org'] || '未知') + '\n' + 
                  "邮政编码" + ":" + (obj['postal'] || '未知') + '\n' + 
                  "坐标" + ":" + (obj['loc'] || '未知') + '\n' + 
                  "时区" + ":" + (obj['timezone'] || '未知');

$done({ title, subtitle, ip, description });