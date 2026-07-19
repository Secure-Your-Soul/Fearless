# Fearless Makefile
# --------- CONFIG ---------
	OS_NAME =Fearless
	CONFIG = config
	CONFIG_CERTS = $(CONFIG)/certs
	CONFIG_KERNELS = $(CONFIG)/kernel
	INITRAMFS = $(CACHE)/initramfs
	BIN = $(INITRAMFS)/bin
	ISO = $(CACHE)/iso
	BOOT = $(ISO)/boot
	EFI_BOOT = $(ISO)/EFI/BOOT
	ISO_LIMINE = $(BOOT)/limine
# Kernel C Flags and Linker C Flags
	KCFLAGS_DEV = -O1 -g -Wall -Wextra
	LDFLAGS_DEV = -g -rdynamic
	KCFLAGS_RELEASE = -march=x86-64-v3 -O3 -pipe -fno-plt -fstack-protector-strong -D_FORTIFY_SOURCE=2 -fstack-clash-protection
	LDFLAGS_RELEASE = -Wl,-z,now -Wl,-z,relro -Wl,-z,noexecstack
#	Temporary Files/Cache
	CACHE = .cache
# --------- External Repositories Paths ---------
	EXTERNAL = external
	LIMINE = $(EXTERNAL)/limine
	LINUX = $(EXTERNAL)/linux
	SECURE_ENGINE = $(EXTERNAL)/SecureEngine
#	Limine Binary Files
	LIMINE_BIN = $(LIMINE)/bin
# ---------	Kernel Binary File ---------
	LINUX_IMAGE = $(LINUX)/arch/x86/boot/bzImage
# ---------	Shim Secure Boot ---------
	SHIM := $(EXTERNAL)/shim
	SHIM_BIN := $(SHIM)/shimx64.efi
	CERT_FILE := $(CONFIG_CERTS)/$(OS_NAME).crt
	KEY_FILE  := $(CONFIG_CERTS)/$(OS_NAME).key
# ---------	Init Binary File ---------
	SECURE_ENGINE_BIN = $(SECURE_ENGINE)/target/x86_64-unknown-linux-gnu/release/secure-engine
# --------- OUTPUT ---------
	OUTPUT = output
# --------- Tests ---------
	VM_ID = 100 # ID Proxmox Machine
	PVE_IP = 192.168.0.2
	PVE_NODE = proxmox 
	STORAGE = Proxmox
# Limine Template
define LIMINE_CONFIG
TIMEOUT:5
VERBOSE:$(VERBOSE)
WALLPAPER:boot():/boot/limine/$(OS_NAME).bmp
INTERFACE_BRANDING:$(OS_NAME) $(BUILD_MODE)

/$(OS_NAME) $(BUILD_MODE)($(BUILD_TYPE))
    PROTOCOL:linux
    KERNEL_PATH:boot():/boot/bzImage
    CMDLINE:$(CMDLINE)
    MODULE_PATH:boot():/boot/initramfs.cpio.zst
endef
export LIMINE_CONFIG
.PHONY: all build_all build_dev build_release build config clean  fclean install update dev test limine linux secure_engine shim iso
all: build
build_all: build_dev build_release
build_dev:
	$(MAKE) build CFLAGS="$(KCFLAGS_DEV)" LDFLAGS="$(LDFLAGS_DEV)" BUILD_MODE="DEV" CMDLINE="console=tty0 console=ttyS0,115200 earlyprintk=ttyS0,115200"
build_release:
	$(MAKE) build CFLAGS="$(KCFLAGS_RELEASE)" LDFLAGS="$(LDFLAGS_RELEASE)" BUILD_MODE="RELEASE" CMDLINE="console=tty0 console=ttyS0,115200 earlyprintk=ttyS0,115200"
build:
# 	Creating Structure in Cache Folder
	mkdir -p $(CACHE)/{initramfs/{bin,dev,proc,sys},iso/{boot/limine,EFI/BOOT}}
#	Copy initramfs config files to cache
#	cp -r $(CONFIG)/initramfs/* $(INITRAMFS)/ 2>/dev/null || true
# ------------------------------------------------------------------------------
	$(MAKE) limine
# ------------------------------------------------------------------------------
	$(MAKE) linux
# ------------------------------------------------------------------------------
	$(MAKE) secure_engine
#	Create Cpio File and move to boot folder
	(cd $(INITRAMFS) && find . -print0 | cpio --null -ov --format=newc | zstd --ultra -22 --long=31 --threads=0 > ../iso/boot/initramfs.cpio.zst)
# ------------------------------------------------------------------------------
	$(MAKE) shim
