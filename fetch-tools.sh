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

required=(sha256sum mktemp tar unzip cp mv rm mkdir ln chmod date dirname uname cat)
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
fetch chezmoi-linux-amd64-musl \
  https://github.com/twpayne/chezmoi/releases/download/v2.71.1/chezmoi-linux-amd64-musl \
  aab0315d65a5e898e3eaf9e134050e0ead02dbb751019d59eb0a475dd7cfc6cf
fetch zmx-0.7.0-linux-x86_64.tar.gz \
  https://zmx.sh/a/zmx-0.7.0-linux-x86_64.tar.gz \
  8b8783d7b120c9ffd0acf4aee37969054dc0dfef3c4f3a4728d2efd35f2e97a0
fetch clangd-linux-22.1.6.zip \
  https://github.com/clangd/clangd/releases/download/22.1.6/clangd-linux-22.1.6.zip \
  a9c77443af2e447ed467e84771848d3a6ac1c56f84bcfcde717e66318de77cfa
fetch bear-4.1.5-linux-x86_64-ubuntu22.04.tar.gz \
  https://github.com/chenbo-again/dotfiles/releases/download/bear-4.1.5/bear-4.1.5-linux-x86_64-ubuntu22.04.tar.gz \
  7b856aeef9ad8ab1f4a1e3ef3d1ef1776ce1ab195e24a0742d2d192a9d9db5e8
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

tar -xzf "$CACHE_DIR/nvim-linux-x86_64.tar.gz" -C "$stage/unpack"
mv -- "$stage/unpack/nvim-linux-x86_64" "$stage/opt/nvim"

mkdir -p "$stage/opt/chezmoi"
cp -- "$CACHE_DIR/chezmoi-linux-amd64-musl" "$stage/opt/chezmoi/chezmoi"
chmod 755 "$stage/opt/chezmoi/chezmoi"

mkdir -p "$stage/unpack/zmx"
tar -xzf "$CACHE_DIR/zmx-0.7.0-linux-x86_64.tar.gz" -C "$stage/unpack/zmx"
mkdir -p "$stage/opt/zmx"
cp -a "$stage/unpack/zmx/." "$stage/opt/zmx/"

unzip -q "$CACHE_DIR/clangd-linux-22.1.6.zip" -d "$stage/unpack"
mv -- "$stage/unpack/clangd_22.1.6" "$stage/opt/clangd"

tar -xzf "$CACHE_DIR/bear-4.1.5-linux-x86_64-ubuntu22.04.tar.gz" -C "$stage/unpack"
mv -- "$stage/unpack/bear-4.1.5" "$stage/opt/bear"

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

declare -A links=(
  [nvim]=../opt/nvim/bin/nvim
  [chezmoi]=../opt/chezmoi/chezmoi
  [zmx]=../opt/zmx/zmx
  [clangd]=../opt/clangd/bin/clangd
  [bear]=../opt/bear/libexec/bear/bin/bear-driver
  [yazi]=../opt/yazi/yazi
  [ya]=../opt/yazi/ya
  [atuin]=../opt/atuin/atuin
  [lazygit]=../opt/lazygit/lazygit
  [fzf]=../opt/fzf/fzf
  [rg]=../opt/ripgrep/rg
  [fd]=../opt/fd/fd
)

for command_name in "${!links[@]}"; do
  ln -s -- "${links[$command_name]}" "$stage/bin/$command_name"
  [[ -x $stage/bin/$command_name ]] || {
    printf 'Error: staged executable is missing: %s\n' "$command_name" >&2
    false
  }
done

items=(
  opt/nvim opt/chezmoi opt/zmx opt/clangd opt/bear opt/yazi opt/atuin
  opt/lazygit opt/fzf opt/ripgrep opt/fd
  bin/nvim bin/chezmoi bin/zmx bin/clangd bin/bear bin/yazi bin/ya
  bin/atuin bin/lazygit bin/fzf bin/rg bin/fd
)

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

for command_name in nvim chezmoi zmx clangd bear yazi ya atuin lazygit fzf rg fd; do
  "$TARGET_HOME/.local/bin/$command_name" --version >/dev/null
done

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
