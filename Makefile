# 	Makefile
#
#  Copyright (C) 2026 Souls (Secure Your Soul)
#  Licensed under the GNU Affero General Public License v3.0.
#
# --------- CONFIG ---------
	OS_NAME 	 := Fearless
	OS_FULLNAME  := $(OS_NAME)_$(TYPE)_$(ARCH)_$(MODE)
	PIV_CERT  	 := $(OS_NAME).cer
    # Github
	ORGANIZATION ?= Secure-Your-Soul
	VERSION  	 ?= v0.1.0
    # System directory structure
	ESP			 := ESP
	INITRAMFS 	 := initramfs
	ROOTFS    	 := rootfs
	LINUX		 := linux
	ESP_EFI		 := $(ESP)/EFI
	ESP_EFI_BOOT := $(ESP_EFI)/BOOT
    # --------- OUTPUT ---------
	OUTPUT 		 := output
	ISO       	 := $(OUTPUT)/$(OS_NAME)-$(VERSION)-$(TYPE)-$(ARCH)-$(MODE).iso
    # --------- Temporary files (CACHE) ---------
	CACHE 		 := .cache
    # --------- Init ---------
	INIT_TAG := v0.1.3
	INIT_REPOSITORY := FearInit
    # --------- Kernel Binary File ---------
    KERNEL_IMAGE := $(LINUX)/arch/$(ARCH)/boot/bzImage
    KERNEL_FLAGS ?= LLVM=1 LLVM_IAS=1 LD=ld.lld CC="ccache clang" ARCH=$(KERNEL_ARCH) CROSS_COMPILE=$(CROSS_PREFIX)
    # INSTALL
	RUST_TARGETS := x86_64-unknown-linux-musl aarch64-unknown-linux-musl riscv64gc-unknown-linux-musl
    # BUILD
	ALL_ARCHS 	 := x86_64 aarch64 riscv64
	ALL_TYPES 	 := Desktop Server
	ALL_MODES 	 := Release Dev
#	--------- Dynamic Kernel & EFI Target Mapping ---------
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

.PHONY: all build_all build clean download-github-release esp initramfs rootfs kernel sign iso iso_test sign_test docker

all: build_all

build_all:
	@rm -rf $(OUTPUT)
	@set -e; \
	for arch in $(ALL_ARCHS); do \
	  for type in $(ALL_TYPES); do \
	    for mode in $(ALL_MODES); do \
			printf "▶  %-10s • %-10s • %s\n" "$$arch" "$$type" "$$mode"; \
			$(MAKE) --no-print-directory build ARCH=$$arch TYPE=$$type MODE=$$mode; \
	    done; \
	  done; \
	done
	@echo "✅ Build all complete"

build: clean esp initramfs rootfs kernel sign iso iso_test sign_test

clean:
	@rm -rf $(ESP)
	@rm -rf $(INITRAMFS)
#	@rm -rf $(CACHE)

esp:
	@mkdir -p $(ESP_EFI_BOOT)
	@cp $(OS_NAME).cer $(ESP_EFI)

initramfs:
	@bash -c "mkdir -p $(INITRAMFS)/{bin,dev,proc,sbin,sys}"
	@printf "▶  %-10s • %-10s • %s\n" "Fetch" "$(INIT_REPOSITORY)" "$(INIT_TAG)"
	@curl -fL -sS -o $(INITRAMFS)/init https://github.com/$(ORGANIZATION)/$(INIT_REPOSITORY)/releases/download/$(INIT_TAG)/$(INIT_REPOSITORY)-$(ARCH)
	@chmod +x $(INITRAMFS)/init
	@printf "▶  %-10s • %-10s • %s\n" "Ready" "$(INIT_REPOSITORY)" "$(MODE)"

rootfs:

