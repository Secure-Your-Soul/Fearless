# 	Fearless Makefile
#
#  Copyright (C) 2026 Denis Rudolf Kontek (Secure Your Soul)
#  Licensed under the GNU Affero General Public License v3.0.
#
# --------- CONFIG ---------
	OS_NAME =Fearless
	OS_FULLNAME = $(OS_NAME)_$(TYPE)_$(ARCH)_$(MODE)
	KERNELS = kernels
	PIV_CERT = $(OS_NAME).cer
	TARGET = $(ARCH)/$(TYPE)/$(MODE)
	INITRAMFS = $(CACHE)/$(TARGET)/initramfs
	IMG = $(CACHE)/$(TARGET)/img
	EFI_BOOT = $(IMG)/EFI/BOOT
    # Temporary Files
	CACHE = .cache
    #	 --------- Dynamic Mapping to Rust/Cargo ---------

    #	 1. Mapping ARCH on Rust Target (adding 'gc' to riscv64)
	ifeq ($(ARCH),riscv64)
		RUST_ARCH := riscv64gc
	else
		RUST_ARCH := $(ARCH)
	endif
    #	 2. Mapping MODE (Dev -> debug, Release -> release)
	ifeq ($(MODE),Dev)
		CARGO_MODE := debug
	else
		CARGO_MODE := release
	endif
    # --------- External Repositories Paths ---------
	LINUX = linux
	FEARINIT = FearInit
	FEARINIT_BIN = $(FEARINIT)/target/$(RUST_ARCH)-unknown-linux-musl/$(CARGO_MODE)/fearinit
    # --------- Dynamic Kernel & EFI Target Mapping ---------
    ifeq ($(ARCH),x86_64)
        KERNEL_ARCH    := x86
        CROSS_PREFIX   :=
        KERNEL_TARGET  := bzImage
        KERNEL_SRC_BIN := $(LINUX)/arch/x86/boot/bzImage
        EFI_OUT_NAME   := BOOTX64.EFI
    else ifeq ($(ARCH),aarch64)
        KERNEL_ARCH    := arm64
        CROSS_PREFIX   := aarch64-linux-gnu-
        KERNEL_TARGET  := Image.gz
        KERNEL_SRC_BIN := $(LINUX)/arch/arm64/boot/Image.gz
        EFI_OUT_NAME   := BOOTAA64.EFI
    else ifeq ($(ARCH),riscv64)
        KERNEL_ARCH    := riscv
        CROSS_PREFIX   := riscv64-linux-gnu-
        KERNEL_TARGET  := Image
        KERNEL_SRC_BIN := $(LINUX)/arch/riscv/boot/Image
        EFI_OUT_NAME   := BOOTRISCV64.EFI
    endif
    # --------- Kernel Binary File ---------
    KERNEL_IMAGE := $(LINUX)/arch/$(ARCH)/boot/bzImage
    KERNEL_FLAGS := LLVM=1 LLVM_IAS=1 LD=ld.lld CC="ccache clang" ARCH=$(KERNEL_ARCH) CROSS_COMPILE=$(CROSS_PREFIX)
    # --------- OUTPUT ---------
	OUTPUT = output
    # INSTALL
	PACMAN_PKGS := base-devel git curl libarchive ccache
	APT_PKGS    := build-essential git curl libarchive-tools ccache
	DNF_PKGS    := @development-tools curl bsdtar ccache
	RUST_TARGETS := x86_64-unknown-linux-musl aarch64-unknown-linux-musl riscv64gc-unknown-linux-musl
    # BUILD
	ALL_ARCHS = x86_64 aarch64 riscv64
	ALL_TYPES = Desktop Server
	ALL_MODES = Release Dev
