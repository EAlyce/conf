// 检查HTTP响应状态码是否为200
if ($response.statusCode === 200) {
    let body = $response.body;

    if (body && typeof body === "string") {
        // 仅删除 <div class="slide-baidu">...</div> 广告区块
        body = body.replace(/<div class="slide-baidu">[\s\S]*?<\/div>/, '');

        // 使用$done()返回修改后的响应内容
        $done({body: body});
    } else {
        // 如果响应内容不存在或不是字符串，直接返回原始响应
        $done({});
    }
} else {
    // 如果状态码不是200，直接返回原始响应
    $done({});
}