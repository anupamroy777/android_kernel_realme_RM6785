# Copyright (C) 2017 MediaTek Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See http://www.gnu.org/licenses/gpl-2.0.html for more details.

LOCAL_PATH := $(call my-dir)

ifeq ($(notdir $(LOCAL_PATH)),$(strip $(LINUX_KERNEL_VERSION)))
ifneq ($(strip $(TARGET_NO_KERNEL)),true)
include $(LOCAL_PATH)/kenv.mk

#ifdef OPLUS_ARCH_INJECT
#Sunliang@ANDROID.BUILD, 2020/04/08, export global native features to kernel
my_feature_file := $(LOCAL_PATH)/oplus_native_features.sh

$(shell echo "#!/bin/bash" > $(my_feature_file))
$(shell echo 'export OPLUS_NATIVE_FEATURE_SET="$(strip $(SOONG_CONFIG_oplusNativeFeaturePlugin))"' >> $(my_feature_file))
$(foreach key,$(SOONG_CONFIG_oplusNativeFeaturePlugin), \
  $(shell echo 'export $(key)=$(SOONG_CONFIG_oplusNativeFeaturePlugin_$(key))' >> $(my_feature_file))\
)
#endif /* OPLUS_ARCH_INJECT */
ifeq ($(wildcard $(TARGET_PREBUILT_KERNEL)),)
KERNEL_MAKE_DEPENDENCIES := $(shell find $(KERNEL_DIR) -name .git -prune -o -type f | sort)
KERNEL_MAKE_DEPENDENCIES := $(filter-out %/.git %/.gitignore %/.gitattributes,$(KERNEL_MAKE_DEPENDENCIES))

$(TARGET_KERNEL_CONFIG): PRIVATE_DIR := $(KERNEL_DIR)
$(TARGET_KERNEL_CONFIG): $(KERNEL_CONFIG_FILE) $(LOCAL_PATH)/Android.mk
$(TARGET_KERNEL_CONFIG): $(KERNEL_MAKE_DEPENDENCIES)
	$(hide) mkdir -p $(dir $@)
#ifdef OPLUS_ARCH_INJECT
#Sunliang@ANDROID.BUILD, 2020/04/08, export global native features to kernel
	source $(srctree)/oplus_native_features.sh ; \
	$(PREBUILT_MAKE_PREFIX)$(MAKE) -C $(PRIVATE_DIR) $(KERNEL_MAKE_OPTION) $(KERNEL_DEFCONFIG)
#endif /* OPLUS_ARCH_INJECT */
$(BUILT_DTB_OVERLAY_TARGET): $(KERNEL_ZIMAGE_OUT)

.KATI_RESTAT: $(KERNEL_ZIMAGE_OUT)
$(KERNEL_ZIMAGE_OUT): PRIVATE_DIR := $(KERNEL_DIR)
$(KERNEL_ZIMAGE_OUT): $(TARGET_KERNEL_CONFIG) $(KERNEL_MAKE_DEPENDENCIES)
	$(hide) mkdir -p $(dir $@)
#ifdef OPLUS_ARCH_INJECT
#Sunliang@ANDROID.BUILD, 2020/04/08, export global native features to kernel
	source $(srctree)/oplus_native_features.sh ; \
	$(PREBUILT_MAKE_PREFIX)$(MAKE) -C $(PRIVATE_DIR) $(KERNEL_MAKE_OPTION)
#endif /* OPLUS_ARCH_INJECT */
	$(hide) $(call fixup-kernel-cmd-file,$(KERNEL_OUT)/arch/$(KERNEL_TARGET_ARCH)/boot/compressed/.piggy.xzkern.cmd)
	# check the kernel image size
	python device/mediatek/build/build/tools/check_kernel_size.py $(KERNEL_OUT) $(KERNEL_DIR) $(PROJECT_DTB_NAMES)

ifeq ($(strip $(MTK_HEADER_SUPPORT)), yes)
$(BUILT_KERNEL_TARGET): $(KERNEL_ZIMAGE_OUT) $(TARGET_KERNEL_CONFIG) $(LOCAL_PATH)/Android.mk | $(HOST_OUT_EXECUTABLES)/mkimage$(HOST_EXECUTABLE_SUFFIX)
	$(hide) $(HOST_OUT_EXECUTABLES)/mkimage$(HOST_EXECUTABLE_SUFFIX) $< KERNEL 0xffffffff > $@
else
$(BUILT_KERNEL_TARGET): $(KERNEL_ZIMAGE_OUT) $(TARGET_KERNEL_CONFIG) $(LOCAL_PATH)/Android.mk | $(ACP)
	$(copy-file-to-target)
