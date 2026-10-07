#!/bin/bash
set -e

BINARY="${1:?Binary path required}"
ARCH="${2:?Architecture name required}"
VERSION="${3:-v0.3.0}"
OUT_DIR="${4:-Releases}"
CFLAGS_INFO="${5:-Not specified}"
LDFLAGS_INFO="${6:-Not specified}"
TARGET_TRIPLE="${7:-Not specified}"
CC_NAME="${8:-gcc}"
TOOLCHAIN_INFO="${9:-musl-cross-make}"

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

case "$OUT_DIR" in
    /*) TARGET_DIR="$OUT_DIR" ;;
    *)  TARGET_DIR="$PROJECT_ROOT/$OUT_DIR" ;;
esac

STAGE_DIR="$(mktemp -d)"
mkdir -p "$TARGET_DIR"

cp "$BINARY" "$STAGE_DIR/yggdrasil"

cat << 'SAMPLE_CONF' > "$STAGE_DIR/yggdrasil.sample.toml"
# yggnode minimal configuration sample
# Generate keys with: yggdrasil --genconf

# Public peers to connect to (tcp:// or tls://)
peers = [
  "tcp://ygg-hel-1.wgos.org:45170",
  "tcp://ygg1.mk16.de:1337"
]

# Disable incoming public listener if you are an edge client/router
listen = []

# Admin socket for CLI control commands (yggdrasil getPeers, etc.)
admin_listen = "tcp://127.0.0.1:9001"

# Kernel TUN interface name & MTU
if_name = "ygg0"
if_mtu = 65535

# Disable multicast on local network
multicast_interfaces = []

[node_info]
node_info_privacy = true

[firewall]
enable = false
SAMPLE_CONF

cat << 'STARTUP' > "$STAGE_DIR/S25yggnode"
#!/bin/sh
ENABLED=yes
[ "$ENABLED" != "yes" ] && exit 0

PROG="yggdrasil"
DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="$DIR/$PROG"
CONF="$DIR/yggdrasil.toml"
LOG="$DIR/yggnode.log"
PIDFILE="/tmp/yggnode.pid"

start() {
    [ -f "$PIDFILE" ] && kill -0 $(cat "$PIDFILE") 2>/dev/null && echo "$PROG is already running" && return 0
    [ ! -f "$CONF" ] && echo "Config not found: $CONF (copy yggdrasil.sample.toml)" && exit 1
    
    echo -n "Starting $PROG... "
    # Allow IPv6 forwarding between LAN and ygg0
    ip6tables -C FORWARD -i br0 -o ygg0 -j ACCEPT 2>/dev/null || ip6tables -I FORWARD -i br0 -o ygg0 -j ACCEPT 2>/dev/null
    ip6tables -C FORWARD -i ygg0 -o br0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || ip6tables -I FORWARD -i ygg0 -o br0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null

    "$BIN" -c "$CONF" -l warn >> "$LOG" 2>&1 &
    echo $! > "$PIDFILE"
    sleep 1
    if kill -0 $(cat "$PIDFILE") 2>/dev/null; then
        echo "OK"
    else
        echo "FAILED"
        rm -f "$PIDFILE"
    fi
}

stop() {
    echo -n "Stopping $PROG... "
    if [ -f "$PIDFILE" ]; then
        PID=$(cat "$PIDFILE")
        kill "$PID" 2>/dev/null
        sleep 1
        kill -9 "$PID" 2>/dev/null
        rm -f "$PIDFILE"
    else
        killall "$PROG" 2>/dev/null
    fi
    echo "OK"
}

case "$1" in
    start)   start ;;
    stop)    stop ;;
    restart) stop; sleep 1; start ;;
    status)  [ -f "$PIDFILE" ] && kill -0 $(cat "$PIDFILE") 2>/dev/null && echo "Running" || echo "Stopped" ;;
    peers)   "$BIN" -c "$CONF" getPeers ;;
    *)       echo "Usage: $0 {start|stop|restart|status|peers}"; exit 1 ;;
esac
STARTUP
chmod +x "$STAGE_DIR/S25yggnode"

cat << BUILD_INFO > "$STAGE_DIR/build_info.txt"
Package: yggnode
Version: ${VERSION}
Target Triple: ${TARGET_TRIPLE}
Architecture Name: ${ARCH}
Build Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

Upstream Reference:
  Repository: https://github.com/Revertron/Yggdrasil-ng
  Base Commit: 59e8973d4ed3888ba021785b0808e68c7874449f
  License: Mozilla Public License 2.0 (MPL-2.0)

Feature Profile:
  Features: --no-default-features --features tun,ctl
  Excluded: quic, ws (WebSockets), ckr (crypto key routing), systemd

Compilation Flags:
  CFLAGS:  ${CFLAGS_INFO}
  LDFLAGS: ${LDFLAGS_INFO}
  Rust:    cargo +nightly --profile small -Zbuild-std=std,panic_abort -Zbuild-std-features=optimize_for_size

Toolchain Details:
  Compiler: ${CC_NAME}
  Info:     ${TOOLCHAIN_INFO}
  C Library: musl libc (static linkage)
BUILD_INFO

(
    cd "$STAGE_DIR"
    find . -type f ! -name "md5sums.txt" -print0 | xargs -0 md5sum > md5sums.txt
    ZIP_NAME="yggnode-${VERSION}-${ARCH}-static.zip"
    zip -r "$TARGET_DIR/$ZIP_NAME" yggdrasil yggdrasil.sample.toml S25yggnode build_info.txt md5sums.txt >/dev/null
    cd "$TARGET_DIR"
    md5sum "$ZIP_NAME" > "$ZIP_NAME.md5"
    echo "Packaged $TARGET_DIR/$ZIP_NAME"
)

rm -rf "$STAGE_DIR"
