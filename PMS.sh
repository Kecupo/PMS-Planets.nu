#!/bin/sh
printf '\033c\033]0;%s\a' PMS
base_path="$(dirname "$(realpath "$0")")"
"$base_path/PMS.x86_64" "$@"
