# 	Fearless Makefile
#
#  Copyright (C) 2026 Denis Rudolf Kontek (Secure Your Soul)
#  Licensed under the GNU Affero General Public License v3.0.
#
# --------- CONFIG ---------
	OS_NAME =Fearless
	KERNELS = kernels
	PIV_CERT = $(OS_NAME).crt
	TARGET = $(ARCH)/$(TYPE)/$(MODE)/$(LIB)
	INITRAMFS = $(CACHE)/$(TARGET)/initramfs
	ISO = $(CACHE)/$(TARGET)/iso
	EFI_BOOT = $(ISO)/EFI/BOOT
    # Temporary Files
	CACHE = .cache
    # --------- External Repositories Paths ---------
	LINUX = linux
	FEARINIT = FearInit
    # ---------	Kernel Binary File ---------
	LINUX_IMAGE = $(LINUX)/arch/x86/boot/bzImage
    # ---------	Shim Secure Boot Loader ---------
	SHIM_x86_64 = $(CACHE)/shimx86_64.rpm
	SHIM_aarch64 = $(CACHE)/shimaarch64.rpm
    # --------- OUTPUT ---------
	OUTPUT = output
    # INSTALL
	PACMAN_PKGS := base-devel git curl libarchive
	APT_PKGS    := build-essential git curl libarchive-tools
	DNF_PKGS    := @development-tools curl bsdtar
    #						Glibc					Musl
	RUST_TARGETS := x86_64-unknown-linux-gnu x86_64-unknown-linux-musl \
					aarch64-unknown-linux-gnu aarch64-unknown-linux-musl \
					riscv64gc-unknown-linux-gnu riscv64gc-unknown-linux-musl
	
.PHONY: all install update build_all build build_test
all: build_all
install:
	@SUDO=""; \
	[ "$$(id -u)" != "0" ] && command -v sudo > /dev/null 2>&1 && SUDO="sudo"; \
	if command -v pacman > /dev/null 2>&1; then \
		$$SUDO pacman -S --needed --noconfirm -q $(PACMAN_PKGS) > /dev/null; \
	elif command -v apt-get > /dev/null 2>&1; then \
		$$SUDO apt-get update -q > /dev/null && \
		$$SUDO apt-get install -y -q --no-install-recommends $(APT_PKGS) > /dev/null; \
	elif command -v dnf > /dev/null 2>&1; then \
		$$SUDO dnf install -y -q $(DNF_PKGS) > /dev/null; \
	else \
		echo "Error: Unsupported package manager." && exit 1; \
	fi; \
	rustup target add $(RUST_TARGETS)
	@$(MAKE) --no-print-directory update
update:
	@git submodule update --init --recursive --depth 1 --remote
build_all: install

    # --------------------------------------------------
    # 						Desktop
    # --------------------------------------------------
	
    # x86_64 (x86 64-bit / AMD64)
	@$(MAKE) --no-print-directory build TYPE=Desktop ARCH=x86_64 MODE=Release LIB=musl
	@$(MAKE) --no-print-directory build TYPE=Desktop ARCH=x86_64 MODE=Release LIB=glibc
	@$(MAKE) --no-print-directory build TYPE=Desktop ARCH=x86_64 MODE=Dev LIB=musl
	@$(MAKE) --no-print-directory build TYPE=Desktop ARCH=x86_64 MODE=Dev LIB=glibc

    # aarch64 (ARM 64-bit)
	@$(MAKE) --no-print-directory build TYPE=Desktop ARCH=aarch64 MODE=Release LIB=musl
	@$(MAKE) --no-print-directory build TYPE=Desktop ARCH=aarch64 MODE=Release LIB=glibc
	@$(MAKE) --no-print-directory build TYPE=Desktop ARCH=aarch64 MODE=Dev LIB=musl
	@$(MAKE) --no-print-directory build TYPE=Desktop ARCH=aarch64 MODE=Dev LIB=glibc

    # riscv64 (RISC-V 64-bit)
	@$(MAKE) --no-print-directory build TYPE=Desktop ARCH=riscv64 MODE=Release LIB=musl
	@$(MAKE) --no-print-directory build TYPE=Desktop ARCH=riscv64 MODE=Release LIB=glibc
	@$(MAKE) --no-print-directory build TYPE=Desktop ARCH=riscv64 MODE=Dev LIB=musl
	@$(MAKE) --no-print-directory build TYPE=Desktop ARCH=riscv64 MODE=Dev LIB=glibc
	
    # --------------------------------------------------
    # 						Server
    # --------------------------------------------------

    # x86_64 (x86 64-bit / AMD64)
	@$(MAKE) --no-print-directory build TYPE=Server ARCH=x86_64 MODE=Release LIB=musl
	@$(MAKE) --no-print-directory build TYPE=Server ARCH=x86_64 MODE=Release LIB=glibc
	@$(MAKE) --no-print-directory build TYPE=Server ARCH=x86_64 MODE=Dev LIB=musl
	@$(MAKE) --no-print-directory build TYPE=Server ARCH=x86_64 MODE=Dev LIB=glibc

    # aarch64 (ARM 64-bit)
	@$(MAKE) --no-print-directory build TYPE=Server ARCH=aarch64 MODE=Release LIB=musl
	@$(MAKE) --no-print-directory build TYPE=Server ARCH=aarch64 MODE=Release LIB=glibc
	@$(MAKE) --no-print-directory build TYPE=Server ARCH=aarch64 MODE=Dev LIB=musl
	@$(MAKE) --no-print-directory build TYPE=Server ARCH=aarch64 MODE=Dev LIB=glibc

    # riscv64 (RISC-V 64-bit)
	@$(MAKE) --no-print-directory build TYPE=Server ARCH=riscv64 MODE=Release LIB=musl
	@$(MAKE) --no-print-directory build TYPE=Server ARCH=riscv64 MODE=Release LIB=glibc
	@$(MAKE) --no-print-directory build TYPE=Server ARCH=riscv64 MODE=Dev LIB=musl
	@$(MAKE) --no-print-directory build TYPE=Server ARCH=riscv64 MODE=Dev LIB=glibc

