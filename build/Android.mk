LOCAL_PATH := $(call my-dir)

# ===== SDK source.property files =====

# Add all files to be generated from the source.prop templates to the SDK pre-requisites
sdk_props := $(patsubst \
               $(TOPDIR)development/sdk/%_source.prop_template, \
               $(HOST_OUT)/development/sdk/%_source.properties, \
               $(wildcard $(TOPDIR)development/sdk/*_source.prop_template))
sample_props := $(patsubst \
                  $(TOPDIR)development/samples/%_source.prop_template, \
                  $(HOST_OUT)/development/samples/%_source.properties, \
                  $(wildcard $(TOPDIR)development/samples/*_source.prop_template))
sys_img_props := $(patsubst \
                   $(TOPDIR)development/sys-img/%_source.prop_template, \
                   $(HOST_OUT)/development/sys-img-$(TARGET_CPU_ABI)/%_source.properties, \
                   $(wildcard $(TOPDIR)development/sys-img/*_source.prop_template))
ALL_SDK_FILES += $(sdk_props) $(sample_props) $(sys_img_props)

# Rule to convert a source.prop template into the desired source.property
# This needs to vary based on the CPU ABI for the system-image files.
# Rewritten variables:
# - ${PLATFORM_VERSION}               e.g. "1.0"
# - ${PLATFORM_SDK_VERSION}           e.g. "3", aka the API level
# - ${PLATFORM_EXTENSION_SDK_VERSION} e.g. "7" -- the extension sdk level
# - ${PLATFORM_IS_BASE_SDK}           bool. -- whether the current extension sdk is the base extension for this api level
# - ${PLATFORM_VERSION_CODENAME}      e.g. "REL" (transformed into "") or "Cupcake"
# - ${TARGET_ARCH}                    e.g. "arm", "x86", "mips" and their 64-bit variants.
# - ${TARGET_CPU_ABI}                 e.g. "armeabi", "x86", "mips" and their 64-bit variants.
define process_prop_template
@echo Generate $@
$(hide) mkdir -p $(dir $@)
$(hide) sed \
	-e 's/$${PLATFORM_VERSION}/$(PLATFORM_VERSION)/' \
	-e 's/$${PLATFORM_SDK_VERSION}/$(PLATFORM_SDK_VERSION)/' \
	-e 's/$${PLATFORM_SDK_EXTENSION_VERSION}/$(PLATFORM_SDK_EXTENSION_VERSION)/' \
	-e 's/$${PLATFORM_IS_BASE_SDK}/$(if $(filter $(PLATFORM_SDK_EXTENSION_VERSION),$(PLATFORM_BASE_SDK_EXTENSION_VERSION)),true,false)/' \
	-e 's/$${PLATFORM_VERSION_CODENAME}/$(subst REL,,$(PLATFORM_VERSION_CODENAME))/' \
	-e 's/$${TARGET_ARCH}/$(TARGET_ARCH)/' \
	-e 's/$${TARGET_CPU_ABI}/$(TARGET_CPU_ABI)/' \
	$< > $@ && sed -i -e '/^AndroidVersion.CodeName=\s*$$/d' $@
endef

$(sys_img_props) : $(HOST_OUT)/development/sys-img-$(TARGET_CPU_ABI)/%_source.properties : $(TOPDIR)development/sys-img/%_source.prop_template
	$(process_prop_template)

$(sdk_props) : $(HOST_OUT)/development/sdk/%_source.properties : $(TOPDIR)development/sdk/%_source.prop_template
	$(process_prop_template)

$(sample_props) : $(HOST_OUT)/development/samples/%_source.properties : $(TOPDIR)development/samples/%_source.prop_template
	$(process_prop_template)

# ===== SDK jar file of stubs =====
# A.k.a the "current" version of the public SDK (android.jar inside the SDK package).
full_target := $(call intermediates-dir-for,JAVA_LIBRARIES,android_stubs_current,,COMMON)/classes.jar
full_src_target := $(call intermediates-dir-for,ETC,frameworks-base-api-current.srcjar)/frameworks-base-api-current.srcjar

# android.jar is what we put in the SDK package.
android_jar_intermediates := $(call intermediates-dir-for,PACKAGING,android_jar,,COMMON)
android_jar_full_target := $(android_jar_intermediates)/android.jar
android_jar_src_target := $(android_jar_intermediates)/android-stubs-src.jar

# unzip and zip android.jar before packaging it. (workaround for b/127733650)
full_target_repackaged := $(android_jar_intermediates)/repackaged/repackaged.jar
$(full_target_repackaged): $(full_target) | $(ZIPTIME)
	@echo Repackaging SDK jar: $@
	$(hide) rm -rf $(dir $@) && mkdir -p $(dir $@)
	unzip -q $< -d $(dir $@)
	cd $(dir $@) && zip -rqX $(notdir $@) *
	$(remove-timestamps-from-package)

$(android_jar_full_target): $(full_target_repackaged)
	@echo Package SDK Stubs: $@
	$(copy-file-to-target)

$(android_jar_src_target): $(full_src_target)
	@echo Package SDK Stubs Source: $@
	$(hide)mkdir -p $(dir $@)
	$(hide)$(ACP) $< $@

ALL_SDK_FILES += $(android_jar_full_target)
ALL_SDK_FILES += $(android_jar_src_target)

# ===== SDK for system modules =====
# A subset of the public SDK to convert to system modules for use with javac -source 9 -target 9
ALL_SDK_FILES += $(call intermediates-dir-for,JAVA_LIBRARIES,core-current-stubs-for-system-modules,,COMMON)/classes.jar

# ====================================================

# The uiautomator stubs
ALL_SDK_FILES += $(TARGET_OUT_COMMON_INTERMEDIATES)/JAVA_LIBRARIES/android_uiautomator_intermediates/classes.jar

# org.apache.http.legacy.jar stubs
ALL_SDK_FILES += $(TARGET_OUT_COMMON_INTERMEDIATES)/JAVA_LIBRARIES/org.apache.http.legacy.stubs_intermediates/classes.jar

# Android Automotive OS stubs
ALL_SDK_FILES += $(OUT_DIR)/target/common/obj/JAVA_LIBRARIES/android.car-stubs_intermediates/classes.jar

# test stubs
ALL_SDK_FILES += $(TARGET_OUT_COMMON_INTERMEDIATES)/JAVA_LIBRARIES/android.test.mock.stubs_intermediates/classes.jar
ALL_SDK_FILES += $(TARGET_OUT_COMMON_INTERMEDIATES)/JAVA_LIBRARIES/android.test.base.stubs_intermediates/classes.jar
ALL_SDK_FILES += $(TARGET_OUT_COMMON_INTERMEDIATES)/JAVA_LIBRARIES/android.test.runner.stubs_intermediates/classes.jar

# core-lambda-stubs
ALL_SDK_FILES += $(TARGET_OUT_COMMON_INTERMEDIATES)/JAVA_LIBRARIES/core-lambda-stubs_intermediates/classes.jar

# ======= Lint API XML ===========
full_target := $(TARGET_OUT_COMMON_INTERMEDIATES)/PACKAGING/framework-doc-stubs_generated-api-versions.xml
ALL_SDK_FILES += $(full_target)
$(call dist-for-goals,sdk win_sdk,$(full_target):data/api-versions.xml)

# ======= Lint Annotations zip ===========
full_target := $(TARGET_OUT_COMMON_INTERMEDIATES)/PACKAGING/framework-doc-stubs_annotations.zip
ALL_SDK_FILES += $(full_target)
$(call dist-for-goals,sdk win_sdk,$(full_target):data/annotations.zip)

# ======= Lint system API XML ===========
full_target := $(TARGET_OUT_COMMON_INTERMEDIATES)/PACKAGING/framework-doc-system-stubs_generated-api-versions.xml
$(call dist-for-goals,sdk win_sdk,$(full_target):system-data/api-versions.xml)

# ======= Lint system Annotations zip ===========
full_target := $(TARGET_OUT_COMMON_INTERMEDIATES)/PACKAGING/framework-doc-system-stubs_annotations.zip
$(call dist-for-goals,sdk win_sdk,$(full_target):system-data/annotations.zip)

# ============ SDK AIDL ============
$(eval $(call copy-one-file,$(FRAMEWORK_AIDL),$(TARGET_OUT_COMMON_INTERMEDIATES)/PACKAGING/framework.aidl))
ALL_SDK_FILES += $(TARGET_OUT_COMMON_INTERMEDIATES)/PACKAGING/framework.aidl
