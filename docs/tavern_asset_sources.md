# 酒館場景免費資產盤點

這份文件記錄目前研究過、可用來重構酒館場景的免費資產。

注意：

- repo 正式追蹤的只有 `apps/client_flutter/assets/environment/` 內的最終素材
- `apps/client_flutter/assets/external/` 是研究用原始下載包，已被 `.gitignore` 排除，不會跟著 git 走
- 如果 MacBook agent 想重新檢視原始包，需要依這份文件的來源網址重新下載

## 1. 研究過的資產來源

### A. RGSDev Free CC0 Top Down Tileset
- 來源: https://opengameart.org/content/free-cc0-top-down-tileset-template-pixel-art
- 研究時下載位置:
  - `apps/client_flutter/assets/external/tavern_free/rgsdev_topdown_template/`
- 代表檔案:
  - `Tilesets/tileset_brown.png`
  - `Tilesets/tileset_full.png`
- 授權:
  - CC0
  - 可商用
  - 不需要署名
- 適合用途:
  - 木地板 base tile
  - 臨時牆面/走道/碰撞底圖
  - 先搭酒館 prototype

### B. Animated Fires
- 來源: https://opengameart.org/content/animated-fires
- 研究時下載位置:
  - `apps/client_flutter/assets/external/tavern_free/oga/animated-fires/`
- 代表檔案:
  - `Small_Fireball_10x26.png`
  - `Jumping_Small_Fireball_14x45.png`
- 授權:
  - CC0
- 適合用途:
  - 營火火焰特效
  - 火把火焰
  - 小型暖色動畫疊層

### C. Campfire Pixel Art Animated
- 來源: https://opengameart.org/content/campfire-pixel-art-animated
- 研究時下載位置:
  - `apps/client_flutter/assets/external/tavern_free/oga/campfire-sprite-sheet.png`
- 授權:
  - CC0
- 適合用途:
  - 中央營火主 sprite
  - 營火語音吧台核心火焰動畫

### D. LPC Tavern
- 來源: https://opengameart.org/content/lpc-tavern
- 研究時下載位置:
  - `apps/client_flutter/assets/external/tavern_free/oga/lpc-tavern/`
- 代表檔案:
  - `lpc-tavern/tavern-furniture.png`
  - `lpc-tavern/tavern-deco.png`
  - `lpc-tavern/preview/floors.png`
  - `lpc-tavern/preview/walls.png`
  - `lpc-tavern/preview/tavern-preview.png`
- 授權:
  - 不是 CC0
  - 內容混合 `OGA-BY 3.0 / CC-BY 3.0+ / CC-BY-SA 3.0+ / GPL`
  - 需要保留 attribution
  - 若正式整合到產品，需要明確做授權整理
- 適合用途:
  - 最接近你要的酒館風格
  - 可作為場景拼接參考
  - 可拆出桌椅、吧台、書櫃、裝飾物

## 2. 目前最建議的使用策略

### 低風險直接可用
- `RGSDev CC0`
- `Animated Fires`
- `Campfire Pixel Art Animated`

這三個可以先直接進 Flutter/Flame 場景，不會有授權複雜度。

### 高匹配但需授權控管
- `LPC Tavern`

這包的畫風最像你給的參考圖，但因為不是單純 CC0，我建議：
- 先當作美術拼接參考與 prototype 候選
- 若要正式放進 app 主素材，再做 attribution 清單和授權決策

## 3. 目前缺少的東西

雖然現在已經有酒館主體元素，但還缺幾個非常具體的物件：
- 任務佈告欄專用大看板
- 公會長書桌專用 front-facing desk
- 商店櫃台/藥水貨架/商人立繪
- 坐在營火周圍的固定 NPC
- 牆面火把或吊燈的一致風格套件

## 4. 下一步建議

### 路線 A: 先落地場景
直接用現有素材做一版可玩的酒館：
- 木地板: RGSDev brown tiles
- 中央營火: campfire-sprite-sheet
- 桌椅/書櫃/裝飾: LPC Tavern
- 火焰特效: Animated Fires

### 路線 B: 繼續補純免費且低風險素材
優先繼續找：
- CC0 或明確可商用的 tavern props
- 商人/吧台/公告欄專用 top-down 像素素材

## 5. 補充

另外有兩個 itch.io 候選包目前沒有自動下載進 repo：
- zedpxl interior pack
- pottlund campfire pack

原因不是找不到，而是 itch.io 的免費下載流程要經過下載確認頁，且自動抓取流程不夠穩。現階段已經有 OpenGameArt 的替代來源，所以先不把這兩包混進正式素材來源。
