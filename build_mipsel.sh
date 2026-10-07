#!/bin/bash
set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLCHAIN_DIR="${PROJECT_ROOT}/toolchain/mipsel-linux-musl"
TARGET="mipsel-unknown-linux-musl"
ENABLE_CLEAN=false
ENABLE_SSTRIP=false

for arg in "$@"; do
    case "$arg" in
        --clean)
            ENABLE_CLEAN=true
            ;;
        --sstrip)
            ENABLE_SSTRIP=true
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --clean     Clean target build artifacts before compilation"
            echo "  --sstrip    Apply extreme ELF section stripping via sstrip"
            echo "  --help, -h  Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            exit 1
            ;;
    esac
done

if [ "$ENABLE_CLEAN" = true ]; then
    echo "[build_mipsel.sh] Cleaning build target..."
    rm -rf "${PROJECT_ROOT}/target"
fi

# 1. Download musl cross-toolchain if missing
if [ ! -f "${TOOLCHAIN_DIR}/bin/mipsel-linux-musl-gcc" ]; then
    echo "[build_mipsel.sh] Downloading toolchain x86_64-mipsel-linux-musl..."
    mkdir -p "${PROJECT_ROOT}/toolchain"
    curl -L "https://github.com/userdocs/qbt-musl-cross-make/releases/latest/download/x86_64-mipsel-linux-musl.tar.xz" -o "${PROJECT_ROOT}/toolchain/toolchain.tar.xz"
    tar -xf "${PROJECT_ROOT}/toolchain/toolchain.tar.xz" -C "${PROJECT_ROOT}/toolchain"
    rm -f "${PROJECT_ROOT}/toolchain/toolchain.tar.xz"
fi

# 2. Prepare compat_lib (dummy libunwind.a to satisfy rustc linker flags)
mkdir -p "${PROJECT_ROOT}/compat_lib"
if [ ! -f "${PROJECT_ROOT}/compat_lib/libunwind.a" ]; then
    "${TOOLCHAIN_DIR}/bin/mipsel-linux-musl-ar" cr "${PROJECT_ROOT}/compat_lib/libunwind.a"
fi

# 3. Create static linker wrapper script
cat << 'WRAPPER_EOF' > "${PROJECT_ROOT}/mips-linker.sh"
#!/bin/bash
ARGS=()
for arg in "$@"; do
    if [ "$arg" = "-Wl,-Bdynamic" ]; then
        ARGS+=("-Wl,-Bstatic")
    else
        ARGS+=("$arg")
    fi
done
exec mipsel-linux-musl-gcc -static -no-pie "${ARGS[@]}"
WRAPPER_EOF
chmod +x "${PROJECT_ROOT}/mips-linker.sh"

export PATH="${TOOLCHAIN_DIR}/bin:${PATH}"
MIPS_CFLAGS="-Os -march=24kc -mtune=24kc -mno-branch-likely -msoft-float -fno-ident -fno-stack-protector -fomit-frame-pointer -fno-unwind-tables -fno-asynchronous-unwind-tables -mno-shared -no-pie"
export CC_mipsel_unknown_linux_musl="mipsel-linux-musl-gcc"
export AR_mipsel_unknown_linux_musl="mipsel-linux-musl-ar"
export CFLAGS_mipsel_unknown_linux_musl="$MIPS_CFLAGS"
export TARGET_CC="mipsel-linux-musl-gcc"
export TARGET_CFLAGS="$MIPS_CFLAGS"

# 4. Configure .cargo/config.toml
mkdir -p "${PROJECT_ROOT}/.cargo"
cat << TOML_EOF > "${PROJECT_ROOT}/.cargo/config.toml"
[target.mipsel-unknown-linux-musl]
linker = "${PROJECT_ROOT}/mips-linker.sh"
rustflags = [
    "-C", "target-feature=+crt-static",
    "-C", "force-unwind-tables=no",
    "--remap-path-prefix==",
    "-C", "link-self-contained=no",
    "-C", "link-arg=-L${PROJECT_ROOT}/compat_lib",
    "-C", "link-arg=-Wl,--gc-sections",
    "-C", "link-arg=-Wl,--start-group",
    "-C", "link-arg=-lc",
    "-C", "link-arg=-lgcc",
    "-C", "link-arg=-lpthread",
    "-C", "link-arg=-lrt",
    "-C", "link-arg=-Wl,--end-group",
    "-C", "link-arg=-Wl,--build-id=none",
    "-C", "link-arg=-Wl,-z,norelro",
    "-C", "link-arg=-Wl,-O2",
    "-C", "link-arg=-Wl,--exclude-libs,ALL",
]

[unstable]
build-std = ["std", "panic_abort"]
build-std-features = ["optimize_for_size"]
TOML_EOF

echo "============================================"
echo "[build_mipsel.sh] Building yggnode for ${TARGET}..."
echo "============================================"

cargo +nightly build \
    --target "${TARGET}" \
    --profile small \
    --no-default-features \
    --features tun,ctl \
    -p yggdrasil \
    -Zbuild-std=std,panic_abort \
    -Zbuild-std-features=optimize_for_size

RAW_BIN="${PROJECT_ROOT}/target/${TARGET}/small/yggdrasil"
OUT_BIN="${PROJECT_ROOT}/yggdrasil-mipsel"

cp "${RAW_BIN}" "${OUT_BIN}"

# 5. Section stripping
echo "[build_mipsel.sh] Stripping binary symbols..."
mipsel-linux-musl-strip -s -R .comment -R .note -R .note.gnu.build-id -R .note.ABI-tag "${OUT_BIN}"

# 6. Optional sstrip
if [ "$ENABLE_SSTRIP" = true ]; then
    SSTRIP_BIN=""
    if command -v sstrip >/dev/null 2>&1; then
        SSTRIP_BIN="$(command -v sstrip)"
    elif [ -f "${PROJECT_ROOT}/tools/sstrip" ]; then
        SSTRIP_BIN="${PROJECT_ROOT}/tools/sstrip"
    fi

    if [ -n "${SSTRIP_BIN}" ]; then
        echo "[build_mipsel.sh] Applying sstrip header optimization..."
        "${SSTRIP_BIN}" "${OUT_BIN}"
    fi
fi

echo "============================================"
echo "[build_mipsel.sh] Done. Resulting binary:"
ls -lh "${OUT_BIN}"
file "${OUT_BIN}"
echo "============================================"
