# 	Makefile
#
#  Copyright (C) 2026 Souls (Secure Your Soul)
#  Licensed under the GNU Affero General Public License v3.0.
#
# --------- CONFIG ---------
	OS_NAME 	 := Fearless
	MODE		 ?= Release
	OS_FULLNAME  := $(OS_NAME)_$(TYPE)_$(ARCH)_$(MODE)
	PIV_CERT  	 := $(OS_NAME).cer
    # Github
	ORGANIZATION := Secure-Your-Soul
	VERSION 	 := v0.1.0
    # Root folder
	ROOT   := $(CURDIR)
    # Temporary files (CACHE)
	CACHE 		 := $(ROOT)/.cache
    # System directory structure
	ESP			 := $(CACHE)/ESP
	INITRAMFS 	 := $(CACHE)/initramfs
	ROOTFS    	 := $(CACHE)/rootfs
	LINUX		 := $(ROOT)/linux
	ESP_EFI		 := $(ESP)/EFI
	ESP_EFI_BOOT := $(ESP_EFI)/BOOT
    # OUTPUT 
	OUTPUT 		 := $(ROOT)/output
	ISO       	 := $(OUTPUT)/$(OS_NAME)-$(VERSION)-$(TYPE)-$(ARCH)-$(MODE).iso
    # Init
	INIT_TAG := v0.1.4
	INIT_REPOSITORY := FearInit
    # Kernel
	KERNEL_CPU ?= native
    KERNEL_FLAGS ?= LLVM=1 LLVM_IAS=1 LD=ld.lld CC="ccache clang" ARCH=$(KERNEL_ARCH) CROSS_COMPILE=$(CROSS_PREFIX)
	ALL_TYPES 	 := Desktop Server

# --------- CPU → ARCH mapping ---------

	X86_CPUS     := x86-64 x86-64-v2 x86-64-v3 x86-64-v4 \
					i386 i486 i586 i686 pentium pentium2 pentium3 pentium4 \
					prescott nocona core2 penryn nehalem westmere \
					sandybridge ivybridge haswell broadwell skylake skylake-avx512 \
					cannonlake icelake-client icelake-server cascadelake \
					cooperlake tigerlake rocketlake alderlake raptorlake \
					meteorlake sapphirerapids graniterapids sierraforest \
					emeraldrapids arrowlake lunarlake pantherlake \
					k8 athlon64 opteron amdfam10 bdver1 bdver2 bdver3 bdver4 \
					znver1 znver2 znver3 znver4 znver5

	AARCH64_CPUS := generic cortex-a34 cortex-a35 cortex-a53 cortex-a55 \
					cortex-a57 cortex-a72 cortex-a73 cortex-a75 cortex-a76 \
					cortex-a77 cortex-a78 cortex-a510 cortex-a710 cortex-a715 \
					cortex-a720 cortex-a725 cortex-a520 cortex-x1 cortex-x1c \
					cortex-x2 cortex-x3 cortex-x4 cortex-x925 \
					neoverse-n1 neoverse-n2 neoverse-n3 neoverse-v1 \
					neoverse-v2 neoverse-v3 neoverse-e1 neoverse-512tvb \
					apple-a7 apple-a8 apple-a9 apple-a10 apple-a11 apple-a12 \
					apple-a13 apple-a14 apple-a15 apple-a16 apple-a17 \
					apple-m1 apple-m2 apple-m3 apple-m4 \
					ampere1 ampere1a ampere1b a64fx carmel cyclone \
					exynos-m1 exynos-m2 exynos-m3 exynos-m4 exynos-m5 \
					falkor fujitsu-monaka grace kryo oryon-1 saphira \
					thunderx thunderx2t99 thunderx3t110 tsv110

	RISCV_CPUS   := generic-rv64 rocket-rv64 sifive-u54 sifive-u74 \
					sifive-s21 sifive-s51 sifive-s54 sifive-s76 \
					sifive-p450 sifive-p670 sifive-x280 \
					veyron-v1 xiangshan-nanhu

	ifeq ($(origin ARCH),undefined)
		ifneq ($(filter $(KERNEL_CPU),$(X86_CPUS)),)
			ARCH := x86_64
		else ifneq ($(filter $(KERNEL_CPU),$(AARCH64_CPUS)),)
			ARCH := aarch64
		else ifneq ($(filter $(KERNEL_CPU),$(RISCV_CPUS)),)
			ARCH := riscv64
		else ifeq ($(KERNEL_CPU),native)
			# native → wykryj z hosta
			ARCH := $(shell uname -m)
		else
			$(error Unknown KERNEL_CPU='$(KERNEL_CPU)'. Add it to X86_CPUS, AARCH64_CPUS or RISCV_CPUS in Makefile.)
		endif
	endif

