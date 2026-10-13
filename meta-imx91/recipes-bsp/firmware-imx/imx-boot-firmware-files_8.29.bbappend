# Allow this firmware provider to build for our machine
COMPATIBLE_MACHINE:append = "|frdm-imx91"

# Make sure the mx9 deploy function runs (so DDR blobs get deployed)
DEPLOY_FOR:append:frdm-imx91 = " mx9"
