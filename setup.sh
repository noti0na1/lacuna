#!/usr/bin/env bash
#
# One-time setup: build and publish the custom Scala 3 compiler/REPL snapshot
# (the dynamic-eval fork) that Agent.scala depends on
# (scala 3.*-RC1-bin-SNAPSHOT). It clones the fork's `main` branch, runs
# `sbt scala3-bootstrapped/publishLocalBin`, and the artifacts land in your
# local ivy repo (~/.ivy2/local) so scala-cli / scala can resolve them.
#
# A clone (not a source zip) is required: the dotty build reads the current
# git commit hash, so it needs a real .git directory.
#
# Requires: git, sbt, and a JDK. The build is heavy and can take many minutes.
#
# The clone/build happens in a temp directory by default; override with
# BUILD_DIR=/some/path ./setup.sh

set -euo pipefail

REPO_URL="https://github.com/noti0na1/dynamic-eval-scala-3"
REPO_BRANCH="main"

# Where to clone and build (kept out of this repo by default). The source is
# cloned into $BUILD_DIR/dynamic-eval-scala-3; override the parent with
# BUILD_DIR=/some/path ./setup.sh
BUILD_DIR="${BUILD_DIR:-${TMPDIR:-/tmp}}"
BUILD_DIR="${BUILD_DIR%/}"
SRC_DIR="$BUILD_DIR/dynamic-eval-scala-3"

have() { command -v "$1" >/dev/null 2>&1; }

for tool in git sbt java; do
  if ! have "$tool"; then
    echo "error: $tool not found on PATH." >&2
    exit 1
  fi
done

mkdir -p "$BUILD_DIR"

if [[ -d "$SRC_DIR/.git" ]]; then
  echo "==> Updating existing clone in $SRC_DIR"
  git -C "$SRC_DIR" fetch --depth 1 origin "$REPO_BRANCH"
  git -C "$SRC_DIR" reset --hard FETCH_HEAD
else
  echo "==> Cloning $REPO_URL ($REPO_BRANCH) into $SRC_DIR"
  rm -rf "$SRC_DIR"
  git clone --depth 1 --branch "$REPO_BRANCH" "$REPO_URL" "$SRC_DIR"
fi

echo "==> Building and publishing locally (this can take a while)"
cd "$SRC_DIR"
# `< /dev/null` so a stray sbt prompt can never hang an unattended run.
sbt "scala3-bootstrapped/publishLocalBin" < /dev/null

echo
echo "==> Done. Published the snapshot to ~/.ivy2/local."
echo "    You can now start the agent REPL with ./start.sh"
