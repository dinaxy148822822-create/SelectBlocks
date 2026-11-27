PACKAGE_VARIANT ?= rootless
ifeq ($(PACKAGE_VARIANT),rootless)
ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless
else ifeq ($(PACKAGE_VARIANT),rootful)
ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0
THEOS_PACKAGE_SCHEME =
else ifeq ($(PACKAGE_VARIANT),rootful-legacy)
ARCHS = arm64
TARGET = iphone:clang:latest:12.0
THEOS_PACKAGE_SCHEME =
else
$(error Unknown PACKAGE_VARIANT; use rootless, rootful or rootful-legacy)
endif
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = SelectBlocks
SelectBlocks_FILES = Tweak.xm
SelectBlocks_CFLAGS = -fobjc-arc
SelectBlocks_FRAMEWORKS = UIKit Foundation WebKit AudioToolbox
include $(THEOS_MAKE_PATH)/tweak.mk
