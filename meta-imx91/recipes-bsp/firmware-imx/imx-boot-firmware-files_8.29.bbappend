# Allow this firmware provider to build for our machine
COMPATIBLE_MACHINE:append = "|evb-imx91"

# Make sure the mx9 deploy function runs (so DDR blobs get deployed)
DEPLOY_FOR:append:evb-imx91 = " mx9"
