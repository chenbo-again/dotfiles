# Dotfiles

这是 `chenbo-again/dotfiles` 的 chezmoi source state。仓库主要版本控制配置，同时保留少量 MCP 启动脚本和 Tavily 运行时源码；工具二进制和 Neovim 运行数据由各自的安装器管理，不进入 Git。

## 管理范围

chezmoi 管理：

- `~/.zshrc`
- `~/.oh-my-zsh/` 及其固定版本的本地插件
- `~/.config/nvim/`（LazyVim 配置和 `lazy-lock.json`）
- `~/.config/atuin/config.toml`
- `~/.config/opencode/` 中的非敏感配置、插件和 skill
- `~/.terminfo/x/xterm-ghostty`（另建 `~/.terminfo/78 -> x`，兼容 zsh-bin 的十六进制查找）

chezmoi 不管理：

- `~/.local/share/nvim/`：lazy.nvim 插件、Mason 工具、Treesitter 解析器和运行历史
- `~/.local/opt/` 与 `~/.local/bin/`：命令行工具本体
- tmux 和 Zellij 的配置及插件
- Atuin 的历史数据库、密钥和登录令牌
- Opencode 的 PAT、MCP gateway key、浏览器状态、`node_modules` 和 MCP 后端源码

因此 `chezmoi apply` 不会回滚本机通过 `:Lazy update`、`:MasonInstall` 或 `:TSInstall` 安装和更新的内容。

## 首次安装

在线机器：

```bash
# Route external traffic through the local FlClash mixed proxy.
proxy_on() {
  local proxy_url="http://127.0.0.1:7899"
  export http_proxy="$proxy_url"
  export https_proxy="$proxy_url"
  export HTTP_PROXY="$proxy_url"
  export HTTPS_PROXY="$proxy_url"
  export ALL_PROXY="$proxy_url"
  export all_proxy="$proxy_url"
  export no_proxy="localhost,127.0.0.1,::1,hygon.cn,.hygon.cn,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
  export NO_PROXY="$no_proxy"
}
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
- Bear 4.1.5（Ubuntu 22.04 x86_64 构建）
- Yazi/ya 26.5.6
- Atuin 18.17.1
- lazygit 0.63.1
- fzf 0.74.1
- ripgrep 15.2.0（命令 `rg`）
- fd 10.4.2
- Zsh 5.8（romkatv/zsh-bin v6.1.1）
- Node.js 22.23.1（同时提供 `npm`、`npx` 和 `corepack`）
- uv/uvx 0.11.32

除 Neovim、Bear 和 Node.js 外，其余下载项均为官方静态或 musl 构建。Neovim 需要 glibc 2.35 或更新版本，Bear 需要 glibc 2.34 或更新版本及 `libgcc_s.so.1`，Node.js 需要 glibc 2.28 或更新版本。Zsh 是完全静态、可重定位的 zsh-bin 构建，不依赖目标机的 glibc、ncurses 或系统 Zsh 模块。

Zsh 使用本仓库 `zsh-bin-5.8-v6.1.1` GitHub Release 中的精简运行时：autoload 函数已预编译，上游内置 terminfo 已移除，改为由 `.zshrc` 依次搜索 `~/.terminfo` 和系统 terminfo 目录。如果系统 PATH 或目标 HOME 中已经有可执行的 Zsh，脚本不会安装或覆盖它；否则才解压、按目标 HOME 重定位并创建 `~/.local/bin/zsh`。Zsh 产物仍会进入工具缓存，确保该缓存可以带到没有 Zsh 的离线机器。脚本不会修改 `/etc/shells` 或账号的登录 shell；新安装 Zsh 后会打印去重写入 `/etc/shells` 并执行 `chsh` 的命令，也会打印无法使用 `chsh` 时幂等写入 `~/.bash_profile` 的备用命令，是否执行由用户决定。

Bear 官方不发布二进制。运行时包和 GPL 对应源码发布在本仓库的 `bear-4.1.5` GitHub Release，fetch 脚本校验运行时包的固定 SHA-256。

## Opencode MCP

Tavily 和 Atlassian 由 Opencode 按需直接以 stdio 启动，不再经过 HTTP 代理或常驻 systemd 服务。只有必须复用本机浏览器状态的 Playwright 使用 `mcp-proxy`：

| 服务 | 传输方式 |
| --- | --- |
| Tavily | 本机 stdio |
| Playwright | `http://127.0.0.1:43102/mcp` |
| Atlassian（Jira + Confluence） | 本机 stdio，只读 |