# Dynamic Kernel & EFI Target Mapping
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

# Kernel flags per arch
	ifeq ($(ARCH),aarch64)
		KERNEL_CPU_FLAG := -mcpu=$(KERNEL_CPU) -mno-aes -mno-sha2 -mno-crc
	else ifeq ($(ARCH),riscv64)
		KERNEL_CPU_FLAG := -mcpu=$(KERNEL_CPU)
	else
		KERNEL_CPU_FLAG := -march=$(KERNEL_CPU)
	endif
	KERNEL_FLAGS += KCFLAGS="$(KERNEL_CPU_FLAG)"

.PHONY: var-% all build_all dev build update clean download-github-release esp initramfs rootfs kernel sign iso iso_test sign_test uefi bios test-direct

var-%:
	@echo '$*=$($*)'

all: build_all

build_all:
	@rm -rf $(OUTPUT)
	@docker compose --progress quiet build builder
	@set -e; \
	for type in $(ALL_TYPES); do \
		printf "▶  %-15s • %-10s • %s\n" "$(ARCH)" "$$type" "$(MODE) $(VERSION) $(KERNEL_CPU)"; \
	  	docker compose --progress quiet run --quiet --quiet-pull --rm builder \
	  		make build ARCH=$(ARCH) TYPE=$$type MODE=$(MODE) KERNEL_CPU=$(KERNEL_CPU); \
	done
	@echo "✅ Build all complete"

dev:
	@$(MAKE) build_all MODE=Dev --no-print-directory

build: clean esp initramfs rootfs kernel sign iso iso_test sign_test

update:
	@git submodule update --remote --recursive

clean:
	@rm -rf $(ESP)
	@rm -rf $(INITRAMFS)
	@rm -rf $(ROOTFS)
#	@rm -rf $(CACHE)

esp:
	@mkdir -p $(ESP_EFI_BOOT)
	@cp $(OS_NAME).cer $(ESP_EFI)