define KCONFIG_GEN
	echo "# --- Fearless Custom Overrides ---" >> $(LINUX)/.config
	# 1. Baza procesora i pamięci
	echo "CONFIG_64BIT=y" >> $(LINUX)/.config
	echo "CONFIG_SMP=y" >> $(LINUX)/.config
	echo "CONFIG_MMU=y" >> $(LINUX)/.config
	echo "CONFIG_FLATMEM_MANUAL=y" >> $(LINUX)/.config
	echo "CONFIG_FLATMEM=y" >> $(LINUX)/.config
	echo "CONFIG_PCI=y" >> $(LINUX)/.config
	
	# Architecture
	if [ "$(ARCH)" = "x86_64" ]; then \
		echo "CONFIG_X86=y" >> $(LINUX)/.config; \
		echo "CONFIG_X86_64=y" >> $(LINUX)/.config; \
		echo "CONFIG_X86_LOCAL_APIC=y" >> $(LINUX)/.config; \
		echo "CONFIG_X86_IO_APIC=y" >> $(LINUX)/.config; \
		echo "CONFIG_HPET_TIMER=y" >> $(LINUX)/.config; \
		echo "CONFIG_PCI_MSI=y" >> $(LINUX)/.config; \
	elif [ "$(ARCH)" = "aarch64" ]; then \
		echo "CONFIG_ARM64=y" >> $(LINUX)/.config; \
		echo "CONFIG_ARM_GIC=y" >> $(LINUX)/.config; \
		echo "CONFIG_ARM_GIC_V3=y" >> $(LINUX)/.config; \
		echo "CONFIG_ARM_ARCH_TIMER=y" >> $(LINUX)/.config; \
	elif [ "$(ARCH)" = "riscv64" ]; then \
		echo "CONFIG_RISCV=y" >> $(LINUX)/.config; \
		echo "CONFIG_ARCH_RV64I=y" >> $(LINUX)/.config; \
		echo "CONFIG_SIFIVE_PLIC=y" >> $(LINUX)/.config; \
		echo "CONFIG_RISCV_TIMER=y" >> $(LINUX)/.config; \
	fi
	
	# 2. System Base (Initramfs, ELF, TTY, Sysfs)
	echo "CONFIG_BLK_DEV_INITRD=y" >> $(LINUX)/.config
	echo "CONFIG_RD_ZSTD=y" >> $(LINUX)/.config
	echo "CONFIG_BINFMT_ELF=y" >> $(LINUX)/.config
	echo "CONFIG_BINFMT_SCRIPT=y" >> $(LINUX)/.config
	echo "CONFIG_PROC_FS=y" >> $(LINUX)/.config
	echo "CONFIG_SYSFS=y" >> $(LINUX)/.config
	echo "CONFIG_DEVTMPFS=y" >> $(LINUX)/.config
	echo "CONFIG_DEVTMPFS_MOUNT=y" >> $(LINUX)/.config
	echo "CONFIG_TTY=y" >> $(LINUX)/.config
	echo "CONFIG_EPOLL=y" >> $(LINUX)/.config
	echo "CONFIG_SIGNALFD=y" >> $(LINUX)/.config
	echo "CONFIG_TIMERFD=y" >> $(LINUX)/.config
	echo "CONFIG_EVENTFD=y" >> $(LINUX)/.config
	echo "CONFIG_EFI=y" >> $(LINUX)/.config
    echo "CONFIG_EFI_STUB=y" >> $(LINUX)/.config
	# Wbudowanie initramfs (FearInit) bezpośrednio w jądro
    echo "CONFIG_BLK_DEV_INITRD=y" >> $(LINUX)/.config
    echo "CONFIG_INITRAMFS_SOURCE=\"$$(realpath $(INITRAMFS))\"" >> $(LINUX)/.config
	# Typ (Desktop / Server)
	if [ "$(TYPE)" = "Desktop" ]; then \
		echo "CONFIG_VT=y" >> $(LINUX)/.config; \
		echo "CONFIG_VT_CONSOLE=y" >> $(LINUX)/.config; \
		echo "CONFIG_INPUT=y" >> $(LINUX)/.config; \
		echo "CONFIG_INPUT_KEYBOARD=y" >> $(LINUX)/.config; \
		echo "CONFIG_INPUT_MOUSE=y" >> $(LINUX)/.config; \
		echo "CONFIG_DRM=y" >> $(LINUX)/.config; \
		echo "CONFIG_VIRTIO_PCI=y" >> $(LINUX)/.config; \
		echo "CONFIG_VIRTIO_BLK=y" >> $(LINUX)/.config; \
	elif [ "$(TYPE)" = "Server" ]; then \
		echo "CONFIG_NET=y" >> $(LINUX)/.config; \
		echo "CONFIG_INET=y" >> $(LINUX)/.config; \
		echo "CONFIG_NET_ETHERNET=y" >> $(LINUX)/.config; \
		echo "CONFIG_CGROUPS=y" >> $(LINUX)/.config; \
		echo "CONFIG_VIRTIO_NET=y" >> $(LINUX)/.config; \
		echo "CONFIG_VIRTIO_BLK=y" >> $(LINUX)/.config; \
		echo "CONFIG_VIRTIO_PCI=y" >> $(LINUX)/.config; \
	fi
	
	# Tryb (Dev / Release)
	if [ "$(MODE)" = "Dev" ]; then \
		echo "CONFIG_DEBUG_KERNEL=y" >> $(LINUX)/.config; \
		echo "CONFIG_PRINTK=y" >> $(LINUX)/.config; \
		echo "CONFIG_PRINTK_TIME=y" >> $(LINUX)/.config; \
		echo "CONFIG_EARLY_PRINTK=y" >> $(LINUX)/.config; \
		echo "CONFIG_SERIAL_8250=y" >> $(LINUX)/.config; \
		echo "CONFIG_SERIAL_8250_CONSOLE=y" >> $(LINUX)/.config; \
	elif [ "$(MODE)" = "Release" ]; then \
		echo "# CONFIG_DEBUG_KERNEL is not set" >> $(LINUX)/.config; \
		echo "CONFIG_PRINTK=y" >> $(LINUX)/.config; \
		echo "CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE=y" >> $(LINUX)/.config; \
	fi
