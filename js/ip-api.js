if ($response.statusCode != 200) {
  $done(null);
}

var body = $response.body;
var obj = JSON.parse(body);

var subtitle = obj['as'] + ' ' + obj['query'];
var ip = obj['query'];

$done({subtitle, ip});