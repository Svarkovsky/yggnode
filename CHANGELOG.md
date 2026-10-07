# Changelog

All notable changes to this project will be documented in this file.

## [0.3.0] - 2026-10-07

### Architecture & Compatibility Fixes
- **32-bit MIPS MTU Synchronization Fix:** Replaced `AtomicU64` with `AtomicU32` in `crates/yggdrasil/src/ipv6rwc.rs`. Upstream MTU clamping strictly bounds values between 1280 and 65535, making a 32-bit integer fully sufficient. This eliminates compiler errors on 32-bit MIPS targets lacking hardware 64-bit atomic instructions.
- **Static Musl Linkage:** Fixed `-lunwind` and dynamic `libc.so` resolution when cross-compiling with custom musl toolchains. All binaries are 100% statically linked and run identically across uClibc, musl, and glibc systems.

### Resource & Feature Footprint Optimization
- **Stripped Heavy Transports:** Built exclusively with `--no-default-features --features tun,ctl`, cutting QUIC, WebSockets, and dynamic Crypto Key Routing (CKR).
- **Embedded Init Compatibility:** Removed systemd hooks in favor of lightweight standalone operation, saving memory and eliminating unnecessary dependencies on home routers.
- **Low RAM Profile:** Tested and verified under live network routing on real hardware (MediaTek MT7628, 64 MB RAM) with stable memory consumption around ~2.5 MB RSS.

### Multi-Architecture CI/CD & Packaging
- **Automated Matrix Builds:** Implemented `.github/workflows/release.yml` with cross-compilation toolchains from `musl-cross-make` for 6 architectures:
  - `mips-unknown-linux-musl` (MIPS Big-Endian, OpenWrt ath79)
  - `mipsel-unknown-linux-musl` (MIPS Little-Endian, OpenWrt / Padavan / Keenetic ramips)
  - `armv7-unknown-linux-musleabihf` (ARMv7 Cortex-A7/A9, hard-float)
  - `aarch64-unknown-linux-musl` (ARM64 Cortex-A53/A72)
  - `x86_64-unknown-linux-musl` (64-bit PC / VPS / servers)
  - `i686-unknown-linux-musl` (32-bit x86 legacy hardware)
- **Pre-release Verification:** Each build passes a complete validation cycle: musl compilation with LTO, section stripping with `sstrip`, execution check under QEMU (`--version`), and packaging into distribution archives with md5 checksums.
- **Packaging:** Added `scripts/package_target.sh` to build self-contained ZIP archives containing the binary, sample configuration (`yggdrasil.sample.toml`), and a universal SysV / Entware init script (`S25yggnode`).

### Documentation
- **Peer Transport Guidance:** Documented strict `tcp://` scheme requirement for 32-bit MIPS hardware, detailing rustls segmentation fault on TLS handshakes and compile-time removal of `ws://` and `quic://` transports. Recommended `peers_updater` filtering.
