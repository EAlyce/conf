if ($response['statusCode'] != 200) { 
    $done(null); 
}

// 将台湾的国旗转为中国国旗
function countryFlag(countryCode) {
    const country = String.fromCodePoint(...countryCode.toUpperCase().split('').map(t => 127462 + t.charCodeAt()));
    return country === '🇹🇼' ? '🇨🇳' : country;
}

// 处理地区与城市信息
function formatRegionCity(region, city) {
    const chineseReg = /[\u4E00-\u9FA5]+/;
    let result = '';

    if (region && city && region !== city) {
        result = chineseReg.test(region) && chineseReg.test(city) ? `${region} ${city}` : region || city;
    }
    return result;
}

// 处理运营商信息
function formatISP(asInfo) {
    const asReg = /\A\S\d+/;
    return asReg.test(asInfo) ? asInfo.match(asReg)[0] : '';
}

// 格式化国家/地区信息
function formatCountry(country) {
    if (country === '中华民国' || country === '中華民國') {
        return '台湾';
    } else if (country === '中国') {
        return '';
    }
    return country;
}

// 简化函数，移除不必要的字符替换逻辑
function formatText(text) {
    return text;
}

// 处理标题和IP信息显示
function formatTitle(asInfo, query, regionCity) {
    return `${asInfo ? asInfo : ''} ➠ ${query} ${regionCity}`;
}

// 限制文本长度
function limitLength(text, maxLength = 10) {
    return text.length > maxLength ? text.slice(0, maxLength) : text;
}

// 主体逻辑
const responseBody = JSON.parse($response.body);
const country = formatCountry(formatText(responseBody.country));
const regionCity = formatRegionCity(formatText(responseBody.regionName), formatText(responseBody.city));
const title = countryFlag(responseBody.countryCode) + ' ' + limitLength(`${country} ${regionCity}`);
const subtitle = formatTitle(formatISP(responseBody.as), responseBody.query, regionCity);
const description = `-----------------------------------\n\n` +
    `国家/地区: ${country} ${regionCity}\n\n` +
    `时区: ${responseBody.timezone}\n\n` +
    `IP: ${responseBody.query}\n\n` +
    `经度: ${responseBody.lon} 纬度: ${responseBody.lat}\n\n` +
    `${responseBody.isp ? responseBody.isp : ''} ${responseBody.org ? responseBody.org : ''}`;

$done({ 'title': title, 'subtitle': subtitle, 'ip': responseBody.query, 'description': description });