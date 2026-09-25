#!/bin/sh
# クローンした直後に 1 回だけ実行する。Git の hook はリポジトリに含まれないため、
# hooksPath を .githooks に向けて、pre-commit / pre-push を有効にする。
#   sh .githooks/setup.sh
set -e
cd "$(git rev-parse --show-toplevel)"
git config core.hooksPath .githooks
chmod +x .githooks/pre-commit .githooks/pre-push .githooks/scan.sh
echo "有効化した: core.hooksPath = $(git config core.hooksPath)"