endif

$(TARGET_PREBUILT_KERNEL): $(BUILT_KERNEL_TARGET) $(LOCAL_PATH)/Android.mk | $(ACP)
	$(copy-file-to-new-target)

endif#TARGET_PREBUILT_KERNEL is empty

$(INSTALLED_KERNEL_TARGET): $(BUILT_KERNEL_TARGET) $(LOCAL_PATH)/Android.mk | $(ACP)
	$(copy-file-to-target)

.PHONY: kernel save-kernel kernel-savedefconfig kernel-menuconfig menuconfig-kernel savedefconfig-kernel clean-kernel
kernel: $(INSTALLED_KERNEL_TARGET)
save-kernel: $(TARGET_PREBUILT_KERNEL)

kernel-savedefconfig: $(TARGET_KERNEL_CONFIG)
	cp $(TARGET_KERNEL_CONFIG) $(KERNEL_CONFIG_FILE)

kernel-menuconfig:
	$(hide) mkdir -p $(KERNEL_OUT)
#ifdef OPLUS_ARCH_INJECT
#Sunliang@ANDROID.BUILD, 2020/04/08, export global native features to kernel
	source $(srctree)/oplus_native_features.sh ; \
	$(MAKE) -C $(KERNEL_DIR) $(KERNEL_MAKE_OPTION) menuconfig
#endif /* OPLUS_ARCH_INJECT */

menuconfig-kernel savedefconfig-kernel:
	$(hide) mkdir -p $(KERNEL_OUT)
#ifdef OPLUS_ARCH_INJECT
#Sunliang@ANDROID.BUILD, 2020/04/08, export global native features to kernel
	source $(srctree)/oplus_native_features.sh ; \
	$(MAKE) -C $(KERNEL_DIR) $(KERNEL_MAKE_OPTION) $(patsubst %config-kernel,%config,$@)
#endif /* OPLUS_ARCH_INJECT */

#ifdef OPLUS_FEATURE_CHG_BASIC
ifneq ($(filter oppo6769_19741, $(OPPO_TARGET_DEVICE)),)
$(shell sed -i 's/CONFIG_USB_POWER_DELIVERY=y/# CONFIG_USB_POWER_DELIVERY is not set/g' $(KERNEL_CONFIG_FILE))
$(shell sed -i 's/CONFIG_TCPC_CLASS=y/# CONFIG_TCPC_CLASS is not set/g' $(KERNEL_CONFIG_FILE))
$(shell sed -i 's/CONFIG_TCPC_RT1711H=y/# CONFIG_TCPC_RT1711H is not set/g' $(KERNEL_CONFIG_FILE))
endif
#endif /*OPLUS_FEATURE_CHG_BASIC*/

clean-kernel:
	$(hide) rm -rf $(KERNEL_OUT) $(KERNEL_MODULES_OUT) $(INSTALLED_KERNEL_TARGET)
	$(hide) rm -f $(INSTALLED_DTB_OVERLAY_TARGET)

### DTB build template
ifeq ($(KERNEL_TARGET_ARCH),arm64)
MTK_DTBIMAGE_DTS := $(KERNEL_DIR)/arch/$(KERNEL_TARGET_ARCH)/boot/dts/mediatek/$(MTK_PLATFORM_DIR)$(if $(filter $(MTK_PLATFORM),MT8167 MT8168),_dtbo).dts
else
MTK_DTBIMAGE_DTS := $(KERNEL_DIR)/arch/$(KERNEL_TARGET_ARCH)/boot/dts/$(MTK_PLATFORM_DIR)$(if $(filter $(MTK_PLATFORM),MT8167 MT8168),_dtbo).dts
endif
include device/mediatek/build/core/build_dtbimage.mk
ifeq ($(KERNEL_TARGET_ARCH),arm64)
MTK_DTBOIMAGE_DTS := $(KERNEL_DIR)/arch/$(KERNEL_TARGET_ARCH)/boot/dts/mediatek/$(MTK_TARGET_PROJECT).dts
else
MTK_DTBOIMAGE_DTS := $(KERNEL_DIR)/arch/$(KERNEL_TARGET_ARCH)/boot/dts/$(MTK_TARGET_PROJECT).dts
endif
#MTK_DTBOIMAGE_DWS := $(KERNEL_DIR)/drivers/misc/mediatek/dws/$(MTK_PLATFORM_DIR)/$(MTK_TARGET_PROJECT).dws
include device/mediatek/build/core/build_dtboimage.mk
endif#TARGET_NO_KERNEL
endif#LINUX_KERNEL_VERSION
