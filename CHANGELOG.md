# 📜 Changelog

All notable changes to the **Fearless** project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Upcoming]
### 🚀 Planned Features & Architecture
- Add support for Secure Boot.
- Add multi-architecture ISO build targets in Makefile (`x86_64`, `aarch64`, `riscv64`).
- Transition bootloader infrastructure towards EFISTUB / UKI (Unified Kernel Image).

---

## [0.0.1-dev] - Work in Progress

### 🚀 Added
- Initial release of the Fearless OS build environment.
- Integrated **Limine** bootloader configuration with boot splash screen (`Fearless.bmp`).
- Added kernel configurations for Server and Desktop targets (`Fearless_Server`, `Fearless_Desktop`).
- Added initial Secure Boot certificate infrastructure (`Fearless.crt`).
- Added Docker development environment (`Dockerfile`, `docker-compose.yml`, `.dockerignore`).
- Added GitHub issue templates (bug, feature, security, chore, question).

### 🛡️ Security
- Added Limine hash verification to validate kernel/payload integrity on boot.

### ⚙️ Fixed
- Applied build configuration fixes to the project pipeline.

### 🛠️ Refactored
- Cleaned up bootloader setup and initialization routines.

### 📦 Dependencies & Submodules
- Managed external submodules: `Linux`, `Limine`, and `SecureEngine`.
- Automated **Shim** bootloader downloading via `Makefile`.
- Updated `SecureEngine` submodule to commit `2c5eb2c`.

### 📄 Licensing & Documentation
- Added core multi-licensing setup (`AGPL-3.0`, `GPL-v2`, `BSD-2-Clause`, `COMMERCIAL_LICENSE`, `THIRDPARTY`).
- Created project governance files (`AUTHORS.md`, `CODE_OF_CONDUCT.md`, `CHANGELOG.md`).
- Updated `README.md` with setup guidelines and start instructions.

### ⚠️ Known Issues
- Secure Boot is currently unsupported.

---

[Upcoming]: https://github.com/Secure-Your-Soul/Fearless/tree/dev
[0.0.1-dev]: https://github.com/Secure-Your-Soul/Fearless/commits/dev