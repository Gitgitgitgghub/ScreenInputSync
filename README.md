# ScreenInputSync

安裝在**發起連線那台 Mac** 上的選單列小工具。在 Apple 螢幕共享（Screen Sharing）裡按 Caps Lock，本機與遠端會一起在 ABC／繁體注音之間切換，而且打字行為與遠端顯示的輸入法一致。其他 App 的 Caps Lock 不受影響。

## 為什麼本機也要跟著切換

螢幕共享會先用**本機**的輸入法轉換按鍵，再把結果送到遠端，所以兩邊必須一致（2026-11-03 實測）：

| 本機 | 遠端 | 打字結果 |
|---|---|---|
| 注音 | 注音 | 正常組字 |
| ABC | 注音 | 直接出英文，無法組字 |
| ABC | ABC | 正常半形英文 |
| 注音 | ABC | 小寫字母變成注音符號 |

## 運作方式

在螢幕共享位於前景時：

- **Caps Lock**：本機明確切換輸入法，並送出 F17 讓遠端切換。Caps Lock 鍵與大寫鎖定狀態都不會傳到遠端（否則遠端注音會被切成英文模式）。
- **進入螢幕共享**：本機自動切到遠端目前的輸入法；期間本機若被其他方式切走，會立刻改回。
- **離開螢幕共享**：本機恢復成原本使用的輸入法。
- **對齊遠端輸入法**：同時按下 ⌘ 和 ⇧ 再放開（中間不按其他鍵），或從選單選「對齊遠端輸入法…」，然後依遠端選單列按 `E`（ABC）或 `C`（注音），`Esc` 取消。只改本機，不送 F17。`⌘⇧P` 等一般快捷鍵不受影響。

本機無法讀取遠端的實際輸入法，只能依 Caps Lock 次數推算。若兩邊變得相反（例如遠端被用滑鼠單獨切換，或 App 剛啟動時推算錯誤），用「對齊遠端輸入法」校正即可。

## 系統需求

- macOS 14 或更新版本
- 本機已啟用 ABC 與「繁體中文－注音」
- 遠端把 F17 設為「選取上一個輸入方式」，且切換循環只有 ABC／注音
- 編譯需要 **Xcode 16 或更新版本**（專案使用 Swift 6）
- XcodeGen（`brew install xcodegen`）為選用：專案檔已放在 git 中，只有新增、刪除或改名原始碼檔案後才需要執行 `xcodegen generate`

## 建置與安裝

```sh
./scripts/build-and-install.sh
```

安裝到 `/Applications/ScreenInputSync.app` 並自動註冊為登入項目（可在選單關閉「登入時啟動」）。首次開啟請在「系統設定 → 隱私權與安全性」允許**輔助使用**與**輸入監控**，再重新開啟 App。

安裝腳本會使用 Keychain 中的 Apple Development 憑證簽署，重建後權限會保留。若沒有憑證則改用 ad-hoc 簽署，每次重建都需要重新允許權限；若權限顯示已允許卻仍被要求，可清除舊紀錄後重新允許：

```sh
tccutil reset Accessibility com.brant.ScreenInputSync
tccutil reset ListenEvent com.brant.ScreenInputSync
```

## 解除安裝

從選單取消「登入時啟動」並結束 App，然後：

```sh
rm -rf /Applications/ScreenInputSync.app
```

最後可在系統設定中移除它的輔助使用與輸入監控權限。