Atlassian 固定为 `mcp-atlassian 0.23.0`，启动器同时设置 `READ_ONLY_MODE=true` 和 `--read-only`，不暴露 Jira/Confluence 写工具。Tavily 使用仓库内基于官方 0.2.20 commit `8c02eedf0fbfe9fe5fb87fb8f6e9fbd3aec157ff` 的多 key 版本；源码、固定依赖和预构建入口位于 `mcp/tavily-rotating/`，但实际 key 不进入 Git。Tavily MCP 超时设为 16 分钟，以覆盖 research 工具最长 15 分钟的官方轮询周期。

本机和 `dev` 的拓扑是：

```text
本机 OpenCode
  ├─ stdio -> 本机 Tavily 多 key 运行时
  ├─ HTTP 43102 -> 本机 Playwright
  └─ stdio -> 本机只读 Atlassian

dev OpenCode
  ├─ stdio -> dev Tavily 多 key 运行时
  ├─ HTTP 43102 -> SSH RemoteForward -> 本机 Playwright
  └─ stdio -> dev 只读 Atlassian 0.23.0
```

本机先应用配置，再准备 stdio 缓存和 Playwright 代理：

```bash
cd ~/.local/share/chezmoi
chezmoi apply
./setup-mcp-proxy.sh --remote-host dev
```

`fetch-tools.sh` 提供固定版本的 Node 和 uv/uvx。`setup-mcp-proxy.sh` 会准备 Atlassian 的 uv 缓存，验证两个 stdio 服务的工具列表，只安装 Playwright 的 `opencode-mcp-playwright.service`，并让 SSH reverse-forward 仅转发 `43102`。使用 `--no-tunnel` 可不创建隧道；缓存已经准备好时可加 `--offline`，严格禁止 npm/uv 下载。迁移成功后，旧 Tavily、Atlassian、Jira 和 Confluence HTTP 服务会被停用并删除。Playwright unit 更新失败时会恢复原 unit 和原启用状态。

远端机器先通过 chezmoi 和 `fetch-tools.sh` 安装配置、Node 与 uv，然后通过安全通道准备四个 `0600` 文件：

```bash
install -d -m 700 ~/.config/opencode/secrets
install -m 600 /secure/path/mcp-gateway.key ~/.config/opencode/mcp-gateway.key
install -m 600 /secure/path/tavily-keys.json ~/.config/opencode/secrets/tavily-keys.json
install -m 600 /secure/path/jira.pat ~/.config/opencode/secrets/jira.pat
install -m 600 /secure/path/confluence.pat ~/.config/opencode/secrets/confluence-local.pat
```

其中 `mcp-gateway.key` 只用于认证经 SSH 转发的 Playwright，必须与本机相同。OpenCode 通过 `{file:~/.config/opencode/mcp-gateway.key}` 直接读取它，不依赖 shell 环境变量。远端准备完成后，在 `dev` 自己执行仓库中的脚本；本机脚本不会 SSH 进去修改远端文件：

```bash
cd ~/.local/share/chezmoi
./setup-remote-mcp.sh
```

`tavily-keys.json` 格式为 `{"keys":["tvly-..."],"currentIndex":0}`。运行时沿用原有的简单轮转逻辑：每次工具调用选择当前 key、推进索引并写回 JSON。也可只提供旧的 `tavily-api.key` 作为单 key 回退。本机首次运行脚本时会把旧 `~/opencode-plugins/tavily-mcp/keys.json` 安全迁移到该位置。远端脚本从仓库内的多 key Tavily 源码包安装固定运行时，准备 `mcp-atlassian 0.23.0` 的 uv 缓存，并验证固定数量的只读 stdio 工具。它不创建 Tavily/Atlassian systemd 服务，也不监听 43101/43103；Opencode 启动时创建进程，退出时关闭进程。`--proxy-url URL` 会把 Tavily 后续启动使用的代理持久化到未纳入 chezmoi 的本机配置，`--offline` 可在 npm 与 uv 缓存完整时禁止下载安装。

不要把任何 key 或 PAT 提交到 Git。

Opencode 只在启动时加载配置。执行 `chezmoi apply` 后必须退出并重新启动 Opencode，当前运行中的会话不会从 HTTP 自动切换为 stdio。Playwright 用户服务随用户登录启动；如果需要未登录时也启动，可单独启用 linger。

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

仓库保留当前启用的 LazyVim DAP、clangd 和 Python extras，以及在线更新后的 `lazy-lock.json`。clangd 不再由 `fetch-tools.sh` 安装，而是由 LazyVim 的 clangd extra 交给 Mason 下载、升级和加入 Neovim 的 PATH；codelldb 同样由该 extra 在启用 DAP 时交给 Mason 管理。

从旧版本迁移时，先在 `:Mason` 中确认 clangd 已安装并用 `:LspInfo` 确认客户端命令来自 `~/.local/share/nvim/mason/bin/clangd`。确认无误后，可选清理旧 standalone 副本：

```bash
rm -rf ~/.local/opt/clangd ~/.local/bin/clangd
```

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