initramfs:
	@mkdir -p $(CACHE) $(INITRAMFS)/etc

	@printf "▶  %-15s • %-10s • %s\n" "Fetch" "$(INIT_REPOSITORY)" "$(INIT_TAG)"
	@curl -fL -sS -o $(INITRAMFS)/init https://github.com/$(ORGANIZATION)/$(INIT_REPOSITORY)/releases/download/$(INIT_TAG)/$(INIT_REPOSITORY)-$(ARCH)
	@chmod +x $(INITRAMFS)/init
	@printf "▶  %-15s • %-10s • %s\n" "Ready" "$(INIT_REPOSITORY)" "$(MODE)"

    # Create CPIO LIST
	@printf '%s\n' \
	  'dir /dev 0755 0 0' \
	  'nod /dev/console 600 0 0 c 5 1' \
	  'nod /dev/null 0666 0 0 c 1 3' \
	  'nod /dev/mem 600 0 0 c 1 1' \
	  'dir /proc 0555 0 0' \
	  'dir /sys 0555 0 0' \
	  > $(CACHE)/cpio.list

    # Path to the directory or cpio archive that will be linked DIRECTLY INTO THE KERNEL IMAGE (no external initrd required).
	@echo "CONFIG_INITRAMFS_SOURCE=\"$(INITRAMFS) $(CACHE)/cpio.list\"" > $(CACHE)/generated.config

	@printf 'NAME="$(OS_NAME) OS"\n' > $(INITRAMFS)/etc/os-release
	@printf 'ID=$(shell echo $(OS_NAME) | tr A-Z a-z)\n' >> $(INITRAMFS)/etc/os-release
	@printf 'PRETTY_NAME="$(OS_NAME) OS $(VERSION)"\n' >> $(INITRAMFS)/etc/os-release
	@printf 'VERSION_ID="$(VERSION)"\n' >> $(INITRAMFS)/etc/os-release
	@printf 'HOME_URL="https://github.com/$(ORGANIZATION)/$(OS_NAME)"\n' >> $(INITRAMFS)/etc/os-release
	@printf 'DOCUMENTATION_URL="https://github.com/$(ORGANIZATION)/$(OS_NAME)/wiki"\n' >> $(INITRAMFS)/etc/os-release
	@printf 'SUPPORT_URL="https://github.com/$(ORGANIZATION)/$(OS_NAME)/discussions"\n' >> $(INITRAMFS)/etc/os-release
	@printf 'BUG_REPORT_URL="https://github.com/$(ORGANIZATION)/$(OS_NAME)/issues"\n' >> $(INITRAMFS)/etc/os-release
	@printf 'PRIVACY_POLICY_URL="https://github.com/$(ORGANIZATION)/$(OS_NAME)/blob/stable/PRIVACY.md"\n' >> $(INITRAMFS)/etc/os-release
	@printf 'ANSI_COLOR="1;31"\n' >> $(INITRAMFS)/etc/os-release
	@printf 'CPE_NAME="cpe:/o:$(shell echo $(ORGANIZATION) | tr A-Z a-z):$(shell echo $(OS_NAME) | tr A-Z a-z)_os:$(VERSION)"\n' >> $(INITRAMFS)/etc/os-release

rootfs:
	@mkdir -p $(ROOTFS)

   # --- EROFS ---
	@mkfs.erofs --quiet -zzstd /tmp/rootfs.erofs $(ROOTFS)
	@printf "▶  %-15s • %-10s • %s (%s)\n" "EROFS" "Ready" "/tmp/rootfs.erofs" "$$(du -h /tmp/rootfs.erofs | cut -f1) zstd"

   # --- DM-VERITY ---
	@veritysetup format /tmp/rootfs.erofs /tmp/rootfs.hash 2>&1 | grep "Root hash" | awk '{print $$3}' > /tmp/root_hash.txt
	@$(MAKE) --silent --no-print-directory rootfs_vars
	@printf "▶  %-15s • %-10s • %s\n" "VERITY" "Ready" "$(ROOT_HASH)"
	@echo "CONFIG_CMDLINE=\"$(CMDLINE_FLAGS)\"" >> $(CACHE)/generated.config;
	@printf "▶  %-15s • %-10s • %s\n" "CMD Flags" "Ready" "$(CMDLINE_FLAGS)"

rootfs_vars:

ROOT_HASH = $$(cat /tmp/root_hash.txt)
CMDLINE_FLAGS = hostname=host roothash=$(ROOT_HASH) $(if $(filter Release,$(MODE)),quiet panic=10 console=ttyS0,console=ttyS0 ignore_loglevel earlyprintk=serial,ttyS0,115200 debug initcall_debug loglevel=8)

