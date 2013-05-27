#
# Copyright (C) 2012 Y-Find.com
#

include $(TOPDIR)/rules.mk

PKG_NAME:=yscanbox
PKG_VERSION:=1.2
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=ftp://dev.yfound.com/
#PKG_MD5SUM:=f7a24ed8fad122c4187d06bfd6f998b4

PKG_BUILD_PARALLEL:=0
PKG_INSTALL:=1

include $(INCLUDE_DIR)/package.mk

define Package/yscanbox
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=wireless
  DEPENDS:=+libpcap +zeromq
  TITLE:=YFind YScanbox for OpenWRT
  URL:=http://www.y-find.com/
  MAINTAINER:=shoop@y-find.com
endef

define Package/yscanbox/description
YScanbox comprises of YHeartbeat, YScanner and YScanbot.
endef

MAKE_FLAGS += \
	CFLAGS="$(TARGET_CFLAGS) -Wall -Iinclude/ $(TARGET_CPPFLAGS) " \
	LDFLAGS="$(TARGET_LDFLAGS)" \
	OSNAME=Linux \
	prefix="/usr" \
	unstable="true"

define Package/yscanbox/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(CP) $(PKG_INSTALL_DIR)/usr/bin/* $(1)/usr/bin/
endef

$(eval $(call BuildPackage,yscanbox))

