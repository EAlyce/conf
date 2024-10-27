if ($response.statusCode != 200) {
  $done(null);
}

var city0 = "高谭市";
var isp0 = "Cross-GFW.org";

function getRandomInt(max) {
  return Math.floor(Math.random() * Math.floor(max));
}

function City_ValidCheck(para) {
  if(para) {
  return para
  } else
  {
  return city0
  }
}

function ISP_ValidCheck(para) {
  if(para) {
  return para
  } else
  {
  return isp0
  }
}

function Area_check(para) {
  if(para=="中华民国"){
  return "台湾"
  } else
  {
  return para
  }
}

var body = $response.body;
var obj = JSON.parse(body);
var title = obj['country'] + "   " + obj['city'];
var subtitle = obj['as'];
var ip = obj['query'];
var description = '------------------------------'+'\n'+'\n'+'服务商:'+obj['isp'] + '\n'+'\n'+'地区:' +City_ValidCheck(obj['regionName'])+ '\n'+ '\n' + 'IP地址:'+ obj['query'] + '\n';
$done({title, subtitle, ip, description});