endef
.PHONY: all install update build_all build build_test img_structure fearinit kernel sign img docker podman clean test
all: build_all
install:
	@SUDO=""; \
	[ "$$(id -u)" != "0" ] && command -v sudo > /dev/null 2>&1 && SUDO="sudo"; \
	if command -v pacman > /dev/null 2>&1; then \
		$$SUDO pacman -S --needed --noconfirm -q $(PACMAN_PKGS) > /dev/null; \
	elif command -v apt-get > /dev/null 2>&1; then \
		$$SUDO apt-get update -q > /dev/null && \
		$$SUDO apt-get install -y -q --no-install-recommends $(APT_PKGS) > /dev/null; \
	else \
		echo "Error: Unsupported package manager." && exit 1; \
	fi; \
	rustup target add $(RUST_TARGETS)
	@$(MAKE) --no-print-directory update
update:
	@git submodule update --init --recursive --depth 1 --remote
build_all: install
#	@$(MAKE) --no-print-directory clean
	@for arch in $(ALL_ARCHS); do \
		echo ""; \
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; \
		echo "🛠️  Building targets for ARCH=$$arch"; \
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; \
		for type in $(ALL_TYPES); do \
			echo ""; \
			echo "  ┌─────────────────────────────────────────────────────────"; \
			echo "  │ 🖥️  TYPE: $$type"; \
			echo "  └─┬───────────────────────────────────────────────────────"; \
			for mode in $(ALL_MODES); do \
				if [ "$$mode" = "Release" ]; then \
					echo "    │"; \
					echo "    ├─► 🚀 MODE: $$mode"; \
					echo "    │   │"; \
					echo "    │   ├─► 🔹 LIB: musl"; \
					$(MAKE) --no-print-directory build ARCH=$$arch TYPE=$$type MODE=$$mode; \
				else \
					echo "    │"; \
					echo "    └─► 🚀 MODE: $$mode"; \
					echo "        │"; \
					echo "        ├─► 🔹 LIB: musl"; \
					$(MAKE) --no-print-directory build ARCH=$$arch TYPE=$$type MODE=$$mode; \
				fi; \
			done; \
		done; \
	done
build: img_structure kernel fearinit sign img
build_test: install
	@$(foreach mode,$(ALL_MODES),\
			$(MAKE) --no-print-directory build ARCH=x86_64 TYPE=Desktop MODE=$(mode); \
	)
img_structure:
	@mkdir -p $(CACHE)/$(TARGET)/initramfs/bin \
	         $(CACHE)/$(TARGET)/initramfs/dev \
	         $(CACHE)/$(TARGET)/initramfs/proc \
	         $(CACHE)/$(TARGET)/initramfs/sys \
	         $(CACHE)/$(TARGET)/img/EFI/BOOT
	@cp $(OS_NAME).cer $(EFI_BOOT)
fearinit:
    #	env -u MAKEFLAGS -u CFLAGS -u LDFLAGS $(MAKE) -j$(shell nproc) -C $(FEARINIT) all
	@$(MAKE) --no-print-directory -j$(shell nproc) -C $(FEARINIT) > /dev/null 2>&1
    # 	Giving Init File Execute Permission
	@chmod +x $(FEARINIT_BIN)
    #	Copy FearInit Binary to initramfs
	@cp $(FEARINIT_BIN) $(INITRAMFS)/init
	@printf "🦀 %-5s %-10s %-10s -> %s\n" \
		"[1/5]" "FearInit" "Built" "$(INITRAMFS)/init"
