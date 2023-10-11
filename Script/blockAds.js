let body = $response.body;

// 使用正则表达式匹配并删除特定的HTML区块
body = body.replace(/<div class="slide-baidu">[\s\S]*?<\/div>\s*<div class="mod mod-page" id="ChapterView"[\s\S]*?<span>/, '<span>');

// 使用$done()返回修改后的响应内容
$done({body: body});