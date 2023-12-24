const urls = [
  "https://purge.jsdelivr.net/gh/Blankwonder/surge-list@master/telegram.list",
  "https://purge.jsdelivr.net/gh/EAlyce/conf@main/Rule/OpenAi.list",
  "https://purge.jsdelivr.net/gh/EAlyce/conf@main/Rule/PRIVATE.list",
  "https://purge.jsdelivr.net/gh/EAlyce/conf@main/Rule/Proxy.list",
  "https://purge.jsdelivr.net/gh/EAlyce/conf@main/Rule/DIRECT.list",
  "https://purge.jsdelivr.net/gh/EAlyce/conf@main/Surge.conf"
];

// 定义请求头
const headers = {
  "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
};

// 访问每个网址
urls.forEach((url, index) => {
  $httpClient.get(url, (error, response, body) => {
    console.log(`URL: ${url}`);
    console.log(`Body: ${body}`);
    console.log('-------------------');

    // 如果是最后一个网址，则输出结果
    if (index === urls.length - 1) {
      $done();
    }
  });
});