# Fearless Makefile
# --------- CONFIG ---------
	OS_NAME =Fearless
	OS_FULLNAME =$(OS_NAME)_$(BUILD_MODE).iso
	CONFIG = config
	CONFIG_CERTS = $(CONFIG)/certs
	CONFIG_KERNELS = $(CONFIG)/kernel
	INITRAMFS = $(CACHE)/initramfs
	BIN = $(INITRAMFS)/bin
	ISO = $(CACHE)/iso
	BOOT = $(ISO)/boot
	EFI_BOOT = $(ISO)/EFI/BOOT
	ISO_LIMINE = $(BOOT)/limine
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
# ---------	Init Binary File ---------
	SECURE_ENGINE_BIN = $(SECURE_ENGINE)/target/x86_64-unknown-linux-gnu/release/secure-engine
# --------- OUTPUT ---------
	OUTPUT = output
# Limine Template
define LIMINE_CONFIG
TIMEOUT:5
VERBOSE:$(VERBOSE)
WALLPAPER:boot():/boot/limine/$(OS_NAME).bmp#@WALLPAPER_HASH@
INTERFACE_BRANDING:$(OS_NAME) $(BUILD_MODE)
REMEMBER_LAST_ENTRY:yes

/$(OS_NAME) $(BUILD_TYPE)($(BUILD_MODE))
    PROTOCOL:linux
    KERNEL_PATH:boot():/boot/bzImage#@KERNEL_HASH@
    MODULE_PATH:boot():/boot/initramfs.cpio.zst#@CPIO_HASH@
    HASH_MANDATORY:yes
    CMDLINE:root=/dev/sr0 rootwait rw rdinit=/init console=tty0 quiet loglevel=3 panic=5 lockdown=integrity lsm=landlock,lockdown,yama,integrated,selinux,bpf security=selinux selinux=1
