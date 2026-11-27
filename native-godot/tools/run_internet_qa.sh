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
engine="${GODOT_BIN:-godot}"
XDG_DATA_HOME="$work/server" "$engine" --headless --path "$project" --script res://scripts/network/dedicated_server.gd >"$logs/server.log" 2>&1 &
pids+=("$!")
for i in $(seq 1 120); do
  if grep -q 'AURORA_ONLINE READY TLS Internet' "$logs/server.log"; then break; fi
  sleep .25
done
grep -F 'AURORA_ONLINE READY TLS Internet' "$logs/server.log"
# Generate the 45-second credential only once the server really listens.
export AURORA_QA_TICKET="$(node -e 'const b=require(process.argv[1]); console.log(b.issueTicket({room:process.env.AURORA_ROOM_ID,sub:"cd".repeat(32),nonce:"ef".repeat(18),exp:Math.floor(Date.now()/1000)+45,signingKey:process.env.AURORA_MATCH_SIGNING_KEY}))' "$project/../functions/src/online-matchmaking.js")"
AURORA_QA_CASE=untrusted XDG_DATA_HOME="$work/untrusted" timeout 20 "$engine" --headless --path "$project" --script res://scripts/network/online_internet_qa.gd >"$logs/untrusted.log" 2>&1
AURORA_QA_CASE=tampered XDG_DATA_HOME="$work/bad" timeout 20 "$engine" --headless --path "$project" --script res://scripts/network/online_internet_qa.gd >"$logs/denied.log" 2>&1
AURORA_QA_CASE=valid XDG_DATA_HOME="$work/good" timeout 35 "$engine" --headless --path "$project" --script res://scripts/network/online_internet_qa.gd >"$logs/good.log" 2>&1 &
good=$!; pids+=("$good")
for i in $(seq 1 80); do
  if grep -q 'V75251_AUTH_ACCEPTED' "$logs/server.log"; then break; fi
  if ! kill -0 "$good" 2>/dev/null; then cat "$logs/"*.log; exit 1; fi
  sleep .1
done
grep -F 'V75251_AUTH_ACCEPTED' "$logs/server.log"
AURORA_QA_CASE=replay XDG_DATA_HOME="$work/replay" timeout 20 "$engine" --headless --path "$project" --script res://scripts/network/online_internet_qa.gd >"$logs/replay.log" 2>&1
wait "$good"
cat "$logs/"*.log
for pair in 'untrusted UNTRUSTED' 'denied TAMPERED' 'replay REPLAY' 'good AUTH'; do
  read -r file label <<< "$pair"
  grep -F "V75251_TLS $label PASS" "$logs/$file.log"
done
grep -F 'V75251_WSS_INPUT moved=true acked=true' "$logs/good.log"
test "$(grep -c 'V75251_AUTH_ACCEPTED' "$logs/server.log")" -eq 1
test "$(grep -c 'V75251_AUTH_DENIED' "$logs/server.log")" -eq 2
if grep -E 'SCRIPT ERROR:|Parse Error' "$logs/"*.log; then exit 1; fi
