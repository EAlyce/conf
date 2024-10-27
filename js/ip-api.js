if ($response.statusCode != 200) {
  $done(null);
}

var body = $response.body;
var obj = JSON.parse(body);

// 从 'org' 字段中提取 ASN 和 ISP 信息
var orgInfo = obj['org'];  // e.g., "AS400618 Prime Security Corp."
var asn = orgInfo.split(' ')[0];  // 提取 ASN 编号 (AS400618)
var isp = orgInfo.split(' ').slice(1).join(' ');  // 提取 ISP 名称 (Prime Security Corp.)

var title = obj['country'];  // 获取国家/地区信息
var subtitle = asn + ' ' + isp + ' ' + obj['ip'];  // 组合 ASN, ISP, 和 IP 地址
var ip = obj['loc'];  // 提取地理坐标

var description = '------------------------------' + '\n\n' + 
                  '服务商: ' + isp + '\n\n' + 
                  '地区: ' + obj['region'] + '\n\n' + 
                  'IP地址: ' + obj['ip'] + '\n';

// 完成响应
$done({ title, subtitle, ip, description });