endef
export LIMINE_CONFIG
.PHONY: all build_all build_dev build_release build config clean fclean install update dev test limine linux secure_engine shim iso
all: install build_all
install:
	@SUDO=""; \
	if [ "$$(id -u)" != "0" ] && command -v sudo >/dev/null 2>&1; then \
		SUDO="sudo"; \
	fi; \
	if command -v pacman >/dev/null 2>&1; then \
		echo "Installing dependencies for Arch Linux (Docker)..."; \
		\
		$$SUDO pacman -Syu --needed --noconfirm \
			git rustup ca-certificates patch autoconf automake cmake gcc glibc \
			clang lld llvm mtools nasm flex bison linux-api-headers perl bc libelf openssl \
			riscv64-linux-gnu-gcc musl aarch64-linux-gnu-gcc \
			zstd coreutils cpio xorriso curl rpm-tools cpio \
			opensc pcsc-lite ccid openssl; \
	elif command -v apt-get >/dev/null 2>&1; then \
		\
		echo "Installing dependencies for Debian/Ubuntu (Docker)..."; \
		$$SUDO apt-get update && \
		$$SUDO apt-get install -y --no-install-recommends \
			git rustup ca-certificates patch autoconf automake cmake gcc libc6-dev \
			clang lld llvm mtools nasm flex bison linux-libc-dev perl bc libelf-dev libssl-dev \
			gcc-riscv64-linux-gnu musl-tools g++-riscv64-linux-gnu libc6-dev-riscv64-cross \
			gcc-aarch64-linux-gnu g++-aarch64-linux-gnu libc6-dev-arm64-cross \
			zstd cpio xorriso curl rpm2cpio cpio \
			osslsigncode opensc pcscd libccid openssl \
		&& rm -rf /var/lib/apt/lists/*; \
	elif command -v dnf >/dev/null 2>&1; then \
		echo "Installing dependencies for Fedora/RHEL (Docker)..."; \
		\
		$$SUDO dnf install -y \
			git rustup ca-certificates patch autoconf automake cmake gcc glibc-devel \
			clang lld llvm mtools nasm flex bison kernel-headers perl bc libelf-devel openssl-devel \
			gcc-riscv64-linux-gnu musl-gcc gcc-aarch64-linux-gnu \
			zstd coreutils cpio xorriso curl rpm-build cpio \
			osslsigncode opensc pcsc-lite pcsc-lite-ccid openssl; \
	else \
		echo "Error: Unsupported package manager." && exit 1; \
	fi; \
	\
	if ! command -v osslsigncode >/dev/null 2>&1; then \
		echo "⚙️ Building osslsigncode from source for container environment..."; \
		git clone --depth 1 https://github.com/mtrojnar/osslsigncode.git /tmp/osslsigncode; \
		cd /tmp/osslsigncode && mkdir -p build && cd build; \
		cmake .. && make -j$$(nproc) && $$SUDO make install; \
		cd / && rm -rf /tmp/osslsigncode; \
	fi; \
	\
	rustup toolchain install nightly; \
	rustup target add \
		x86_64-unknown-linux-gnu x86_64-unknown-linux-musl x86_64-unknown-none \
		aarch64-unknown-linux-gnu aarch64-unknown-linux-musl aarch64-unknown-none \
		riscv64gc-unknown-linux-gnu riscv64gc-unknown-linux-musl riscv64gc-unknown-none-elf; \
	$(MAKE) update
update:
	git config --global --add safe.directory /build
	git submodule update --init --recursive --depth 1 --remote
build: initramfs_dirs shim secure_engine cpio linux limine sign limine_config iso
build_all: clean build_dev build_release
build_dev:
	$(MAKE) build BUILD_MODE="DEV"
build_release:
	$(MAKE) build BUILD_MODE="RELEASE"
docker: clean
	docker compose up --build
	mkdir -p ./output
	docker cp $$(docker compose ps -qa builder):/build/output/. ./output/
	docker compose down
podman: clean
	podman-compose up --build
	mkdir -p ./output
	podman cp $$(docker compose ps -qa builder):/build/output/. ./output/
	podman-compose down
initramfs_dirs:
# 	Creating Structure in Cache Folder
#	mkdir -p $(CACHE)/{initramfs/{bin,dev,proc,sys},iso/{boot/limine,EFI/BOOT}}
	mkdir -p .cache/initramfs/bin \
	         .cache/initramfs/dev \
	         .cache/initramfs/proc \
	         .cache/initramfs/sys \
	         .cache/iso/boot/limine \
	         .cache/iso/EFI/BOOT
#	Copy initramfs config files to cache
#	cp -r $(CONFIG)/initramfs/* $(INITRAMFS)/ 2>/dev/null || true
FEDORA_VER := $(shell curl -s https://dl.fedoraproject.org/pub/fedora/linux/releases/ | grep -oE '[0-9]+/' | tr -d '/' | sort -n | tail -n 1)

URL_X86_64  = https://dl.fedoraproject.org/pub/fedora/linux/releases/$(FEDORA_VER)/Everything/x86_64/os/Packages/s/
URL_AARCH64 = https://dl.fedoraproject.org/pub/fedora/linux/releases/$(FEDORA_VER)/Everything/aarch64/os/Packages/s/

shim:
	@echo "🔍 Wykryta wersja Fedory: $(FEDORA_VER)"
	@mkdir -p $(EFI_BOOT) .cache
	
	$(eval RPM_X64  := $(shell curl -s $(URL_X86_64)  | grep -oE 'shim-x64-[0-9.]+-([0-9.]+)\.[^"]+\.rpm' | grep -v 'unsigned' | sort -V | tail -n 1))
	$(eval RPM_IA32 := $(shell curl -s $(URL_X86_64)  | grep -oE 'shim-ia32-[0-9.]+-([0-9.]+)\.[^"]+\.rpm' | grep -v 'unsigned' | sort -V | tail -n 1))
	$(eval RPM_AA64 := $(shell curl -s $(URL_AARCH64) | grep -oE 'shim-aa64-[0-9.]+-([0-9.]+)\.[^"]+\.rpm' | grep -v 'unsigned' | sort -V | tail -n 1))

	@if [ -z "$(RPM_X64)" ]; then echo "❌ Error: No RPM"; exit 1; fi
	
	@curl -sL -f -o ".cache/$(RPM_X64)" "$(URL_X86_64)$(RPM_X64)"
	@if [ -n "$(RPM_IA32)" ]; then curl -sL -f -o ".cache/$(RPM_IA32)" "$(URL_X86_64)$(RPM_IA32)"; fi
	@if [ -n "$(RPM_AA64)" ]; then curl -sL -f -o ".cache/$(RPM_AA64)" "$(URL_AARCH64)$(RPM_AA64)"; fi
	
	# --- x86_64 ---
	# --- IA32 ---
	# --- AArch64 ---

	@cp $(CERT_FILE) $(EFI_BOOT)/$(OS_NAME).cer 2>/dev/null || true
secure_engine:
#	SecureEngine Repository Build
	env -u MAKEFLAGS -u CFLAGS -u LDFLAGS $(MAKE) -j$(shell nproc) -C $(SECURE_ENGINE) all
# 	Giving Init File Execute Permission
	chmod +x $(SECURE_ENGINE_BIN)
#	Copy SecureEngine Binary to BIN
	cp $(SECURE_ENGINE_BIN) $(INITRAMFS)/init
cpio:
#	Create Cpio File and move to boot folder
	(cd $(INITRAMFS) && find . -print0 | cpio --null -ov --format=newc | zstd --ultra -22 --long=31 --threads=0 > ../iso/boot/initramfs.cpio.zst)
linux:
# 	Copy kernel configuration
	cp $(CONFIG_KERNELS)/$(OS_NAME)_Desktop.config $(LINUX)/.config
# 	Linux Repository Build
	$(MAKE) -C $(LINUX) LLVM=1 LLVM_IAS=1 LD=ld.lld CC="ccache clang" olddefconfig
	$(MAKE) -C $(LINUX) LLVM=1 LLVM_IAS=1 LD=ld.lld CC="ccache clang" bzImage -j$(shell nproc)
# 	Copy Kernel image
	cp $(LINUX_IMAGE) $(BOOT)/bzImage
limine:
# ------------------------------------------------------------------------------
# 	Limine Repository Build
# ------------------------------------------------------------------------------
	(cd $(LIMINE) && ./bootstrap && ./configure --enable-all) && $(MAKE) -C $(LIMINE) -j$(shell nproc)
# ------------------------------------------------------------------------------
# 🛡️ Legacy CD/HDD PXE
# ------------------------------------------------------------------------------
	@cp $(addprefix $(LIMINE_BIN)/, limine-bios.sys limine-bios-cd.bin limine-bios-hdd.bin limine-bios-pxe.bin) $(ISO_LIMINE)/
# ------------------------------------------------------------------------------
# 🛡️ UEFI
# ------------------------------------------------------------------------------
	@cp $(LIMINE_BIN)/limine-uefi-cd.bin $(ISO_LIMINE)/
	@cp $(LIMINE_BIN)/BOOTX64.EFI $(EFI_BOOT)/grubx64.efi
	@cp $(LIMINE_BIN)/BOOTAA64.EFI $(EFI_BOOT)/grubaa64.efi
	@cp $(LIMINE_BIN)/BOOTIA32.EFI $(EFI_BOOT)/grubia32.efi
	@cp $(addprefix $(LIMINE_BIN)/, BOOTRISCV64.EFI BOOTLOONGARCH64.EFI) $(EFI_BOOT)/

	@cp $(CONFIG)/iso/limine/$(OS_NAME).bmp $(ISO_LIMINE)/$(OS_NAME).bmp
sign:
	@echo "🔏 Signing binaries with YubiKey (osslsigncode)..."
	@OPENSC_SO=$$(ls /usr/lib*/opensc-pkcs11.so /usr/lib64/pkcs11/opensc-pkcs11.so 2>/dev/null | head -n 1); \
	[ -z "$$OPENSC_SO" ] && { echo "❌ Error: opensc-pkcs11.so not found!"; exit 1; }; \
	[ ! -f "$(CERT_FILE)" ] && { echo "❌ Error: Certificate file missing: $(CERT_FILE)"; exit 1; }; \
	\
	read -s -p "🔑 Enter YubiKey PIN (once): " YUBI_PIN; echo; \
	[ -z "$$YUBI_PIN" ] && { echo "❌ Error: PIN cannot be empty!"; exit 1; }; \
	\
	mkdir -p .cache; \
	CNF=".cache/openssl_pkcs11.cnf"; \
	printf "openssl_conf = openssl_init\n\n[openssl_init]\nengines = engine_section\n\n[engine_section]\npkcs11 = pkcs11_section\n\n[pkcs11_section]\nengine_id = pkcs11\nMODULE_PATH = %s\nPIN = %s\ninit = 0\n" "$$OPENSC_SO" "$$YUBI_PIN" > "$$CNF"; \
	\
	SUCCESS=1; \
	for file in $(BOOT)/bzImage $$(ls $(EFI_BOOT)/*.efi $(EFI_BOOT)/*.EFI 2>/dev/null); do \
		if [ -f "$$file" ] && [ ! -L "$$file" ]; then \
			if [ "$$(stat -c%s "$$file" 2>/dev/null)" -lt 10240 ]; then \
				echo "  -> Skipping $$file (helper stub)"; \
				continue; \
			fi; \
			echo "  -> Signing $$file"; \
			if ! OPENSSL_CONF="$$(pwd)/$$CNF" PKCS11_MODULE_PATH="$$OPENSC_SO" osslsigncode sign \
				-engine pkcs11 -key "pkcs11:type=private" -certs "$(CERT_FILE)" \
				-in "$$file" -out "$$file.signed"; then \
				echo "❌ Error: Failed to sign $$file!"; \
				SUCCESS=0; \
				break; \
			fi; \
			mv "$$file.signed" "$$file"; \
		fi; \
	done; \
	rm -f "$$CNF"; \
	[ "$$SUCCESS" -eq 0 ] && exit 1; \
	echo "🎉 All binaries successfully signed!"
limine_config:
# ------------------------------------------------------------------------------
# 	Create Limine config
# ------------------------------------------------------------------------------
	@KERNEL_HASH=$$(b2sum $(BOOT)/bzImage 2>/dev/null | cut -d' ' -f1); \
	CPIO_HASH=$$(b2sum $(BOOT)/initramfs.cpio.zst 2>/dev/null | cut -d' ' -f1); \
	WALLPAPER_HASH=$$(if [ -f "$(ISO_LIMINE)/$(OS_NAME).bmp" ]; then b2sum "$(ISO_LIMINE)/$(OS_NAME).bmp" | cut -d' ' -f1; else echo ""; fi); \
	if [ -z "$$KERNEL_HASH" ] || [ -z "$$CPIO_HASH" ]; then \
		echo "❌ Błąd: Brak plików do wyliczenia sum b2sum!"; exit 1; \
	fi; \
	echo "$$LIMINE_CONFIG" | \
		sed "s|@KERNEL_HASH@|$$KERNEL_HASH|g" | \
		sed "s|@CPIO_HASH@|$$CPIO_HASH|g" | \
		sed "s|@WALLPAPER_HASH@|$$WALLPAPER_HASH|g" > $(ISO_LIMINE)/limine.conf
iso:
	mkdir -p $(OUTPUT)
	xorriso -as mkisofs \
		-b boot/limine/limine-bios-cd.bin \
		-no-emul-boot -boot-load-size 4 -boot-info-table \
		--efi-boot boot/limine/limine-uefi-cd.bin \
		-efi-boot-part --efi-boot-image --protective-msdos-label \
		-J -joliet -R -V "$(OS_NAME)" -o $(OUTPUT)/$(OS_FULLNAME) $(ISO)
# --- Generating Hashes for Open Source Release ---
	@echo "🔍 Generating SHA-512 checksum..."
	@cd $(OUTPUT) && sha512sum $(OS_FULLNAME) > $(OS_FULLNAME).sha512

# --- Optional: Sign ISO with GPG key (if available) ---
	@if command -v gpg >/dev/null 2>&1 && gpg --list-secret-keys >/dev/null 2>&1; then \
		echo "🔏 Signing ISO with GPG..."; \
		cd $(OUTPUT) && gpg --batch --yes --detach-sign --armor $(OS_FULLNAME); \
	fi
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
dev:
	$(MAKE) -C $(SECURE_ENGINE) dev
test:
	qemu-system-x86_64 -enable-kvm -cdrom $(OUTPUT)/$(OS_NAME)_DEV.iso -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF.4m.fd -m 2G\
		-serial stdio \
		-monitor vc
#qemu-system-x86_64 -enable-kvm -cdrom $(OUTPUT)/$(OS_NAME)_DEV.iso -m 2G