ARCHS = arm64
TARGET = iphone:clang:latest:16.0
THEOS_PACKAGE_SCHEME = rootless
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = SelectBlocks
SelectBlocks_FILES = Tweak.xm
SelectBlocks_CFLAGS = -fobjc-arc
SelectBlocks_FRAMEWORKS = UIKit Foundation WebKit AudioToolbox
include $(THEOS_MAKE_PATH)/tweak.mk
