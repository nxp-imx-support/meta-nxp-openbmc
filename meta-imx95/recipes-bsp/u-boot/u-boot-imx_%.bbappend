#Look in our local files/ dir first
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# Name of the env file (without suffix)
UBOOT_ENV = "custom-bmc-env"

UBOOT_CONFIG_FRAGMENTS:sd += "defconfig-fragment.cfg"

# Stage the text env file into WORKDIR during do_fetch/do_unpack
SRC_URI += " file://custom-bmc-env.cmd"
SRC_URI += " file://defconfig-fragment.cfg"

# Ensure u-boot's env handling is active (harmless if base recipe already does this)
inherit uboot-config

# Custom task to copy into the build directory after unpack
do_copy_custom_env() {
  # Make sure the build dir exists
  install -d ${B}

  src="${UNPACKDIR}/custom-bmc-env.cmd"
  if [ ! -f "${src}" ]; then
        bbfatal "custom-bmc-env.cmd not found in UNPACKDIR (${UNPACKDIR}). Check FILESPATH/SRC_URI."
  fi

  install -m 0644 "${src}" "${B}/custom-bmc-env.cmd"
}

# Register the task to run after unpack and before configure
addtask copy_custom_env after do_unpack before do_configure

# Also deploy the file as part of do_deploy
do_deploy:append() {
  install -d ${DEPLOYDIR}
  install -m 0644 ${B}/custom-bmc-env.cmd ${DEPLOYDIR}/custom-bmc-env.cmd
}

# -----------------------------------------------------------------
# NOR flash (fspi) overrides for evb-imx95-evk-nor machine
# -----------------------------------------------------------------
FILESEXTRAPATHS:prepend:evb-imx95-evk-nor := "${THISDIR}/files:"

# Use the NOR-specific boot environment when building for NOR
UBOOT_ENV:evb-imx95-evk-nor = "custom-bmc-env-nor"

# Stage the NOR env file and FlexSPI defconfig fragment
SRC_URI:append:evb-imx95-evk-nor = " file://fspi/custom-bmc-env-nor.cmd"
SRC_URI:append:evb-imx95-evk-nor = " file://fspi/defconfig-fragment.cfg"

UBOOT_CONFIG_FRAGMENTS:fspi += "defconfig-fragment.cfg"

# Copy the NOR env into the build directory after unpack
do_copy_custom_env:append:evb-imx95-evk-nor() {
  src="${UNPACKDIR}/fspi/custom-bmc-env-nor.cmd"
  if [ -f "${src}" ]; then
    install -m 0644 "${src}" "${B}/custom-bmc-env-nor.cmd"
    install -m 0644 "${src}" "${UNPACKDIR}/custom-bmc-env-nor.cmd"
  fi
}