kernel:
	@mkdir -p $(CACHE)/kernel/$(KERNEL_ARCH)
	@printf "▶  %-15s • %-10s • %s\n" "defconfig" "Kernel" "v$(shell $(MAKE) -s --no-print-directory -C $(LINUX) O=$(CACHE)/kernel/$(KERNEL_ARCH) ARCH=$(KERNEL_ARCH) kernelversion 2>/dev/null)"
	@$(MAKE) --silent --no-print-directory -C $(LINUX) O=$(CACHE)/kernel/$(KERNEL_ARCH) $(KERNEL_FLAGS) defconfig
	@printf "▶  %-15s • %-10s • %s\n" "merge configs" "Kernel" "v$(shell $(MAKE) -s --no-print-directory -C $(LINUX) O=$(CACHE)/kernel/$(KERNEL_ARCH) ARCH=$(KERNEL_ARCH) kernelversion 2>/dev/null)"
	@$(LINUX)/scripts/kconfig/merge_config.sh -m -O $(CACHE)/kernel/$(KERNEL_ARCH) \
		$(CACHE)/kernel/$(KERNEL_ARCH)/.config \
		$(ROOT)/configs/default.config \
		$(CACHE)/generated.config > /dev/null

	@printf "▶  %-15s • %-10s • %s\n" "olddefconfig" "Kernel" "v$(shell $(MAKE) -s --no-print-directory -C $(LINUX) O=$(CACHE)/kernel/$(KERNEL_ARCH) ARCH=$(KERNEL_ARCH) kernelversion 2>/dev/null)"
	@$(MAKE) --silent -C $(LINUX) O=$(CACHE)/kernel/$(KERNEL_ARCH) $(KERNEL_FLAGS) olddefconfig
	@printf "▶  %-15s • %-10s • %s\n" "Build" "Kernel" "v$(shell $(MAKE) -s --no-print-directory -C $(LINUX) O=$(CACHE)/kernel/$(KERNEL_ARCH) ARCH=$(KERNEL_ARCH) kernelversion 2>/dev/null)"
	@$(MAKE) --silent --no-print-directory -C $(LINUX) O=$(CACHE)/kernel/$(KERNEL_ARCH) $(KERNEL_FLAGS) $(KERNEL_TARGET) -j$(nproc) -l16
	@cp $(CACHE)/kernel/$(KERNEL_ARCH)/arch/$(KERNEL_ARCH)/boot/$(KERNEL_TARGET) $(ESP_EFI_BOOT)/$(EFI_OUT_NAME)
	@printf "▶  %-15s • %-10s • %s\n" "Ready" "Kernel" "$(MODE)"

	@rm $(CACHE)/cpio.list $(CACHE)/generated.config