kernel:
	@mkdir -p $(CACHE)/kernel/$(KERNEL_ARCH)
	@printf "▶  %-10s • %-10s • %s\n" "defconfig" "Kernel" "v$(shell $(MAKE) -s --no-print-directory -C $(LINUX) O=$(PWD)/$(CACHE)/kernel/$(KERNEL_ARCH) ARCH=$(KERNEL_ARCH) kernelversion 2>/dev/null)"
	@$(MAKE) --silent --no-print-directory -C $(LINUX) O=$(PWD)/$(CACHE)/kernel/$(KERNEL_ARCH) $(KERNEL_FLAGS) defconfig
	@printf "▶  %-10s • %-10s • %s\n" "merge configs" "Kernel" "v$(shell $(MAKE) -s --no-print-directory -C $(LINUX) O=$(PWD)/$(CACHE)/kernel/$(KERNEL_ARCH) ARCH=$(KERNEL_ARCH) kernelversion 2>/dev/null)"
	@$(LINUX)/scripts/kconfig/merge_config.sh -m -O $(PWD)/$(CACHE)/kernel/$(KERNEL_ARCH) \
		$(PWD)/$(CACHE)/kernel/$(KERNEL_ARCH)/.config \
		$(PWD)/configs/initramfs.conf
	@printf "▶  %-10s • %-10s • %s\n" "olddefconfig" "Kernel" "v$(shell $(MAKE) -s --no-print-directory -C $(LINUX) O=$(PWD)/$(CACHE)/kernel/$(KERNEL_ARCH) ARCH=$(KERNEL_ARCH) kernelversion 2>/dev/null)"
	@$(MAKE) --silent -C $(LINUX) O=$(PWD)/$(CACHE)/kernel/$(KERNEL_ARCH) $(KERNEL_FLAGS) olddefconfig
	@printf "▶  %-10s • %-10s • %s\n" "Build" "Kernel" "v$(shell $(MAKE) -s --no-print-directory -C $(LINUX) O=$(PWD)/$(CACHE)/kernel/$(KERNEL_ARCH) ARCH=$(KERNEL_ARCH) kernelversion 2>/dev/null)"
	@$(MAKE) --silent --no-print-directory -C $(LINUX) O=$(PWD)/$(CACHE)/kernel/$(KERNEL_ARCH) $(KERNEL_FLAGS) $(KERNEL_TARGET) -j$(nproc) -l16
	@cp $(CACHE)/kernel/$(KERNEL_ARCH)/arch/$(KERNEL_ARCH)/boot/$(KERNEL_TARGET) $(ESP_EFI_BOOT)/$(EFI_OUT_NAME)
	@printf "▶  %-10s • %-10s • %s\n" "Ready" "Kernel" "$(MODE)"

iso:
	@mkdir -p $(OUTPUT)
    # --- ESP: FAT32 with UKI ---
	@dd if=/dev/zero of=$(OUTPUT)/efi.img bs=1M count=64 status=none
	@out=$$(mkfs.vfat -F 32 -n FEARLESS $(OUTPUT)/efi.img 2>&1); rc=$$?; \
	if [ $$rc -ne 0 ]; then echo "$$out"; exit $$rc; fi
	@out=$$(MTOOLS_SKIP_CHECK=1 mmd -i $(OUTPUT)/efi.img ::/EFI ::/EFI/BOOT 2>&1); rc=$$?; \
	if [ $$rc -ne 0 ]; then echo "$$out"; exit $$rc; fi
	@for uki in $(ESP)/EFI/BOOT/*.efi $(ESP)/EFI/BOOT/*.EFI; do \
	  [ -f "$$uki" ] || continue; \
	  out=$$(MTOOLS_SKIP_CHECK=1 mcopy -i $(OUTPUT)/efi.img "$$uki" ::/EFI/BOOT/ 2>&1); rc=$$?; \
	  if [ $$rc -ne 0 ]; then echo "$$out"; exit $$rc; fi; \
	done
    # --- Hybrid ISO ---
	@empty=$$(mktemp -d); \
	out=$$(xorriso -as mkisofs -quiet \
	  -o $(ISO) \
	  -R -J -V "FEARLESS" \
	  -partition_offset 16 \
	  -appended_part_as_gpt \
	  -append_partition 1 C12A7328-F81F-11D2-BA4B-00A0C93EC93B $(OUTPUT)/efi.img \
	  -eltorito-alt-boot \
	  -e --interval:appended_partition_1:all:: \
	  -no-emul-boot \
	  -isohybrid-gpt-basdat \
	  $$empty 2>&1); \
	rc=$$?; rmdir $$empty; \
	if [ $$rc -ne 0 ]; then echo "$$out"; exit $$rc; fi
	@printf "▶  %-10s • %-10s • %s (%s)\n" "ISO" "Ready" "$(PWD)/$(ISO)" "$$(du -h $(ISO) | cut -f1)"

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
	check "UKI $(EFI_OUT_NAME) on ESP"    sh -c "MTOOLS_SKIP_CHECK=1 mdir -i $(OUTPUT)/efi.img ::/EFI/BOOT/$(EFI_OUT_NAME)"; \
	echo ""; \
	if [ $$FAIL -eq 0 ]; then \
	  echo "✅ All tests passed ($$PASS/$$PASS)"; \
	else \
	  echo "❌ $$FAIL failed, $$PASS passed"; \
	  exit 1; \
	fi
	@rm $(OUTPUT)/efi.img

sign:

sign_test:

docker:
	docker compose down --remove-orphans
	docker compose up --build --abort-on-container-exit --exit-code-from builder

test:
	@echo "🖥️  Uruchamianie QEMU (UEFI)..."
	#docker compose run --rm builder gpg --card-status
	docker compose run --rm test sh -c "ISO_FILE=\$$(ls output/*.iso | head -n 1); \
	cp /usr/share/OVMF/OVMF_VARS_4M.fd /build/OVMF_VARS.fd && \
	qemu-system-x86_64 \
		-enable-kvm \
		-m 2048 \
		-cpu max \
		-nographic \
		-drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
		-drive if=pflash,format=raw,readonly=off,file=/build/OVMF_VARS.fd \
		-drive file=\$$ISO_FILE,format=raw,media=cdrom"