# Dotfiles

这是 `chenbo-again/dotfiles` 的 chezmoi source state。仓库只版本控制配置；工具二进制和 Neovim 运行数据由各自的安装器管理，不进入 Git。

## 管理范围

chezmoi 管理：

- `~/.zshrc`
- `~/.oh-my-zsh/` 及其固定版本的本地插件
- `~/.config/nvim/`（LazyVim 配置和 `lazy-lock.json`）
- `~/.config/atuin/config.toml`
- `~/.terminfo/x/xterm-ghostty`（另建 `~/.terminfo/78 -> x`，兼容 zsh-bin 的十六进制查找）

chezmoi 不管理：

- `~/.local/share/nvim/`：lazy.nvim 插件、Mason 工具、Treesitter 解析器和运行历史
- `~/.local/opt/` 与 `~/.local/bin/`：命令行工具本体
- tmux 和 Zellij 的配置及插件
- Atuin 的历史数据库、密钥和登录令牌

因此 `chezmoi apply` 不会回滚本机通过 `:Lazy update`、`:MasonInstall` 或 `:TSInstall` 安装和更新的内容。

## 首次安装

在线机器：

```bash
git clone https://github.com/chenbo-again/dotfiles.git ~/.local/share/chezmoi
cd ~/.local/share/chezmoi
./fetch-tools.sh
~/.local/bin/chezmoi apply
```

`fetch-tools.sh` 会下载固定版本的 Linux x86_64 工具，校验官方 SHA-256 后安装到 `~/.local/opt/`，并为每个工具在 `~/.local/bin/` 创建相对符号链接。已存在的对应工具会移动到 `~/.local/share/tool-fetch-backups/`，安装失败时自动恢复。

首次启动 `nvim` 时，配置会在线 clone `lazy.nvim`，随后由 LazyVim 根据 `lazy-lock.json` 安装插件。常用在线维护命令：

```vim
:Lazy update
:Mason
:TSUpdate
```

## 工具缓存与离线安装

在联网机器准备完整缓存：

```bash
./fetch-tools.sh --cache-dir /path/to/tool-cache
```

把本仓库和 `tool-cache` 一起复制到离线机器，再执行：

```bash
./fetch-tools.sh --offline --cache-dir /path/to/tool-cache
~/.local/bin/chezmoi --source /path/to/dotfiles apply
```

该缓存只包含 CLI 工具，不包含 `~/.local/share/nvim`。需要在完全离线的机器运行 LazyVim 时，还应从已配置好的机器另行复制 `~/.local/share/nvim`；仓库不会覆盖该目录。

## 固定工具版本

脚本当前安装：

- Neovim 0.12.4
- chezmoi 2.71.1
- zmx 0.7.0
- clangd 22.1.6
- Bear 4.1.5（Ubuntu 22.04 x86_64 构建）
- Yazi/ya 26.5.6
- Atuin 18.17.1
- lazygit 0.63.1
- fzf 0.74.1
- ripgrep 15.2.0（命令 `rg`）
- fd 10.4.2
- Zsh 5.8（romkatv/zsh-bin v6.1.1）

除 Neovim、clangd 和 Bear 外，其余下载项均为官方静态或 musl 构建。Neovim 需要 glibc 2.35 或更新版本，clangd 需要 glibc 2.18 或更新版本，Bear 需要 glibc 2.34 或更新版本及 `libgcc_s.so.1`。Zsh 是完全静态、可重定位的 zsh-bin 构建，不依赖目标机的 glibc、ncurses 或系统 Zsh 模块。

Zsh 使用本仓库 `zsh-bin-5.8-v6.1.1` GitHub Release 中的精简运行时：autoload 函数已预编译，上游内置 terminfo 已移除，改为由 `.zshrc` 依次搜索 `~/.terminfo` 和系统 terminfo 目录。脚本安装时只需解压并根据目标 HOME 重定位一次，然后创建 `~/.local/bin/zsh`。它不会修改 `/etc/shells` 或账号的登录 shell；需要时可直接执行 `~/.local/bin/zsh`。因此目标机即使没有系统 Zsh，也能加载本仓库的 Oh My Zsh 配置。

Bear 官方不发布二进制。运行时包和 GPL 对应源码发布在本仓库的 `bear-4.1.5` GitHub Release，fetch 脚本校验运行时包的固定 SHA-256。

## 日常配置管理

```bash
chezmoi status
chezmoi diff
chezmoi edit ~/.zshrc
chezmoi apply
```

如果先编辑了 HOME 中的文件，回写 source state：

```bash
chezmoi re-add ~/.zshrc
chezmoi re-add ~/.config/nvim
```

提交前检查：

```bash
chezmoi verify
git diff --check
git status
```

## LazyVim

仓库保留当前启用的 LazyVim DAP、clangd 和 Python extras，以及在线更新后的 `lazy-lock.json`。如果 `fetch-tools.sh` 安装的 `~/.local/bin/clangd` 存在，Neovim 优先使用该 standalone clangd；否则允许 Mason 正常安装和管理 clangd。

Yazi 集成键位：

- `Space f y`：在当前文件位置打开 Yazi
- `Space f Y`：在当前工作目录打开 Yazi
- `Ctrl + Up`：恢复上一次 Yazi 会话

## Zsh 与 zmx

`.zshrc` 将 `~/.local/bin` 加入 `PATH`，使用 `nvim` 作为 `EDITOR`，加载 Atuin、Yazi wrapper、zmx 补全和 `zmx-select`（别名 `zs`）。

```bash
zmx attach work
zs
```

`zmx` 只保持单个终端会话，不提供窗口和分屏；布局继续由 Ghostty 管理。按 `Ctrl + \\` 可从会话分离。

Zsh 命令行支持 `Shift + 方向键` 选择，`Ctrl + Shift + C` 复制，`Ctrl + Shift + X` 剪切；SSH 环境通过 OSC 52 写回本地终端剪贴板。`Ctrl + Backspace` 删除前一个单词。

## Atuin

Atuin 使用本地历史数据库，仓库配置关闭自动同步和版本检查。`~/.local/share/atuin` 永远不纳入 chezmoi，因此历史、密钥和令牌不会进入 Git。
