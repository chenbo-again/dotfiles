#!/usr/bin/env bash
set -Eeuo pipefail

TARGET_HOME=$HOME
CACHE_DIR=${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles-tools
OFFLINE=0

usage() {
  cat <<'EOF'
Usage: ./fetch-tools.sh [OPTIONS]

Download and install the pinned Linux x86_64 command-line tools used by this
dotfiles repository.

Options:
  --home PATH       Install under PATH instead of $HOME
  --cache-dir PATH  Store/read downloaded artifacts in PATH
  --offline         Never use the network; require every artifact in cache
  -h, --help        Show this help

Online preparation:
  ./fetch-tools.sh --cache-dir /path/to/tool-cache

Offline installation:
  ./fetch-tools.sh --offline --cache-dir /path/to/tool-cache
EOF
}

while (($#)); do
  case $1 in
    --home)
      [[ $# -ge 2 ]] || { printf 'Error: --home requires a path.\n' >&2; exit 2; }
      TARGET_HOME=$2
      shift 2
      ;;
    --cache-dir)
      [[ $# -ge 2 ]] || { printf 'Error: --cache-dir requires a path.\n' >&2; exit 2; }
      CACHE_DIR=$2
      shift 2
      ;;
    --offline)
      OFFLINE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Error: unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case $(uname -s):$(uname -m) in
  Linux:x86_64) ;;
  *)
    printf 'Error: this tool set supports Linux x86_64 only.\n' >&2
    exit 1
    ;;
esac

required=(sha256sum mktemp tar xz cp mv rm mkdir ln chmod date dirname uname cat grep dd)
((OFFLINE)) || required+=(curl)
for command_name in "${required[@]}"; do
  command -v "$command_name" >/dev/null 2>&1 || {
    printf 'Error: required command not found: %s\n' "$command_name" >&2
    exit 1
  }
done

mkdir -p "$CACHE_DIR" "$TARGET_HOME/.local"
CACHE_DIR=$(cd "$CACHE_DIR" && pwd -P)
TARGET_HOME=$(cd "$TARGET_HOME" && pwd -P)

install_zsh=1
if command -v zsh >/dev/null 2>&1 || [[ -x $TARGET_HOME/.local/bin/zsh ]]; then
  install_zsh=0
  printf 'Zsh is already available; skipping its installation.\n'
fi

fetch() {
  local filename=$1 url=$2 expected=$3
  local destination=$CACHE_DIR/$filename
  local temporary=$destination.part.$$

  if [[ -f $destination ]] && printf '%s  %s\n' "$expected" "$destination" | sha256sum --check --status; then
    return
  fi

  if ((OFFLINE)); then
    printf 'Error: missing or invalid cached artifact: %s\n' "$destination" >&2
    exit 1
  fi

  rm -f -- "$temporary"
  printf 'Downloading %s...\n' "$filename"
  curl --fail --location --retry 3 --output "$temporary" "$url"
  printf '%s  %s\n' "$expected" "$temporary" | sha256sum --check --status || {
    rm -f -- "$temporary"
    printf 'Error: checksum mismatch for %s\n' "$filename" >&2
    exit 1
  }
  mv -- "$temporary" "$destination"
}

fetch nvim-linux-x86_64.tar.gz \
  https://github.com/neovim/neovim/releases/download/v0.12.4/nvim-linux-x86_64.tar.gz \
  012bf3fcac5ade43914df3f174668bf64d05e049a4f032a388c027b1ebd78628
fetch chezmoi-linux-amd64 \
  https://github.com/twpayne/chezmoi/releases/download/v2.71.1/chezmoi-linux-amd64 \
  37d22a4947134c3d6cb87d7a2be7caa63684a27d57e2999c86564126e79424ae
fetch zmx-0.7.0-linux-x86_64.tar.gz \
  https://zmx.sh/a/zmx-0.7.0-linux-x86_64.tar.gz \
  8b8783d7b120c9ffd0acf4aee37969054dc0dfef3c4f3a4728d2efd35f2e97a0
fetch bear-4.1.5-linux-x86_64-ubuntu22.04.tar.gz \
  https://github.com/chenbo-again/dotfiles/releases/download/bear-4.1.5/bear-4.1.5-linux-x86_64-ubuntu22.04.tar.gz \
  7b856aeef9ad8ab1f4a1e3ef3d1ef1776ce1ab195e24a0742d2d192a9d9db5e8
fetch autossh-1.4g-linux-x86_64.tar.gz \
  https://github.com/chenbo-again/dotfiles/releases/download/autossh-1.4g/autossh-1.4g-linux-x86_64.tar.gz \
  08e103809fdb64d1b0dfd044fcadca4463f99359e256b7715cb5362e9821ba51
fetch yazi-x86_64-unknown-linux-musl.zip \
  https://github.com/sxyazi/yazi/releases/download/v26.5.6/yazi-x86_64-unknown-linux-musl.zip \
  1031a02560d053301537195a6661d227c15cb4ce5c30481050b31e2b88681bff
fetch atuin-x86_64-unknown-linux-musl.tar.gz \
  https://github.com/atuinsh/atuin/releases/download/v18.17.1/atuin-x86_64-unknown-linux-musl.tar.gz \
  5772df4121174a9f0b71c17260727794fde22a71b5a3ee5ac07b227eebcbfa9a
fetch lazygit_0.63.1_linux_x86_64.tar.gz \
  https://github.com/jesseduffield/lazygit/releases/download/v0.63.1/lazygit_0.63.1_linux_x86_64.tar.gz \
  8e033bc78c8e192dee9510e951f6c9e154289b7198d22c924ed1d0a951b0dac1
fetch fzf-0.74.1-linux_amd64.tar.gz \
  https://github.com/junegunn/fzf/releases/download/v0.74.1/fzf-0.74.1-linux_amd64.tar.gz \
  df53438be5f51e151bb4044d78fda72bdfe209e3ecd2baecae48e8dea370c81b
fetch ripgrep-15.2.0-x86_64-unknown-linux-musl.tar.gz \
  https://github.com/BurntSushi/ripgrep/releases/download/15.2.0/ripgrep-15.2.0-x86_64-unknown-linux-musl.tar.gz \
  33e15bcf1624b25cdd2a55813a47a2f95dbe126268203e76aa6a585d1e7b149c
fetch fd-v10.4.2-x86_64-unknown-linux-musl.tar.gz \
  https://github.com/sharkdp/fd/releases/download/v10.4.2/fd-v10.4.2-x86_64-unknown-linux-musl.tar.gz \
  e3257d48e29a6be965187dbd24ce9af564e0fe67b3e73c9bdcd180f4ec11bdde
fetch zsh-bin-5.8-v6.1.1-linux-x86_64.tar.gz \
  https://github.com/chenbo-again/dotfiles/releases/download/zsh-bin-5.8-v6.1.1/zsh-bin-5.8-v6.1.1-linux-x86_64.tar.gz \
  02fae3ce56e3087f32019e186cd2e99eef54b6207432fe05f45cde1b8a83dbe2
fetch helix-25.07.1-x86_64-linux.tar.xz \
  https://github.com/helix-editor/helix/releases/download/25.07.1/helix-25.07.1-x86_64-linux.tar.xz \
  3f08e63ecd388fff657ad39722f88bb03dcf326f1f2da2700d99e1dc40ab2e8b
fetch opencode-linux-x64.tar.gz \
  https://github.com/anomalyco/opencode/releases/download/v1.18.6/opencode-linux-x64.tar.gz \
  b5b7fa9509757b60249de8f22874b641a8b59a61b2e177b6d24e46805c7f352d
fetch age-v1.3.1-linux-amd64.tar.gz \
  https://github.com/FiloSottile/age/releases/download/v1.3.1/age-v1.3.1-linux-amd64.tar.gz \
  bdc69c09cbdd6cf8b1f333d372a1f58247b3a33146406333e30c0f26e8f51377
fetch rtk-x86_64-unknown-linux-musl.tar.gz \
  https://github.com/rtk-ai/rtk/releases/download/v0.44.0/rtk-x86_64-unknown-linux-musl.tar.gz \
  3c3316cfc068e372432b415faeab73d46f8047750d488dd94d01d8d9f016a2a1
fetch clangd-linux-22.1.6.zip \
  https://github.com/clangd/clangd/releases/download/22.1.6/clangd-linux-22.1.6.zip \
  a9c77443af2e447ed467e84771848d3a6ac1c56f84bcfcde717e66318de77cfa
fetch sttr_Linux_x86_64.tar.gz \
  https://github.com/abhimanyu003/sttr/releases/download/v0.2.30/sttr_Linux_x86_64.tar.gz \
  f4cb5b240853b53f67d7b789c9cf5969e794675c5c38aad2ed5ff2c065be4c19
fetch busybox \
  https://busybox.net/downloads/binaries/1.35.0-x86_64-linux-musl/busybox \
  6e123e7f3202a8c1e9b1f94d8941580a25135382b99e8d3e34fb858bba311348
fetch fnm-linux.zip \
  https://github.com/Schniz/fnm/releases/download/v1.39.0/fnm-linux.zip \
  7807664f39d39fc518da1c35ba0181e4b3267603c4b1dedeb4b5fc6ae440a224
stage=$(mktemp -d "$TARGET_HOME/.local/.fetch-tools-stage.XXXXXX")
backup=
backed_up=0
installed=()

cleanup() {
  rm -rf -- "$stage"
}

rollback() {
  local item
  trap - ERR
  for ((i=${#installed[@]}-1; i>=0; i--)); do
    item=${installed[i]}
    rm -rf -- "$TARGET_HOME/.local/$item"
    if [[ -n $backup && -e $backup/$item || -L $backup/$item ]]; then
      mkdir -p -- "$TARGET_HOME/.local/$(dirname -- "$item")"
      mv -- "$backup/$item" "$TARGET_HOME/.local/$item"
    fi
  done
  cleanup
  printf 'Error: tool installation failed; previous files were restored.\n' >&2
}

trap cleanup EXIT
trap rollback ERR

mkdir -p "$stage/opt" "$stage/bin" "$stage/unpack"

mkdir -p "$stage/opt/busybox"
cp -- "$CACHE_DIR/busybox" "$stage/opt/busybox/busybox"
chmod 755 "$stage/opt/busybox/busybox"
rm -rf "$stage/bin/unzip"
cp "$stage/opt/busybox/busybox" "$stage/bin/unzip"
chmod 755 "$stage/bin/unzip"
export PATH="$stage/bin:$PATH"

tar -xzf "$CACHE_DIR/nvim-linux-x86_64.tar.gz" -C "$stage/unpack"
mv -- "$stage/unpack/nvim-linux-x86_64" "$stage/opt/nvim"

mkdir -p "$stage/opt/chezmoi"
cp -- "$CACHE_DIR/chezmoi-linux-amd64" "$stage/opt/chezmoi/chezmoi"
chmod 755 "$stage/opt/chezmoi/chezmoi"
tar -xzf "$CACHE_DIR/age-v1.3.1-linux-amd64.tar.gz" -C "$stage/unpack"
cp -- "$stage/unpack/age/age" "$stage/unpack/age/age-keygen" "$stage/opt/chezmoi/"
chmod 755 "$stage/opt/chezmoi/age" "$stage/opt/chezmoi/age-keygen"

mkdir -p "$stage/unpack/zmx"
tar -xzf "$CACHE_DIR/zmx-0.7.0-linux-x86_64.tar.gz" -C "$stage/unpack/zmx"
mkdir -p "$stage/opt/zmx"
cp -a "$stage/unpack/zmx/." "$stage/opt/zmx/"

tar -xzf "$CACHE_DIR/bear-4.1.5-linux-x86_64-ubuntu22.04.tar.gz" -C "$stage/unpack"
mv -- "$stage/unpack/bear-4.1.5" "$stage/opt/bear"

mkdir -p "$stage/opt/autossh"
tar -xzf "$CACHE_DIR/autossh-1.4g-linux-x86_64.tar.gz" -C "$stage/opt/autossh"
chmod 755 "$stage/opt/autossh/autossh"

unzip -q "$CACHE_DIR/yazi-x86_64-unknown-linux-musl.zip" -d "$stage/unpack"
mv -- "$stage/unpack/yazi-x86_64-unknown-linux-musl" "$stage/opt/yazi"

tar -xzf "$CACHE_DIR/atuin-x86_64-unknown-linux-musl.tar.gz" -C "$stage/unpack"
mv -- "$stage/unpack/atuin-x86_64-unknown-linux-musl" "$stage/opt/atuin"

mkdir -p "$stage/opt/lazygit"
tar -xzf "$CACHE_DIR/lazygit_0.63.1_linux_x86_64.tar.gz" -C "$stage/opt/lazygit"
mkdir -p "$stage/opt/fzf"
tar -xzf "$CACHE_DIR/fzf-0.74.1-linux_amd64.tar.gz" -C "$stage/opt/fzf"
tar -xzf "$CACHE_DIR/ripgrep-15.2.0-x86_64-unknown-linux-musl.tar.gz" -C "$stage/unpack"
mv -- "$stage/unpack/ripgrep-15.2.0-x86_64-unknown-linux-musl" "$stage/opt/ripgrep"
tar -xzf "$CACHE_DIR/fd-v10.4.2-x86_64-unknown-linux-musl.tar.gz" -C "$stage/unpack"
mv -- "$stage/unpack/fd-v10.4.2-x86_64-unknown-linux-musl" "$stage/opt/fd"

tar -xJf "$CACHE_DIR/helix-25.07.1-x86_64-linux.tar.xz" -C "$stage/unpack"
mv -- "$stage/unpack/helix-25.07.1-x86_64-linux" "$stage/opt/helix"

mkdir -p "$stage/opt/opencode"
tar -xzf "$CACHE_DIR/opencode-linux-x64.tar.gz" -C "$stage/opt/opencode"
chmod 755 "$stage/opt/opencode/opencode"

mkdir -p "$stage/opt/rtk"
tar -xzf "$CACHE_DIR/rtk-x86_64-unknown-linux-musl.tar.gz" -C "$stage/opt/rtk"
chmod 755 "$stage/opt/rtk/rtk"

unzip -q "$CACHE_DIR/clangd-linux-22.1.6.zip" -d "$stage/unpack"
mv -- "$stage/unpack/clangd_22.1.6" "$stage/opt/clangd"

mkdir -p "$stage/opt/sttr"
tar -xzf "$CACHE_DIR/sttr_Linux_x86_64.tar.gz" -C "$stage/opt/sttr"

mkdir -p "$stage/opt/fnm"
unzip -q "$CACHE_DIR/fnm-linux.zip" -d "$stage/opt/fnm"
chmod 755 "$stage/opt/fnm/fnm"

if ((install_zsh)); then
  tar -xzf "$CACHE_DIR/zsh-bin-5.8-v6.1.1-linux-x86_64.tar.gz" -C "$stage/unpack"
  mv -- "$stage/unpack/zsh-bin-5.8-v6.1.1" "$stage/opt/zsh"
  "$stage/opt/zsh/share/zsh/5.8/scripts/relocate" \
    -s "$stage/opt/zsh" \
    -d "$TARGET_HOME/.local/opt/zsh"
fi

declare -A links=(
  [nvim]=../opt/nvim/bin/nvim
  [chezmoi]=../opt/chezmoi/chezmoi
  [opencode]=../opt/opencode/opencode
  [rtk]=../opt/rtk/rtk
  [clangd]=../opt/clangd/bin/clangd
  [sttr]=../opt/sttr/sttr
  [unzip]=../opt/busybox/busybox
  [age]=../opt/chezmoi/age
  [age-keygen]=../opt/chezmoi/age-keygen
  [zmx]=../opt/zmx/zmx
  [autossh]=../opt/autossh/autossh
  [bear]=../opt/bear/libexec/bear/bin/bear-driver
  [yazi]=../opt/yazi/yazi
  [ya]=../opt/yazi/ya
  [atuin]=../opt/atuin/atuin
  [lazygit]=../opt/lazygit/lazygit
  [fzf]=../opt/fzf/fzf
  [rg]=../opt/ripgrep/rg
  [fd]=../opt/fd/fd
  [hx]=../opt/helix/hx
  [fnm]=../opt/fnm/fnm
)

if ((install_zsh)); then
  links[zsh]=../opt/zsh/bin/zsh
fi

for command_name in "${!links[@]}"; do
  ln -sf -- "${links[$command_name]}" "$stage/bin/$command_name"
  [[ -x $stage/bin/$command_name ]] || {
    printf 'Error: staged executable is missing: %s\n' "$command_name" >&2
    false
  }
done

items=(
  opt/nvim opt/chezmoi opt/opencode   opt/rtk opt/zmx opt/bear opt/yazi opt/atuin
  opt/lazygit opt/fzf opt/ripgrep opt/fd opt/helix opt/clangd opt/sttr
  opt/busybox opt/fnm opt/autossh
  bin/nvim bin/chezmoi   bin/opencode bin/rtk bin/clangd bin/age bin/age-keygen bin/zmx bin/bear bin/yazi bin/ya
  bin/atuin bin/lazygit bin/fzf bin/rg bin/fd bin/hx
  bin/sttr bin/unzip bin/fnm
)
if ((install_zsh)); then
  items+=(opt/zsh bin/zsh)
fi

timestamp=$(date +%Y%m%d-%H%M%S)
backup=$TARGET_HOME/.local/share/tool-fetch-backups/$timestamp-$$
mkdir -p "$backup"

for item in "${items[@]}"; do
  target=$TARGET_HOME/.local/$item
  source=$stage/$item
  mkdir -p -- "$(dirname -- "$target")" "$backup/$(dirname -- "$item")"
  if [[ -e $target || -L $target ]]; then
    mv -- "$target" "$backup/$item"
    backed_up=1
  fi
  mv -- "$source" "$target"
  installed+=("$item")
done

commands=(nvim chezmoi opencode rtk clangd age age-keygen zmx autossh bear yazi ya atuin lazygit fzf rg fd hx sttr unzip fnm)
if ((install_zsh)); then
  commands+=(zsh)
fi
export PATH="$TARGET_HOME/.local/bin:$PATH"
for command_name in "${commands[@]}"; do
  "$TARGET_HOME/.local/bin/$command_name" --version >/dev/null 2>&1 ||     "$TARGET_HOME/.local/bin/$command_name" version >/dev/null 2>&1 || true
done

FNM_DIR=${FNM_DIR:-$TARGET_HOME/.local/share/fnm}
if ((OFFLINE)); then
  if [[ ! -d $FNM_DIR/node-versions ]] || [[ -z $(command ls "$FNM_DIR/node-versions") ]]; then
    printf 'Error: offline mode requires fnm node versions pre-seeded in %s.\n' "$FNM_DIR" >&2
    exit 1
  fi
else
  FNM_DIR=$FNM_DIR "$TARGET_HOME/.local/bin/fnm" install 24 >/dev/null
  FNM_DIR=$FNM_DIR "$TARGET_HOME/.local/bin/fnm" default 24 >/dev/null
  printf 'Installed Node 24 via fnm under %s.\n' "$FNM_DIR"
fi

trap - ERR
cleanup
trap - EXIT

printf 'Installed tools under %s/.local.\n' "$TARGET_HOME"
printf 'Downloaded artifacts are cached in %s.\n' "$CACHE_DIR"
if ((backed_up)); then
  printf 'Previous tool files were moved to %s.\n' "$backup"
else
  rm -rf -- "$backup"
fi

if ((install_zsh)); then
  printf '\nPortable Zsh was installed. To make it your login shell, run:\n'
  printf '  ZSH_PATH=%q\n' "$TARGET_HOME/.local/bin/zsh"
  printf '  grep -qxF "$ZSH_PATH" /etc/shells || printf '\''%%s\\n'\'' "$ZSH_PATH" | sudo tee -a /etc/shells\n'
  printf '  chsh -s "$ZSH_PATH"\n'
  cat <<'INSTRUCTIONS'

If you cannot use chsh, run this command to start portable Zsh from
interactive Bash login shells (it will not add the block twice):

grep -qxF '# Start portable Zsh from interactive Bash login shells.' "$HOME/.bash_profile" 2>/dev/null || cat >> "$HOME/.bash_profile" <<'ZSH_PROFILE'

# Start portable Zsh from interactive Bash login shells.
if [[ $- == *i* ]] && [[ -x "$HOME/.local/bin/zsh" ]] && [[ -z ${ZSH_VERSION:-} ]]; then
  exec "$HOME/.local/bin/zsh" -l
fi
ZSH_PROFILE
INSTRUCTIONS
fi
