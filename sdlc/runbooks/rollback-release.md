# 回滚一次发版

herdr-bar 的生产是 GitHub Release zip。没有自安装通道。要退一个版本，装上一份 zip。

## 步骤

1. 下载上一份 GitHub Release zip（坏 tag 之前那个）。
2. 解压。
3. 清隔离：`xattr -cr HerdrBar.app`
4. 用那份 app 替换 `~/Applications/HerdrBar.app`（或先留着解压出来的副本）。
5. 打开：`open ~/Applications/HerdrBar.app`

extra 是 ad-hoc 签名。从浏览器下下来的必须 `xattr -cr`。

## Agent 不能做的

Agent 会话没有 `RELEASE_APPROVAL` 就不能打 `v*` 或发 GitHub Release。回滚之后由人切下一个 tag。见 `scripts/hooks/production-gate.sh`。
