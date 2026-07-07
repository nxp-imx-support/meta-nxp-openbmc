DEPENDS:append:class-native = " libyaml-native"

EXTRA_OEMAKE:append:class-native = " HOSTLDLIBS_dtc=' -lyaml'"
