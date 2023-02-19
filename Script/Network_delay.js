//使用方法
******************************************

const REQUEST_HEADERS = {
  'User-Agent':
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/94.0.4606.61 Safari/537.36',
  'Accept-Language': 'en',
};
(async () => {
  let panel_result = {
    title: 'Network Connectivity Test',
    content: '',
    icon: 'wifi.circle',
    'icon-color': '#FF5A9AF9',
  };
  let test_list = [test_baidu(), test_bilibili(), test_github(), test_google(), test_youtube()];
  let result = await Promise.all(test_list);
  let content = result.join('\n');
  panel_result['content'] = content;
  $done(panel_result);
})();
async function test_baidu() {
  let inner_check = () => {
    return new Promise((resolve) => {
      let option = {
        url: 'https://www.baidu.com',
        headers: REQUEST_HEADERS,
      };
      let baidu_startTime = Date.now();
      $httpClient.post(option, function (error, response, data) {
        let baidu_endTime = Date.now();
        resolve('1');
      });
    });
  };
  let baidu_test_result = 'Baidu' + '\xa0\xa0\xa0\xa0\xa0\xa0' + ': ';
  let baidu_Delay = await inner_check().then((code) => {
    if (code === '1') {
      baidu_Delay = baidu_endTime - baidu_startTime + '';
      baidu_test_result += baidu_Delay + ' ms';
    }
  });
  return baidu_test_result;
}
async function test_bilibili() {
  let inner_check = () => {
    return new Promise((resolve) => {
      let option = {
        url: 'https://www.bilibili.com',
        headers: REQUEST_HEADERS,
      };
      let bilibili_startTime = Date.now();
      $httpClient.post(option, function (error, response, data) {
        let bilibili_endTime = Date.now();
        resolve('1');
      });
    });
  };
  let bilibili_test_result = 'Bilibili' + '\xa0\xa0\xa0\xa0\xa0\xa0' + ': ';
  let bilibili_Delay = await inner_check().then((code) => {
    if (code === '1') {
      bilibili_Delay = bilibili_endTime - bilibili_startTime + '';
      bilibili_test_result += bilibili_Delay + ' ms';
    }
  });
  return bilibili_test_result;
}
async function test_youtube() {
  let inner_check = () => {
    return new Promise((resolve) => {
      let option = {
        url: 'https://www.youtube.com',
        headers: REQUEST_HEADERS,
      };
      let youtube_startTime = Date.now();
      $httpClient.post(option, function (error, response, data) {
        let youtube_endTime = Date.now();
        resolve('1');
      });
    });
  };
  let youtube_test_result = 'Youtube' + '\xa0\xa0' + ': ';
  let youtube_Delay = await inner_check().then((code) => {
    if (code === '1') {
      youtube_Delay = youtube_endTime - youtube_startTime + '';
      youtube_test_result += youtube_Delay + ' ms';
    }
  });
  return youtube_test_result;
}
async function test_google() {
  let inner_check = () => {
    return new Promise((resolve) => {
      let option = {
        url: 'https://www.google.com/generate_204',
        headers: REQUEST_HEADERS,
      };
      let google_startTime = Date.now();
      $httpClient.post(option, function (error, response, data) {
        let google_endTime = Date.now();
        resolve('1');
      });
    });
  };
  let google_test_result = 'Google' + '\xa0\xa0\xa0\xa0' + ': ';
  let google_Delay = await inner_check().then((code) => {
    if (code === '1') {
      google_Delay = google_endTime - google_startTime + '';
      google_test_result += google_Delay + ' ms';
    }
  });
  return google_test_result;
}
async function test_github() {
  let inner_check = () => {
    return new Promise((resolve) => {
      let option = {
        url: 'https://www.github.com',
        headers: REQUEST_HEADERS,
      };
      let github_startTime = Date.now();
      $httpClient.post(option, function (error, response, data) {
        let github_endTime = Date.now();
        resolve('1');
      });
    });
  };
  let github_test_result = 'Github' + '\xa0\xa0\xa0\xa0\xa0' + ': ';
  let github_Delay = await inner_check().then((code) => {
    if (code === '1') {
      github_Delay = github_endTime - github_startTime + '';
      github_test_result += github_Delay + ' ms';
    }
  });
  return github_test_result;
}