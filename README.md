<p align="center">
  <img src="Assets/AppIcon.png" width="112" alt="UU 轻滑图标">
</p>

<h1 align="center">UU 轻滑 · UU LightSlide</h1>

<p align="center"><strong>手机、iPad 远控 Mac，让页面慢下来，让操作更从容。</strong></p>

<p align="center">
  继续使用 UU 原来的滚动工具条，把速度调到适合阅读的节奏。<br>
  平时慢慢看，需要快速翻页时，一键恢复原速。
</p>

<p align="center">
  <a href="https://github.com/Dameon020/uu-lightslide/releases/download/v0.3.0/UU-LightSlide-v0.3.0-universal.dmg"><strong>下载 Mac 安装包</strong></a> ·
  <a href="#安装只需几步">安装</a> ·
  <a href="#怎么用">使用</a> ·
  <a href="#常见问题">常见问题</a> ·
  <a href="https://github.com/Dameon020/uu-lightslide/releases">全部版本</a>
</p>

---

## 为什么做这个小工具

用手机或 iPad 通过 UU 远程操作 Mac，连接很方便，但阅读网页、文档时，总有一个让人头疼的小问题：**滚动太快了。**

按住 UU 自带的滚动工具条，稍微动一下，页面就翻过了想看的位置。想慢慢看，只好把鼠标挪到窗口边缘，去拖那条细细的滚动条。手机屏幕本来就小，这样操作很费劲。

UU 轻滑就是为了解决这件事：

- **沿用原来的操作**：还是用 UU 的滚动工具条，不用换手势，也不用找窗口边缘。
- **把移动幅度变小**：默认调到原速的 10%，还可以继续降到 5%、2%、1%。
- **快慢随时切换**：需要快速翻页时点“原速 30 秒”，时间到了自动回到慢速。

装在被控的 Mac 上，授权一次，让它留在菜单栏里就好。

## 看看界面

<p align="center">
  <img src="docs/settings.png" width="380" alt="UU 轻滑实际界面：5%速度、快捷档位、原速30秒和自动模式">
</p>
<p align="center"><em>实际运行截图。滑动速度、临时原速和模式切换，都在这一个小面板里。</em></p>

## 能做什么

| 功能 | 用起来是什么样 |
| --- | --- |
| 自动处理 UU 输入 | 应用运行时，识别到 UU 发来的滚动就自动减速，每次连接不用重新开关 |
| 1%–100% 调节 | 轻轻调滑块，找到自己舒服的速度；改完自动保存 |
| 常用速度一键选 | 5% 精细阅读，10% 慢速浏览，50% 较快翻看 |
| 原速 30 秒 | 临时快速翻页，到时自动恢复；也可以提前恢复 |
| 菜单栏常驻 | 上下箭头图标旁显示当前百分比，点开就能调 |
| 登录自动启动 | Mac 登录后自动运行，也可以在面板里取消 |
| 本机鼠标保持原样 | 自动模式只减速能识别为 UU 来源的输入 |
| 本地运行 | 无账号、无联网、无遥测；不读取网页或文档内容 |

## 下载

**普通用户下载 DMG 即可，不需要下载源码，也不需要安装开发工具。**

