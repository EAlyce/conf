// @timestamp thenkey 2024-01-31 13:54:57
let e = "globe.asia.australia";
let s = true, o = 1000, c = 3000, a = {};

if ("undefined" != typeof $argument && "" !== $argument) {
    const n = l("$argument");
    e = n.icon || e;
    s = 0 != n.hideIP;
    o = n.cnTimeout || 1000;
    c = n.usTimeout || 3000;
}

function l() {
    return Object.fromEntries($argument.split("&").map((e) => e.split("=")).map(([e, t]) => [e, decodeURIComponent(t)]));
}

async function g(e = "/v1/requests/recent", t = "GET", n = null) {
    return new Promise(((i, s) => {
        $httpAPI(t, e, n, (e => {
            i(e);
        }));
    }));
}

async function m(e, t) {
    let i = 1;
    const s = new Promise(((s, o) => {
        const c = async a => {
            try {
                const i = await Promise.race([new Promise(((t, n) => {
                    let i = Date.now();
                    $httpClient.get({url: e}, ((e, s, o) => {
                        if (e) n(e);
                        else {
                            let e = Date.now() - i;
                            switch (s.status) {
                                case 200:
                                    let n = s.headers["Content-Type"];
                                    switch (true) {
                                        case n.includes("application/json"):
                                            let i = JSON.parse(o);
                                            i.tk = e;
                                            t(i);
                                            break;
                                        case n.includes("text/html"):
                                            t("text/html");
                                            break;
                                        case n.includes("text/plain"):
                                            let s = o.split("\n").reduce(((t, n) => {
                                                let [i, s] = n.split("=");
                                                return t[i] = s, t;
                                            }), {});
                                            t(s);
                                            break;
                                        case n.includes("image/svg+xml"):
                                            t("image/svg+xml");
                                            break;
                                        default:
                                            t("未知");
                                    }
                                    break;
                                case 204:
                                    t({tk: e});
                                    break;
                                case 429:
                                    console.log("次数过多");
                                    t("次数过多");
                                    break;
                                case 404:
                                    console.log("404");
                                    t("404");
                                    break;
                                default:
                                    t("nokey");
                            }
                        }
                    }));
                })), new Promise(((e, n) => {
                    setTimeout(() => n(new Error("timeout")), t);
                }))]);
                i ? s(i) : (s("超时"), o(new Error(n.message)));
            } catch (e) {
                a < 1 ? (i++, c(a + 1)) : (s("检测失败, 重试次数" + i), o(e));
            }
        };
        c(0);
    }));
}

(async () => {
    let n = "", l = "节点信息查询", r = "代理链", p = "", f = "", y = "";
    const P = await m("http://ip-api.com/json/?lang=zh-CN", c);
    if ("success" === P.status) {
        console.log("ipapi" + JSON.stringify(P, null, 2));
        let {query: o, city: c, isp: l, as: r} = P;
        n = o;
        p = "落地IP: \t" + o + "\n落地ISP: \t" + l + "\n落地ASN: \t" + r;
    } else {
        console.log("ild" + JSON.stringify(P));
        p = "";
    }
    let h, w = "";
    let k = (await g()).requests.slice(0, 6).filter((e => /ip-api\.com/.test(e.URL)));
    if (k.length > 0) {
        const e = k[0];
        /\(Proxy\)/.test(e.remoteAddress) ? (h = e.remoteAddress.replace(" (Proxy)", ""), r = "") : (h = "Noip", w = "代理链地区:");
    } else h = "Noip";

    let N = false, $ = false;
    if (h == n) w = "直连节点:"; 
    else {
        if ("Noip" === h ? N = true : /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/.test(h) ? $ = true : /^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$/.test(h) && (isv6 = true), 
            (!N || $)) {
            const e = await m(`https://api-v3.speedtest.cn/ip?ip=${h}`, o);
            if (0 === e.code && "中国" === e.data.country) {
                let {isp: n} = e.data;
                console.log("ik" + JSON.stringify(e, null, 2));
                w = "入口IP: \t" + h + "\n入口ISP: \t" + n + "\n---------------------\n";
            } else {
                N = false;
                console.log("ik" + JSON.stringify(e));
            }
        }
        if ((!N || isv6) && !cn) {
            const e = await m(`http://ip-api.com/json/${h}?lang=zh-CN`, c);
            if ("success" === e.status) {
                console.log("iai" + JSON.stringify(e, null, 2));
                let {isp: c} = e;
                w += "入口IP: \t" + h + "\n入口ISP: \t" + c + "\n---------------------\n";
            } else {
                console.log("iai" + JSON.stringify(e));
            }
        }
    }
    
    a = {title: l + y, content: "" + w + p};
})().catch((e) => console.log(e.message)).finally(() => $done(a));
