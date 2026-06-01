#!/usr/bin/env bash
#
# Start an interactive REPL with the inline LLM agent (Agent.scala) loaded.
#
# Once the REPL is up, call the agent at the prompt, pinning the result type:
#
#   scala> agent[Int]("what is the sum of 2 to 100")
#   scala> agent[String]("write a haiku about Scala")
#
# Configuration (API key, model, base URL, ...) is read from env.sh. Copy
# env.sh.example to env.sh and fill in your key before the first run.
#
# Any extra arguments are passed through to the REPL.

set -euo pipefail

# Work from the directory this script lives in, so relative paths (env.sh,
# Agent.scala, ./log) resolve no matter where it's invoked from.
cd "$(dirname "${BASH_SOURCE[0]}")"

# Pick a launcher: prefer scala-cli, fall back to the `scala` runner. Scala
# 3.5+ ships `scala` as scala-cli under the hood, so `scala repl` takes the
# same arguments (using directives, --server, ...).
if command -v scala-cli >/dev/null 2>&1; then
  RUNNER=scala-cli
elif command -v scala >/dev/null 2>&1; then
  RUNNER=scala
else
  echo "error: neither scala-cli nor scala found on PATH." >&2
  echo "  Install scala-cli: https://scala-cli.virtuslab.org/install" >&2
  exit 1
fi

if [[ ! -f env.sh ]]; then
  echo "error: env.sh not found." >&2
  echo "  Copy the example and add your API key:" >&2
  echo "    cp env.sh.example env.sh" >&2
  exit 1
fi

# Load AGENT_* configuration into the environment (env.sh uses `export`).
source ./env.sh

if [[ -z "${AGENT_API_KEY:-}" ]]; then
  echo "error: AGENT_API_KEY is not set in env.sh." >&2
  exit 1
fi

# -Xrepl-eval-log-dir (set via `//> using options` in Agent.scala) writes
# per-eval logs here; make sure the directory exists.
mkdir -p log

# Mark the start of a new session in the REPL transcript. The transcript
# (./session.repl, written by -Xrepl-history-file) is append-only across runs;
# the agent only reads history after the last marker (see SessionMarker /
# readRecentReplHistory in Agent.scala), so each run gets a fresh view without
# discarding the file's earlier contents.
printf '\n##### LACUNA SESSION %s #####\n\n' "$(date '+%Y-%m-%d %H:%M:%S')" >> session.repl

# Launch the REPL with the agent in scope. Using directives in Agent.scala pin
# the compiler version, dependencies, and REPL options.
exec "$RUNNER" repl --server=false Agent.scala "$@"