- **[下载 UU 轻滑 v0.3.0 · Mac 安装包](https://github.com/Dameon020/uu-lightslide/releases/download/v0.3.0/UU-LightSlide-v0.3.0-universal.dmg)**
- [备用：应用 ZIP](https://github.com/Dameon020/uu-lightslide/releases/download/v0.3.0/UU-LightSlide-v0.3.0-universal.app.zip)
- [查看版本说明与校验和](https://github.com/Dameon020/uu-lightslide/releases/tag/v0.3.0)

需要 **macOS 13 或更新版本**，被控 Mac 和手机／iPad 上已有能正常使用的 UU 远程。安装包同时包含 **Apple Silicon（M 系列）和 Intel** 架构。

> 本工具只装在**被远程控制的 Mac** 上；手机和 iPad 无需额外安装任何东西。
>
> 当前为**未经过 Apple 公证的社区版**。首次打开可能被 macOS 拦截，按下方步骤处理。Apple Silicon 已有实际远控使用反馈；Intel 已完成交叉编译，尚未实机验证。

## 安装只需几步

1. 下载并打开 `.dmg`，把 **UU轻滑.app** 拖入 **Applications（应用程序）**。
2. 推出安装磁盘，从“应用程序”打开 **UU轻滑**。
3. 点击菜单栏上下箭头图标，在面板里选择 **授权辅助功能**。
4. 在 **系统设置 → 隐私与安全性 → 辅助功能** 中允许 **UU轻滑**。不同 macOS 版本的权限名称可能有所不同。
5. 用手机或 iPad 通过 UU 连接这台 Mac，继续操作原来的滚动工具条。

**首次打开被拦住时：**先尝试打开一次，再进入 **系统设置 → 隐私与安全性**，找到该应用的提示并选择 **仍要打开**。只在确认下载来源可信后操作，具体以 [Apple 官方说明](https://support.apple.com/102445) 为准。此步骤与辅助功能授权是两件事。

## 怎么用

### 平时慢慢看

保持 **自动：只减速 UU 远程输入**。默认是原速的 10%；如果还觉得快，就选 5% 或继续往左调。速度会自动记住，不用每次重设。

手机上继续用 UU 自带的滚动工具条。Mac 菜单栏会显示当前比例，例如 `↕ 5%`。

### 偶尔想快速翻页

点 **原速 30 秒**，再回到页面使用 UU 滚动工具条。30 秒后，自动恢复到你原来选的慢速；也可以提前点击“立即恢复慢速”。

这里恢复的是 UU 原来的速度，**不会直接跳到文档顶部或底部**。

### 想暂时停用

在模式菜单选择 **暂停减速**。需要时切回自动模式即可，退出应用也会停止减速。

## 常见问题

<details>
<summary><strong>装好了，为什么还是没有变慢？</strong></summary>

先确认面板显示“辅助功能已授权”，模式是“自动”，速度小于100%。然后在手机上滚动，查看面板底部的“UU事件”和“已减速”计数是否增加。

如果 UU 计数始终为0，可能是当前 UU 版本或输入路径没有保留可识别的来源。可以试一下 **兼容：全部滚动减速（本次）**。

兼容模式会同时影响本机鼠标，远程结束后应切回自动；它不会自动判断连接是否已断开，也不会保存到下次启动。

</details>

<details>
<summary><strong>已经连上了，为什么还显示“等待 UU 滚动”？</strong></summary>

这表示工具已就绪，正在等待输入。它根据滚动事件的来源工作，不需要读取 UU 的设备列表、账号或连接信息。近期没有收到 UU 滚动时，也会显示这条提示。

</details>

<details>
<summary><strong>会影响我坐在 Mac 前使用鼠标或触控板吗？</strong></summary>

自动模式下，普通本机鼠标和触控板输入原样通过。只有手动选择“兼容：全部滚动减速”时，才会一起减速。

Ctrl、Command、Option 配合滚轮的组合动作保持原样，避免改变缩放等操作。

</details>

<details>
<summary><strong>所有软件都能像素级平滑滚动吗？</strong></summary>

应用会缩小系统滚动事件的移动量，但最终呈现还取决于目标软件。个别程序按行或按页吸附，可能仍会出现步进效果。目前没有逐一验证所有应用。

已有 macOS 27.0.1、UU 4.43.1、Apple Silicon 环境的真实手机/iPad远控反馈，确认滚动明显变慢，整体体验良好。欢迎反馈其他组合的使用情况。

</details>

<details>
<summary><strong>为什么需要辅助功能权限？会读取我的内容吗？</strong></summary>

这是 macOS 允许程序调整输入事件所需的权限。工具只订阅滚轮事件，检查其来源并缩小移动量，不监听键盘文本，不读取屏幕、网页、文档或 UU 账号，也不会上传数据。

速度偏好保存在本机；面板中的事件计数用于判断是否工作。

</details>

<details>
<summary><strong>升级后提示重新授权，或者安装包无法打开怎么办？</strong></summary>

社区版未经过 Developer ID 签名与 Apple 公证，升级后可能需要重新确认授权。如果辅助功能列表里已有旧条目，可移除后重新添加当前应用。

如果系统提示文件损坏，先核对 Release 中的 SHA256 校验和并重新下载；也可以从源码构建。不要为了运行工具关闭整个系统的安全保护。

</details>

## 卸载

1. 在面板中取消 **登录 Mac 时自动启动**。
2. 点击 **退出**。
3. 将“应用程序”中的 **UU轻滑.app** 移到废纸篓。
4. 在系统辅助功能权限列表中移除 UU轻滑。

## 从源码构建

需要 macOS 与支持 macOS 13+ SDK 的 Xcode 或 Command Line Tools。使用 Swift 和系统自带的打包工具，无第三方包依赖。

```bash
git clone https://github.com/Dameon020/uu-lightslide.git
cd uu-lightslide
./build.sh
```

应用位于 `dist/UU轻滑.app`。更多命令：

```bash
./test.sh                   # 合成滚动事件与算法检查
./package.sh                # DMG、应用ZIP、源码ZIP和校验和
ARCHS=arm64 ./build.sh       # 仅构建Apple Silicon
ARCHS=x86_64 ./build.sh      # 仅构建Intel
```

技术实现、兼容边界见 [工作原理](docs/HOW_IT_WORKS.md)，正式签名与公证流程见 [发行指南](docs/RELEASING.md)。

## 反馈与开源

遇到问题或有改进想法，欢迎 [提交 Issue](https://github.com/Dameon020/uu-lightslide/issues)。请注明 macOS、芯片、UU版本、目标软件及使用模式；不要上传账号、设备验证码或完整个人日志。

感谢 [UUyc-companion](https://github.com/aoyamashou/UUyc-companion) 对 Mac 远控体验的探索，本项目介绍页的组织方式也参考了它的清晰表达。

**UU 轻滑是独立项目，与网易或 UU 远程无隶属关系。** 产品名称与第三方商标属于各自权利人，详见 [第三方说明](NOTICE.md)。

[MIT License](LICENSE) © 2026 Rixin Zhao and contributors
