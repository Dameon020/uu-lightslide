# 构建与发行

## 社区分享包（默认）

执行 `./package.sh`，得到 Universal 2 的 DMG、App ZIP、源码 ZIP 和 SHA256SUMS.txt。默认采用 ad-hoc 签名，没有 Apple 公证，接收者可能遇到 Gatekeeper 提示。不要把它描述为“已签名公证”或“免提示安装”。

打包脚本仅将白名单源码、图标和文档加入源码包，不包含本机日志、原始官方参考图、旧版备份、用户偏好、证书、构建中间文件或会话记录。使用未联网源码副本重新构建可验证可构建性；编译器版本和签名时间可能使二进制哈希不同，不承诺逐字节重现。

## Developer ID 正式发行

需要拥有有效的 Apple Developer ID Application 证书和 Apple Developer Program 资格。不要提交证书、私钥或 API 密钥到仓库。

1. 在 Keychain 中准备正式签名身份，并通过 `notarytool store-credentials` 保存公证凭据。具体认证选项按 Apple 官方文档配置。
2. 设置 `SIGN_IDENTITY` 为 Keychain 中的证书名称后执行 `./package.sh`，构建将启用 hardened runtime 和安全时间戳。此时文件已正式签名，但**还没有公证**。
3. 对生成的 App ZIP 运行 `xcrun notarytool submit <AppZIP> --keychain-profile <profile> --wait`，确认状态为 Accepted。
4. 对 `dist/UU轻滑.app` 执行 `xcrun stapler staple` 和 `xcrun stapler validate`，再执行 `./package.sh --reuse-app`，重新生成包含公证票据的 App ZIP 和 DMG。
5. 对新的 DMG 提交公证，确认 Accepted 后 staple/validate DMG。最后重新生成校验和：在 release 目录运行 `shasum -a 256 *.dmg *.zip > SHA256SUMS.txt`。
6. 使用 `codesign --verify --deep --strict`、`spctl --assess --type execute --verbose`、DMG校验及不同电脑下载后的首次安装验证。只发布最终验收过的附件。

`--reuse-app` 不会重新编译或重新签名应用；需要先手动确认它的版本与源码一致。

官方参考：
- https://developer.apple.com/developer-id/
- https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution
- https://support.apple.com/102445

## 发布到 GitHub

1. 新建名为 `uu-lightslide` 的仓库（建议公开），上传本源码包中的全部内容，包括隐藏的 `.github` 文件夹。
2. 仓库描述可用：“A macOS menu bar helper for precise, slower scrolling with UU Remote.”
3. 创建对应版本的 tag 和 Release；发布说明可取 CHANGELOG.md 的相应部分。
4. 上传 DMG、App ZIP 与 SHA256SUMS.txt，社区版应显著标注“未公证”。源码由仓库和源码ZIP同时提供。

以上步骤是准备好的发布流程；本次本地打包不等于已创建或发布 GitHub 仓库。
