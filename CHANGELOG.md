# 更新歷程

版本號採用 `主版本.次版本`：新增或改變功能時加次版本，不相容的大改動才加主版本。每個版本在 git 上都有對應的 `v` 標籤（例如 `v1.1`），並發佈在 [Releases](https://github.com/Gitgitgitgghub/ScreenInputSync/releases)。

## [1.1] - 2026-11-04

### 新增
- 直接在「下載」資料夾開啟 App 時，會提示並自動移到「應用程式」，再從那裡重新開啟。之前從暫存位置執行時，部分功能會不正常。
- 選單底部顯示目前版本。

## [1.0] - 2026-11-04

第一個公開版本。

### 新增
- 在螢幕共享裡按 Caps Lock，本機與遠端一起在 ABC／繁體注音之間切換；Caps Lock 與大寫鎖定狀態不會傳到遠端。
- 也可以用本機系統設定裡的切換輸入法快捷鍵（例如 `⌃Space`、`⌘Space`），效果和 Caps Lock 相同。
- 本機輸入法在螢幕共享期間一律跟隨遠端；離開後恢復原本的輸入法。
- 「對齊遠端輸入法」（`⌘⇧` 或選單）：兩邊不一致時，依遠端選單列按 `E`／`C` 校正本機。
- 登入時啟動、前往輔助使用權限設定。

[1.1]: https://github.com/Gitgitgitgghub/ScreenInputSync/releases/tag/v1.1
[1.0]: https://github.com/Gitgitgitgghub/ScreenInputSync/releases/tag/v1.0