# ------------------------------------------------------------------------------
	$(MAKE) iso
# ------------------------------------------------------------------------------
	$(MAKE) clean
# ------------------------------------------------------------------------------
config:
	$(MAKE) -C $(LINUX) menuconfig
# TEMP CLEAN
clean:
	rm -rf $(CACHE)
	rm -rf target
	rm -rf $(OUTPUT)
# FULL CLEAN
fclean:
	$(MAKE) clean
	rm -rf $(EXTERNAL)
install:
	@if command -v pacman >/dev/null 2>&1; then \
		echo "Installing dependencies for Arch Linux..."; \
		sudo pacman -Syu --needed git; \
	elif command -v apt-get >/dev/null 2>&1; then \
		echo "Installing dependencies for Debian/Ubuntu..."; \
		sudo apt-get update && sudo apt-get install -y --no-install-recommends git; && rm -rf /var/lib/apt/lists/* \
	elif command -v dnf >/dev/null 2>&1; then \
		echo "Installing dependencies for Fedora/RHEL..."; \
		sudo dnf install -y git; \
	else \
		echo "Error: Unsupported package manager." && exit 1; \
	fi
	rustup toolchain install nightly
	rustup target add \
  x86_64-unknown-linux-gnu x86_64-unknown-linux-musl x86_64-unknown-none \
  aarch64-unknown-linux-gnu aarch64-unknown-linux-musl aarch64-unknown-none \
  riscv64gc-unknown-linux-gnu riscv64gc-unknown-linux-musl #riscv64gc-unknown-none
	$(MAKE) update
update:
	git submodule update --init --recursive --depth 1 --remote
dev:
	$(MAKE) -C $(SECURE_ENGINE) dev
test:
	qemu-system-x86_64 -enable-kvm -cdrom $(OUTPUT)/$(OS_NAME).iso -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF.4m.fd -m 2G\
		-serial stdio \
		-monitor vc
#qemu-system-x86_64 -enable-kvm -cdrom $(OUTPUT)/$(OS_NAME).iso -m 2G
limine:
# 	Create Limine config
	echo "$$LIMINE_CONFIG" > $(ISO_LIMINE)/limine.conf
# 	Limine Repository Build
	(cd $(LIMINE) && ./bootstrap && ./configure --enable-all) && $(MAKE) -C $(LIMINE) -j$(shell nproc)
# ------------------------------------------------------------------------------
# 🛡️ Legacy CD/HDD PXE
# ------------------------------------------------------------------------------
	cp $(addprefix $(LIMINE_BIN)/, limine-bios.sys limine-bios-cd.bin limine-bios-hdd.bin limine-bios-pxe.bin) $(ISO_LIMINE)/
# ------------------------------------------------------------------------------
# 🛡️ UEFI
# ------------------------------------------------------------------------------
	cp $(LIMINE_BIN)/limine-uefi-cd.bin $(ISO_LIMINE)/
	cp $(LIMINE_BIN)/BOOTX64.EFI $(EFI_BOOT)/grubx64.efi
	cp $(LIMINE_BIN)/BOOTAA64.EFI $(EFI_BOOT)/grubaa64.efi
	cp $(LIMINE_BIN)/BOOTIA32.EFI $(EFI_BOOT)/grubia32.efi
	cp $(addprefix $(LIMINE_BIN)/, BOOTRISCV64.EFI BOOTLOONGARCH64.EFI) $(EFI_BOOT)/
linux:
# 	Copy kernel configuration
	cp $(CONFIG_KERNELS)/$(OS_NAME)_Desktop.config $(LINUX)/.config
# 	Linux Repository Build
	$(MAKE) -C $(LINUX) olddefconfig
	$(MAKE) -C $(LINUX) -j$(shell nproc)
# 	Copy Kernel image
	cp $(LINUX_IMAGE) $(BOOT)/bzImage
secure_engine:
#	SecureEngine Repository Build
	env -u MAKEFLAGS -u CFLAGS -u LDFLAGS $(MAKE) -j$(shell nproc) -C $(SECURE_ENGINE) all
# 	Giving Init File Execute Permission
	chmod +x $(SECURE_ENGINE_BIN)
#	Copy SecureEngine Binary to BIN
	cp $(SECURE_ENGINE_BIN) $(INITRAMFS)/init
shim:
URL_X86_64  = https://dl.fedoraproject.org/pub/fedora/linux/development/rawhide/Everything/x86_64/os/Packages/s/
URL_AARCH64 = https://dl.fedoraproject.org/pub/fedora/linux/development/rawhide/Everything/aarch64/os/Packages/s/
	@mkdir -p $(OUT_DIR)

	$(eval RPM_X64  := $(shell curl -s $(URL_X86_64)  | grep -oE 'shim-x64-[0-9.]+-[0-9.]+\.fc[0-9.]+\.x86_64\.rpm|shim-x64-[0-9.]+-[0-9.]+\.x86_64\.rpm' | sort -V | tail -n 1))
	$(eval RPM_AA64 := $(shell curl -s $(URL_AARCH64) | grep -oE 'shim-aa64-[0-9.]+-[0-9.]+\.fc[0-9.]+\.aarch64\.rpm|shim-aa64-[0-9.]+-[0-9.]+\.aarch64\.rpm' | sort -V | tail -n 1))
	$(eval RPM_IA32 := $(shell curl -s $(URL_X86_64)  | grep -oE 'shim-ia32-[0-9.]+-[0-9.]+\.fc[0-9.]+\.x86_64\.rpm|shim-ia32-[0-9.]+-[0-9.]+\.x86_64\.rpm' | sort -V | tail -n 1))
	
	@if [ -n "$(RPM_X64)" ];  then curl -s -O "$(URL_X86_64)$(RPM_X64)"; fi
	@if [ -n "$(RPM_AA64)" ]; then curl -s -O "$(URL_AARCH64)$(RPM_AA64)"; fi
	@if [ -n "$(RPM_IA32)" ]; then curl -s -O "$(URL_X86_64)$(RPM_IA32)"; fi

	@if [ -f "$(RPM_X64)" ]; then \
		rpm2cpio "$(RPM_X64)" | cpio --to-stdout -i "*/BOOT/BOOTX64.EFI" 2>/dev/null > $(OUT_DIR)/BOOTX64.EFI || true; \
		rpm2cpio "$(RPM_X64)" | cpio --to-stdout -i "*/BOOT/fbx64.efi" 2>/dev/null > $(OUT_DIR)/fbx64.efi || true; \
		rpm2cpio "$(RPM_X64)" | cpio --to-stdout -i "*/fedora/mmx64.efi" 2>/dev/null > $(OUT_DIR)/mmx64.efi || true; \
		rpm2cpio "$(RPM_X64)" | cpio --to-stdout -i "*/fedora/shimx64.efi" 2>/dev/null > $(OUT_DIR)/shimx64.efi || true; \
	fi
	@if [ -f "$(RPM_IA32)" ]; then \
		rpm2cpio "$(RPM_IA32)" | cpio --to-stdout -i "*/BOOT/BOOTIA32.EFI" 2>/dev/null > $(OUT_DIR)/BOOTIA32.EFI || true; \
		rpm2cpio "$(RPM_IA32)" | cpio --to-stdout -i "*/BOOT/fbia32.efi" 2>/dev/null > $(OUT_DIR)/fbia32.efi || true; \
		rpm2cpio "$(RPM_IA32)" | cpio --to-stdout -i "*/fedora/mmia32.efi" 2>/dev/null > $(OUT_DIR)/mmia32.efi || true; \
		rpm2cpio "$(RPM_IA32)" | cpio --to-stdout -i "*/fedora/shimia32.efi" 2>/dev/null > $(OUT_DIR)/shimia32.efi || true; \
	fi
	@if [ -f "$(RPM_AA64)" ]; then \
		rpm2cpio "$(RPM_AA64)" | cpio --to-stdout -i "*/BOOT/BOOTAA64.EFI" 2>/dev/null > $(OUT_DIR)/BOOTAA64.EFI || true; \
		rpm2cpio "$(RPM_AA64)" | cpio --to-stdout -i "*/BOOT/fbaa64.efi" 2>/dev/null > $(OUT_DIR)/fbaa64.efi || true; \
		rpm2cpio "$(RPM_AA64)" | cpio --to-stdout -i "*/fedora/mmaa64.efi" 2>/dev/null > $(OUT_DIR)/mmaa64.efi || true; \
		rpm2cpio "$(RPM_AA64)" | cpio --to-stdout -i "*/fedora/shimaa64.efi" 2>/dev/null > $(OUT_DIR)/shimaa64.efi || true; \
	fi

	@rm -rf boot *.rpm
iso:
	mkdir -p $(OUTPUT)
	xorriso -as mkisofs \
		-b boot/limine/limine-bios-cd.bin \
		-no-emul-boot -boot-load-size 4 -boot-info-table \
		--efi-boot boot/limine/limine-uefi-cd.bin \
		-efi-boot-part --efi-boot-image --protective-msdos-label \
		-J -joliet -R -V "$(OS_NAME)" -o $(OUTPUT)/$(OS_NAME).iso $(ISO)