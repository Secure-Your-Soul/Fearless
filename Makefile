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
	VERSION  	 ?= v0.0.1
    # System directory structure
	ROOTFS    	 := rootfs
	INITRAMFS 	 := initramfs
	ESP			 := ESP
	ESP_EFI		 := $(ESP)/EFI
	ESP_EFI_BOOT := $(ESP_EFI)/BOOT
    # --------- OUTPUT ---------
	OUTPUT 		 := output
	ISO       	 := $(OUTPUT)/$(OS_NAME)-$(VERSION)-$(TYPE)-$(ARCH)-$(MODE).iso
    # --------- Temporary files (CACHE) ---------
	CACHE 		 := .cache
    # --------- Init ---------
	INIT_TAG := v0.0.1
	INIT_REPOSITORY := FearInit
    # --------- Kernel Binary File ---------
    KERNEL_IMAGE := $(LINUX)/arch/$(ARCH)/boot/bzImage
    KERNEL_FLAGS := LLVM=1 LLVM_IAS=1 LD=ld.lld CC="ccache clang" ARCH=$(KERNEL_ARCH) CROSS_COMPILE=$(CROSS_PREFIX)
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
	@set -e; \
	for arch in $(ALL_ARCHS); do \
	  for type in $(ALL_TYPES); do \
	    for mode in $(ALL_MODES); do \
			echo "▶ $$arch • $$type • $$mode"; \
			$(MAKE) --no-print-directory build ARCH=$$arch TYPE=$$type MODE=$$mode; \
	    done; \
	  done; \
	done
	@echo "✅ build_all complete"
build: clean esp initramfs rootfs kernel sign iso iso_test sign_test clean
clean:
	@rm -rf $(ESP)
	@rm -rf $(INITRAMFS)
	@rm -rf $(CACHE)

esp:
	@mkdir -p $(ESP_EFI_BOOT)
	@cp $(OS_NAME).cer $(ESP_EFI)
initramfs:
	@bash -c "mkdir -p $(INITRAMFS)/{bin,dev,proc,sbin,sys}"
	@echo "📥 Fetching $(INIT_REPOSITORY) $(INIT_TAG)"
	@curl -fL -sS -o $(INITRAMFS)/init https://github.com/$(ORGANIZATION)/$(INIT_REPOSITORY)/releases/download/$(INIT_TAG)/$(INIT_REPOSITORY)-$(ARCH)-musl
	@chmod +x $(INITRAMFS)/init
	@echo "✅ Download finished successfully"
rootfs:

kernel:
	@$(MAKE) --no-print-directory -C $(LINUX) $(KERNEL_FLAGS) defconfig
	@$(MAKE) --no-print-directory -C $(LINUX) $(KERNEL_FLAGS) $(KERNEL_TARGET) -j$(shell nproc)
iso:
	@rm -rf $(OUTPUT)
	@mkdir -p $(OUTPUT)
    # --- ESP: FAT32 with UKI ---
	@dd if=/dev/zero of=$(OUTPUT)/efi.img bs=1M count=64 status=none
	@out=$$(mkfs.vfat -F 32 -n FEARLESS $(OUTPUT)/efi.img 2>&1); rc=$$?; \
	if [ $$rc -ne 0 ]; then echo "$$out"; exit $$rc; fi
	@out=$$(MTOOLS_SKIP_CHECK=1 mmd -i $(OUTPUT)/efi.img ::/EFI ::/EFI/BOOT 2>&1); rc=$$?; \
	if [ $$rc -ne 0 ]; then echo "$$out"; exit $$rc; fi
	@for uki in $(ESP)/*.efi $(ESP)/*.EFI; do \
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
	@echo "✅ ISO: $(ISO) ($$(du -h $(ISO) | cut -f1))"
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
sign:

sign_test:

docker:
	docker compose down --remove-orphans
	docker compose up --build --abort-on-container-exit --exit-code-from builder