# Roadmap & Project Status

This document tracks completed optimization milestones, current project status, and future plans for `yggnode`.

---

## Current Status: Production Deployment & Hardware Verification

The core optimization targets, 32-bit architecture fixes, and multi-architecture build pipeline are implemented, tested on real hardware (MediaTek MT7628 running Linux 3.4 / Padavan), and released in v0.3.0.

The project is running in production across home routers, and we are collecting real-world stability feedback under continuous network traffic.

---

## Completed Milestones (v0.3.0)

### 1. 32-bit Architecture Fixes
- [x] Fixed broken 32-bit MIPS compilation in `crates/yggdrasil/src/ipv6rwc.rs` by replacing `AtomicU64` with `AtomicU32` for overlay MTU tracking.
- [x] Verified zero atomic lock emulation overhead and full compatibility with MIPS 24KEc / 74Kc SoCs without native 64-bit atomics.

### 2. Feature & Memory Footprint Pruning
- [x] Isolated build configuration strictly to `--no-default-features --features tun,ctl`.
- [x] Stripped heavy optional transports: QUIC, WebSockets, dynamic Crypto Key Routing (CKR), and systemd service hooks.
- [x] Verified low RAM consumption: ~2.5 MB RSS under continuous transit traffic on 64 MB RAM routers.

### 3. Static Musl Toolchain & Binary Optimization
- [x] Configured static linking against musl libc across all target architectures with zero runtime libc dependencies.
- [x] Configured release profile with `opt-level = "z"`, `lto = true`, `panic = "abort"`, and `-Zbuild-std=std,panic_abort -Zbuild-std-features=optimize_for_size`.
- [x] Integrated `sstrip` from ELFkickers to remove non-essential ELF header sections.
- [x] Packaged binaries into self-contained distribution archives (~1.2 - 1.5 MB ZIP) containing binary, sample configuration, and SysV / Entware init script.

### 4. Multi-Architecture CI/CD Pipeline
- [x] Automated cross-compilation pipeline on GitHub Actions supporting 6 hardware architectures:
  - `mips-unknown-linux-musl` (MIPS Big-Endian, Qualcomm Atheros AR9xxx / QCA95xx, OpenWrt ath79)
  - `mipsel-unknown-linux-musl` (MIPS Little-Endian, MediaTek MT7620 / MT7621 / MT7628, OpenWrt / Padavan / Keenetic ramips)
  - `armv7-unknown-linux-musleabihf` (ARMv7-A 32-bit, Raspberry Pi 2 / Zero 2W, Orange Pi, hard-float)
  - `aarch64-unknown-linux-musl` (ARM64 / AArch64, Raspberry Pi 3/4/5, modern ARM routers and servers)
  - `x86_64-unknown-linux-musl` (64-bit Intel / AMD x86 servers, PC, VM, and VPS)
  - `i686-unknown-linux-musl` (32-bit x86 legacy hardware and thin clients)
- [x] Integrated pre-release execution verification with QEMU user emulation.

---

## Future Roadmap

The following tasks may be addressed based on community feedback:

- [ ] **OpenWrt Package Feed:** Create an official OpenWrt package Makefile for direct integration into firmware image builders.
- [ ] **RISC-V 64 Support:** Add `riscv64gc-unknown-linux-musl` target for low-power open hardware boards (Milk-V, StarFive).
- [ ] **Pre-configured Init Templates:** Add turnkey startup templates for OpenWrt `procd`, Alpine Linux `openrc`, and ASUSWRT user scripts.
- [ ] **Kernel WireGuard Bridge Helper:** Lightweight script to automate forwarding between Yggdrasil IPv6 and isolated WireGuard client subnets.

---

*Feedback, deployment logs, and bug reports are welcome via GitHub Issues.*
