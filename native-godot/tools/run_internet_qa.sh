#!/usr/bin/env bash
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
logs="$project/out/online/internet"
mkdir -p "$logs"
pids=()
cleanup(){ for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; done; rm -rf "$work"; }
trap cleanup EXIT
openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj /CN=localhost -addext subjectAltName=DNS:localhost -keyout "$work/key.pem" -out "$work/cert.pem" >/dev/null 2>&1
export AURORA_INTERNET_SERVER=1 AURORA_INTERNET_QA=1
export AURORA_ROOM_ID=ci-internet-instance-unique
export AURORA_MATCH_SIGNING_KEY="$(openssl rand -hex 32)" AURORA_TLS_CERT="$work/cert.pem" AURORA_TLS_KEY="$work/key.pem"
export AURORA_QA_TICKET="$(node -e 'const b=require(process.argv[1]); console.log(b.issueTicket({room:process.env.AURORA_ROOM_ID,sub:"cd".repeat(32),nonce:"ef".repeat(18),exp:Math.floor(Date.now()/1000)+45,signingKey:process.env.AURORA_MATCH_SIGNING_KEY}))' "$project/../functions/src/online-matchmaking.js")"
engine="${GODOT_BIN:-godot}"
XDG_DATA_HOME="$work/server" "$engine" --headless --path "$project" --script res://scripts/network/dedicated_server.gd >"$logs/server.log" 2>&1 &
pids+=("$!")
for i in $(seq 1 120); do
  if grep -q 'AURORA_ONLINE READY TLS Internet' "$logs/server.log"; then break; fi
  sleep .25
done
grep -F 'AURORA_ONLINE READY TLS Internet' "$logs/server.log"
AURORA_QA_DENIED=1 XDG_DATA_HOME="$work/bad" timeout 20 "$engine" --headless --path "$project" --script res://scripts/network/online_internet_qa.gd >"$logs/denied.log" 2>&1
XDG_DATA_HOME="$work/good" timeout 25 "$engine" --headless --path "$project" --script res://scripts/network/online_internet_qa.gd >"$logs/good.log" 2>&1
cat "$logs/"*.log
grep -F 'V75251_TLS DENIED PASS' "$logs/denied.log"
grep -F 'V75251_TLS AUTH PASS' "$logs/good.log"
grep -F 'V75251_AUTH_ACCEPTED' "$logs/server.log"
grep -F 'V75251_AUTH_DENIED' "$logs/server.log"
if grep -E 'SCRIPT ERROR:|Parse Error' "$logs/"*.log; then exit 1; fi