iso:
	@mkdir -p $(OUTPUT)

    # --- ESP: FAT32 with UKI ---
	@printf "▶  %-15s • %-10s • %s (%s)\n" "ISO/FAT32" "Build" "/tmp/efi.img" "FAT32"
	@dd if=/dev/zero of=/tmp/efi.img bs=1M count=64 status=none
	@mkfs.vfat -F 32 -n $(shell echo $(OS_NAME) | tr a-z A-Z) /tmp/efi.img > /dev/null
	@MTOOLS_SKIP_CHECK=1 mmd -i /tmp/efi.img ::/EFI ::/EFI/BOOT
	@MTOOLS_SKIP_CHECK=1 mcopy -i /tmp/efi.img $(ESP)/EFI/BOOT/*.EFI ::/EFI/BOOT/
	@printf "▶  %-15s • %-10s • %s (%s)\n" "ISO/FAT32" "Ready" "/tmp/efi.img" "$$(du -h /tmp/efi.img | cut -f1) zstd"

    # --- Hybrid ISO ---
	@printf "▶  %-15s • %-10s • %s (%s)\n" "ISO" "Build" "$(ISO)" "FAT32 + EROFS"
	@empty=$$(mktemp -d); \
	xorriso -as mkisofs -quiet \
	  -o $(ISO) \
	  -R -J -V "$(OS_NAME)" \
	  -partition_offset 16 \
	  -appended_part_as_gpt \
	  -append_partition 1 C12A7328-F81F-11D2-BA4B-00A0C93EC93B /tmp/efi.img \
	  -append_partition 2 0FC63DAF-8483-4772-8E79-3D69D8477DE4 /tmp/rootfs.erofs \
	  -eltorito-alt-boot \
	  -e --interval:appended_partition_1:all:: \
	  -no-emul-boot \
	  -isohybrid-gpt-basdat \
	  $$empty; \
	rmdir $$empty

	@rm -f /tmp/rootfs.erofs
	@printf "▶  %-15s • %-10s • %s (%s)\n" "ISO" "Ready" "$(ISO)" "$$(du -h $(ISO) | cut -f1)"

iso_test: $(ISO)
	@echo "🔍 Testing $(ISO)"
	@PASS=0; FAIL=0; \
	check() { \
	  desc="$$1"; shift; \
	  if "$$@" >/dev/null 2>&1; then \
	    echo "  ✅ $$desc"; PASS=$$((PASS+1)); \
	  else \
	    echo "  ❌ $$desc"; FAIL=$$((FAIL+1)); \
	  fi; \
	}; \
	check "ISO marked bootable"           sh -c "file $(ISO) | grep -q bootable"; \
	check "ISO9660 volume"                sh -c "isoinfo -d -i $(ISO) | grep -q 'Volume id'"; \
	check "El Torito boot entry (CD/DVD)" sh -c "isoinfo -d -i $(ISO) | grep -q 'Bootid 88 (bootable)'"; \
	check "UEFI El Torito image"          sh -c "xorriso -indev $(ISO) -report_el_torito plain 2>/dev/null | grep -q 'UEFI'"; \
	check "GPT partition table"           sh -c "parted -s $(ISO) print | grep -q 'Partition Table: gpt'"; \
	check "Protective MBR"                sh -c "xorriso -indev $(ISO) -report_system_area plain 2>/dev/null | grep -q 'MBR protective'"; \
	check "ESP (FAT32 + boot/esp flags)"  sh -c "parted -s $(ISO) print | grep -qE 'fat32.*(boot|esp)'"; \
	check "UKI $(EFI_OUT_NAME) on ESP"    sh -c "MTOOLS_SKIP_CHECK=1 mdir -i /tmp/efi.img ::/EFI/BOOT/$(EFI_OUT_NAME)"; \
	echo ""; \
	if [ $$FAIL -eq 0 ]; then \
	  echo "✅ All tests passed ($$PASS/$$PASS)"; \
	else \
	  echo "❌ $$FAIL failed, $$PASS passed"; \
	  exit 1; \
	fi
	@rm /tmp/efi.img

sign:

sign_test:

uefi:
	#docker compose run --rm builder gpg --card-status
	docker compose run --rm test sh -c " \
	ISO_FILE=\$$(ls output/*.iso | head -n 1) && \
	cp /usr/share/OVMF/OVMF_VARS_4M.fd /tmp/OVMF_VARS.fd && \
	qemu-system-x86_64 \
		-enable-kvm \
		-m 2048 \
		-cpu max \
		-nographic \
		-drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
		-drive if=pflash,format=raw,readonly=off,file=/tmp/OVMF_VARS.fd \
		-drive file=\$$ISO_FILE,format=raw,media=cdrom"

bios:
	docker compose run --rm test sh -c " \
	ISO_FILE=\$$(ls output/*.iso | head -n 1) && \
	qemu-system-x86_64 \
		-enable-kvm \
		-m 2048 \
		-machine q35 \
		-cpu max \
		-nographic \
		-drive file=\$$ISO_FILE,format=raw,media=cdrom"

test-direct:
	@rm $(CACHE)/initramfs.cpio.zst
	@cd $(INITRAMFS) && find . -print0 | cpio --null -o -H newc | zstd -T0 -19 -o $(CACHE)/initramfs.cpio.zst
	qemu-system-x86_64 \
		-enable-kvm \
		-m 2048 \
		-cpu max \
		-nographic \
		-kernel $(CACHE)/kernel/$(KERNEL_ARCH)/arch/$(KERNEL_ARCH)/boot/$(KERNEL_TARGET) \
		-initrd $(CACHE)/initramfs.cpio.zst
	@rm $(CACHE)/initramfs.cpio.zst