kernel:
	@$(MAKE) --no-print-directory -C $(LINUX) $(KERNEL_FLAGS) tinyconfig > /dev/null 2>&1
	@$(MAKE) --no-print-directory -C $(LINUX) $(KERNEL_FLAGS) defconfig #> /dev/null 2>&1
	@$(KCONFIG_GEN)
	@$(MAKE) --no-print-directory -C $(LINUX) $(KERNEL_FLAGS) olddefconfig #> /dev/null 2>&1
	@$(MAKE) --no-print-directory -C $(LINUX) $(KERNEL_FLAGS) $(KERNEL_TARGET) -j$(shell nproc) > /dev/null 2>&1
	@cp $(KERNEL_SRC_BIN) $(EFI_BOOT)/$(EFI_OUT_NAME)
	@printf "🐧 %-5s %-10s %-10s -> %s\n" \
		"[2/5]" "Kernel" "Built" "$(EFI_BOOT)/$(EFI_OUT_NAME)"
sign:
	@echo "🔏 Signing binaries with YubiKey (osslsigncode)..."
	@OPENSC_SO=$$(ls /usr/lib*/opensc-pkcs11.so /usr/lib64/pkcs11/opensc-pkcs11.so /usr/lib/opensc-pkcs11.so 2>/dev/null | head -n 1); \
	[ -z "$$OPENSC_SO" ] && { echo "❌ Error: opensc-pkcs11.so not found!"; exit 1; }; \
	[ ! -f "$(PIV_CERT)" ] && { echo "❌ Error: Certificate file missing: $(PIV_CERT)"; exit 1; }; \
	\
	SUCCESS=1; \
	for file in $$(ls $(EFI_BOOT)/*.efi $(EFI_BOOT)/*.EFI 2>/dev/null); do \
		if [ -f "$$file" ] && [ ! -L "$$file" ]; then \
			if [ "$$(stat -c%s "$$file" 2>/dev/null)" -lt 10240 ]; then \
				echo "  -> Skipping $$file (helper stub)"; \
				continue; \
			fi; \
			echo "  -> Signing $$file"; \
			if ! osslsigncode sign \
				-pkcs11module "$$OPENSC_SO" \
				-key "pkcs11:object=SIGN%20key;type=private" \
				-certs "$(PIV_CERT)" \
				-askpass \
				-in "$$file" -out "$$file.signed"; then \
				echo "❌ Error: Failed to sign $$file!"; \
				SUCCESS=0; \
				break; \
			fi; \
			mv "$$file.signed" "$$file"; \
		fi; \
	done; \
	[ "$$SUCCESS" -eq 0 ] && exit 1; \
	echo "🎉 All binaries successfully signed!"
iso:
img:
	@mkdir -p $(OUTPUT)
    # 1. Wygeneruj pusty plik o rozmiarze 64 MB (wystarczy na jądro z initramfs)
	@truncate -s $$(($$(du -sb $(IMG) | awk '{print $$1}') < 55000 ? 55000 : $$(du -sb $(IMG) | awk '{print $$1}'))) $(OUTPUT)/$(OS_FULLNAME).img
    # 2. Sformatuj ten plik jako system plików FAT (flaga -I jest kluczowa, bo to zwykły plik, a nie dysk!)
	@mkfs.vfat -I $(OUTPUT)/$(OS_FULLNAME).img
	@mcopy -s -i $(OUTPUT)/$(OS_FULLNAME).img $(IMG)/* ::/; \
	
    # --- Generating Hashes for Open Source Release ---
	@echo "🔍 Generating SHA-512 checksum..."
	@cd $(OUTPUT) && sha512sum $(OS_FULLNAME).img > $(OS_FULLNAME).sha512

    # --- Optional: Sign Image with GPG key (if available) ---
	@if command -v gpg >/dev/null 2>&1 && gpg --list-secret-keys >/dev/null 2>&1; then \
		echo "🔏 Signing Image with GPG..."; \
		cd $(OUTPUT) && gpg --batch --yes --detach-sign --armor $(OS_FULLNAME).img; \
	fi
docker: clean
	docker compose up --build
	@mkdir -p ./output
	docker cp $$(docker compose ps -qa builder):/build/output/. ./output/
	docker compose down
podman: clean
	podman-compose up --build
	@mkdir -p ./output
	podman cp $$(podman-compose ps -qa builder):/build/output/. ./output/
	podman-compose down
clean:
	@rm -rf $(CACHE)
	@rm -rf target
	@rm -rf $(OUTPUT)
test:
	qemu-system-x86_64 -enable-kvm \
          -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF.4m.fd \
          -drive format=raw,file=$(OUTPUT)/$(OS_NAME)_Desktop_x86_64_musl_Release.img -m 2G -serial stdio -nic none