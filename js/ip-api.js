if ($response.statusCode != 200) {
  $done(null);
}

var city0 = "高谭市";
var isp0 = "Cross-GFW.org";

function City_ValidCheck(para) {
  return para || city0;
}

function ISP_ValidCheck(para) {
  return para || isp0;
}

function Country_ValidCheck(para) {
  return para || "未知国家";
}

var body = $response.body;
var obj = JSON.parse(body);

// 获取国家信息
var title = Country_ValidCheck(obj["country"]);

// subtitle 显示ISP和ASN信息
var subtitle = ISP_ValidCheck(obj["org"] || obj.as) + " | ASN: " + (obj["as"] || "未知ASN");

// IP信息
var ip = obj["query"];

// 详细描述
var description =
  "服务商:" +
  obj["isp"] +
  "\n" +
  "地区:" +
  City_ValidCheck(obj["regionName"]) +
  "\n" +
  "IP:" +
  obj["query"] +
  "\n" +
  "时区:" +
  obj["timezone"];

$done({ title, subtitle, ip, description });