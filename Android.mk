LOCAL_PATH := $(call my-dir)

ifneq ($(filter kminilte,$(TARGET_DEVICE)),)

# Blobs stay byte-identical to the stock images in this tree; patches are
# applied to build-time copies under TARGET_OUT_INTERMEDIATES instead.
KMINILTE_PATCHED := $(TARGET_OUT_INTERMEDIATES)/vendor/samsung/kminilte/patched
# Recipes expand at execution time; keep script paths in unique globals.
KMINILTE_HWC_PATCH_SCRIPT := $(LOCAL_PATH)/patches/patch_hwc_query.sh
KMINILTE_MPLMPU_PATCH_SCRIPT := $(LOCAL_PATH)/patches/patch_mplmpu_dynsym.py

# hwcomposer.exynos3.so: query() must not claim HWC_BACKGROUND_LAYER_SUPPORTED
# (libdisplay.so dereferences layer->handle unconditionally -> SF crash).
$(KMINILTE_PATCHED)/hw/hwcomposer.exynos3.so: \
		$(LOCAL_PATH)/proprietary/lib/hw/hwcomposer.exynos3.so \
		$(KMINILTE_HWC_PATCH_SCRIPT)
	@mkdir -p $(dir $@)
	cp $< $@
	$(KMINILTE_HWC_PATCH_SCRIPT) $@

include $(CLEAR_VARS)
LOCAL_MODULE := hwcomposer.exynos3
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_OWNER := samsung
LOCAL_MODULE_SUFFIX := .so
LOCAL_MODULE_PATH := $(TARGET_OUT)/lib/hw
LOCAL_PREBUILT_MODULE_FILE := $(KMINILTE_PATCHED)/hw/hwcomposer.exynos3.so
LOCAL_STRIP_MODULE := false
include $(BUILD_SHARED_LIBRARY)

# libmplmpu.so: 9 misplaced LOCAL dynsym entries break lld when
# libinvensense_hal links against it. The patched copy is consumed by the
# libmplmpu prebuilt module in libsensors/Android.mk (same target path).
$(KMINILTE_PATCHED)/libmplmpu.so: \
		$(LOCAL_PATH)/proprietary/lib/libmplmpu.so \
		$(KMINILTE_MPLMPU_PATCH_SCRIPT)
	@mkdir -p $(dir $@)
	cp $< $@
	python3 $(KMINILTE_MPLMPU_PATCH_SCRIPT) $@

endif
