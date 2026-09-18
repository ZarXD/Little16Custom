FINALPACKAGE = 1
ARCHS = arm64 arm64e
THEOS_PACKAGE_SCHEME = rootless
TARGET = iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Little16
Little16_FILES = Tweak.xm
Little16_CFLAGS = -fobjc-arc -Wno-deprecated-declarations

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += Little16Prefs
include $(THEOS_MAKE_PATH)/aggregate.mk