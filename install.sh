#!/usr/bin/env bash
set -euo pipefail
url="https://github.com/alcure/winmarchy-vfio.git"
target="$HOME/.config/omarchy/plugins/psycrow.winmarchy"
if [[ ! -d $target ]]; then
  omarchy plugin add "$url" --enable
fi
exec "$target/bin/setup" "$@"
