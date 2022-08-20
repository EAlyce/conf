/***********************************

> 應用名稱：傲軟摳圖
> 軟件版本：1.5.4
> 下載地址：https://apps.apple.com/cn/app/id1490054676
> 腳本作者：Cuttlefish
> 微信賬號：墨魚手記
> 更新時間：2022-02-25
> 通知頻道：https://t.me/ddgksf2021
> 問題反饋：https://t.me/ddgksf2013_bot
> 特别說明：本腳本僅供學習交流使用，禁止轉載售賣
 
[rewrite_local]

# ～ 傲軟摳圖解鎖會員權限（2022-02-25）@ddgksf2013
https?:\/\/gw\.aoscdn\.com\/base\/vip\/client\/authorizations$ url script-response-body https://raw.githubusercontent.com/ddgksf2013/Cuttlefish/master/Crack/apowersoft.js

[mitm] 

hostname=gw.aoscdn.com

***********************************/



var cuttlefish ={"warning":"本腳本僅供學習交流使用，禁止轉載售賣","tgchannel":"https://t.me/ddgksf2021","feedback":"https://t.me/ddgksf2013_bot"};
var ddgksf2013 = {
  "status" : 200,
  "message" : "success",
  "data" : {
    "expired_at" : 4045798296,
    "is_activated" : 1,
    "is_lifetime" : 1,
    "expire_time" : "2099-01-01 00:00:00",
    "device_id" : 600150864,
    "period_type" : "active",
    "remain_days" : 99999,
    "product_id" : 369,
    "has_present" : 0,
    "allowed_device_count" : 1,
    "has_buy_extend" : 0,
    "will_expire" : 0,
    "license_type" : "premium",
    "begin_activated_time" : 1645798296,
    "durations" : 0,
    "vip_special" : 1
  }
};
$done({body: JSON.stringify(ddgksf2013)});
