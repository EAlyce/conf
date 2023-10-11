let body = $response.body;

// 仅删除 <div class="slide-baidu">...</div> 广告区块
body = body.replace(/<div class="slide-baidu">[\s\S]*?<\/div>/, '');

// 使用$done()返回修改后的响应内容
$done({body: body});