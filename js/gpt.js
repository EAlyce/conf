let url = "http://chat.openai.com/cdn-cgi/trace";

let titlediy, icon, iconerr, iconColor, iconerrColor;
if (typeof $argument !== 'undefined') {
    const args = $argument.split('&');
    for (let i = 0; i < args.length; i++) {
        const [key, value] = args[i].split('=');
        if (key === 'title') {
            titlediy = value;
        } else if (key === 'icon') {
            icon = value;
        } else if (key === 'iconerr') {
            iconerr = value;
        } else if (key === 'icon-color') {
            iconColor = value;
        } else if (key === 'iconerr-color') {
            iconerrColor = value;
        }
    }
}

$httpClient.get(url, function (error, response, data) {
    if (error) {
        console.error(error);
        $done();
        return;
    }

    let gpt, iconUsed, iconCol;
    if (data.includes("gpt")) {  // 直接检测数据中是否包含 'gpt'
        gpt = "GPT: 支持";
        iconUsed = icon ? icon : undefined;
        iconCol = iconColor ? iconColor : undefined;
    } else {
        gpt = "GPT: 不支持";
        iconUsed = iconerr ? iconerr : undefined;
        iconCol = iconerrColor ? iconerrColor : undefined;
    }

    let body = {
        title: titlediy || "默认标题",
        content: gpt,
        icon: iconUsed,
        'icon-color': iconCol
    };

    $done(body);
});
