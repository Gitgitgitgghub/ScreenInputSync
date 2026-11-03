# ScreenInputSync

ScreenInputSync 是僅安裝在發起連線 Mac 上的 macOS 選單列工具。當 Apple Screen Sharing 位於前景時，它會讓 Caps Lock 同步切換本機與遠端的 ABC／繁體注音；其他 App 的 Caps Lock 不受影響。

## 系統需求

- macOS 14 或更新版本
- Apple Screen Sharing（bundle ID：`com.apple.ScreenSharing`）
- 本機已啟用 ABC 與「繁體中文－注音」
- 遠端把 F17 設為「選取上一個輸入方式」，且切換循環只有預期的 ABC／注音
- 開發建置需要 Xcode 及 XcodeGen：`brew install xcodegen`

## 建置與安裝

```sh
./scripts/build-and-install.sh
```

預設安裝至 `/Applications/ScreenInputSync.app`。首次開啟時：

1. 在「系統設定 → 隱私權與安全性 → 輔助使用」允許 ScreenInputSync。
2. 在「系統設定 → 隱私權與安全性 → 輸入監控」允許 ScreenInputSync。
3. 權限變更後結束並重新開啟 ScreenInputSync。

工具會自動註冊為登入項目，也可從選單列關閉或重新開啟「Launch at Login」。

安裝腳本會優先使用 Keychain 中的 Apple Development 憑證，讓重建後的權限識別保持穩定。若找不到憑證才使用 ad-hoc 簽署；ad-hoc 版本更新後，macOS 可能要求重新核准權限。

## 使用方式

- **Screen Sharing 位於前景：** 本機輸入法固定為 ABC（離開時恢復原本的輸入法），讓按鍵原樣送到遠端，由遠端輸入法決定打字行為。Caps Lock 只送出 F17 切換遠端輸入法；Caps Lock 與大寫鎖定狀態都不會傳到遠端，避免遠端注音被大寫鎖定切成英文、ABC 下 Shift 出現全形字。
- **其他 App：** Caps Lock 維持原有行為。
- **重新對齊：** 先按住 Command，再按 Shift；期間不要按其他鍵，最後放開兩鍵。
  - 按 `E`：遠端目前是 ABC，將本機對齊英文。
  - 按 `C`：遠端目前是注音，將本機對齊中文。
  - 按 `Esc`：取消。

重新對齊只改本機，不送 F17。`Command + Shift + P` 等一般快捷鍵會正常通過，不會開啟 HUD。

## 從 Karabiner 遷移

在完成下列實機測試前，**不要移除 Karabiner**：

1. 先備份：`cp ~/.config/karabiner/karabiner.json ~/.config/karabiner/karabiner.json.before-screen-input-sync`。
2. 暫時停用現有的「Screen Sharing: Caps Lock to F18」規則，避免重複事件。
3. 確認其他 App 的 Caps Lock 正常。
4. 在 Screen Sharing 中測試 Caps Lock 往返 ABC／注音。
5. 測試 ABC 下的半形大寫 `ABC` 與注音中文組字。
6. 測試 `Command + Shift + P` 不開啟 HUD。
7. 測試 Command → Shift HUD 的 E、C、Esc。
8. 睡眠、重新連線後再次確認 Caps Lock 同步。

全部通過後才能：

- 移除 Karabiner 的 Screen Sharing Caps Lock 規則。
- 移除本機 F18 輸入來源快捷鍵。
- **保留遠端 F17 輸入來源快捷鍵。**

若新工具不穩定，結束 ScreenInputSync、恢復 Karabiner 備份與規則即可回復原方案。

## 解除安裝

先從選單列取消「Launch at Login」並結束工具，再執行：

```sh
rm -rf /Applications/ScreenInputSync.app
```

最後可在系統設定中移除 ScreenInputSync 的輔助使用與輸入監控權限。

## 限制

本機工具無法讀取遠端 Mac 的實際輸入來源。如果遠端被獨立切換或漏掉 F17，兩端會持續相反；此時使用 Command → Shift，再按 E 或 C 對齊。