build: initramfs shim # fearinit kernel
build_test: install
	@$(MAKE) --no-print-directory build TYPE=Desktop ARCH=x86_64 MODE=Release LIB=musl
	@$(MAKE) --no-print-directory build TYPE=Desktop ARCH=x86_64 MODE=Release LIB=glibc
	@$(MAKE) --no-print-directory build TYPE=Desktop ARCH=x86_64 MODE=Dev LIB=musl
	@$(MAKE) --no-print-directory build TYPE=Desktop ARCH=x86_64 MODE=Dev LIB=glibc
initramfs:
	@mkdir -p $(CACHE)/$(TARGET)/initramfs/bin \
	         $(CACHE)/$(TARGET)/initramfs/dev \
	         $(CACHE)/$(TARGET)/initramfs/proc \
	         $(CACHE)/$(TARGET)/initramfs/sys \
	         $(CACHE)/$(TARGET)/iso/EFI/BOOT
shim:
	@if [ ! -f $(SHIM_x86_64) ]; then \
		echo "⬇️ Downloading x86_64 shim..."; \
		curl -fL -o $(SHIM_x86_64) -s https://dl.fedoraproject.org/pub/fedora/linux/releases/44/Everything/x86_64/os/Packages/s/shim-x64-16.1-5.x86_64.rpm || \
		{ echo "❌ Failed to download x86_64 shim"; rm -f $(SHIM_x86_64); exit 1; }; \
	fi
	@if [ ! -f $(SHIM_aarch64) ]; then \
		echo "⬇️ Downloading aarch64 shim..."; \
		curl -fL -o $(SHIM_aarch64) -s https://dl.fedoraproject.org/pub/fedora/linux/releases/44/Everything/aarch64/os/Packages/s/shim-aa64-16.1-5.aarch64.rpm || \
		{ echo "❌ Failed to download aarch64 shim"; rm -f $(SHIM_aarch64); exit 1; }; \
	fi
	@echo "📦 Extracting shim for ARCH=$(ARCH) into $(EFI_BOOT)..."
	@if [ "$(ARCH)" = "x86_64" ]; then \
        bsdtar -xf $(SHIM_x86_64) -C $(EFI_BOOT) --strip-components 8 "*EFI/BOOT/*" "*mmx64.efi"; \
        printf 'BOOTX64.EFI,$(OS_NAME),,This is the boot entry for $(OS_NAME)\n' | iconv -t UTF-16LE > $(EFI_BOOT)/BOOTX64.CSV; \
    elif [ "$(ARCH)" = "aarch64" ]; then \
        bsdtar -xf $(SHIM_aarch64) -C $(EFI_BOOT) --strip-components 8 "*EFI/BOOT/*" "*mmaa64.efi"; \
        printf 'BOOTAA64.EFI,$(OS_NAME),,This is the boot entry for $(OS_NAME)\n' | iconv -t UTF-16LE > $(EFI_BOOT)/BOOTAA64.CSV; \
    elif [ "$(ARCH)" = "riscv64" ]; then \
        printf 'BOOTRISCV64.EFI,$(OS_NAME),,This is the boot entry for $(OS_NAME)\n' | iconv -t UTF-16LE > $(EFI_BOOT)/BOOTRISCV64.CSV; \
    fi
fearinit:
	@$(MAKE) --no-print-directory -C $(FEARINIT)
kernel:
	$(MAKE) --no-print-directory -C $(LINUX) $(KARGS) ARCH=$(ARCH) tinyconfig
	$(LINUX)/scripts/kconfig/merge_config.sh -O $(LINUX) \
		$(LINUX)/.config \
		config/$(ARCH).config \
		config/$(TYPE).config \
		config/$(MODE).config
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
docker: clean
	docker compose up --build
	mkdir -p ./output
	docker cp $$(docker compose ps -qa builder):/build/output/. ./output/
	docker compose down
podman: clean
	podman-compose up --build
	mkdir -p ./output
	podman cp $$(podman-compose ps -qa builder):/build/output/. ./output/
	podman-compose down
clean:
	rm -rf $(CACHE)
	rm -rf target
	rm -rf $(OUTPUT)
test:
	qemu-system-x86_64 -enable-kvm -cdrom $(OUTPUT)/$(OS_NAME)_Dev.iso -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF.4m.fd -m 2G\
		-serial stdio \
		-monitor vc