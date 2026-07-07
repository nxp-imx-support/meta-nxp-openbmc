require optee-client-imx.inc

SRCBRANCH = "lf-6.18.2_1.0.0"
SRC_URI = "${OPTEE_CLIENT_SRC};branch=${SRCBRANCH};name=client"
SRCREV_client = "ad79099ca6b642f2bb69739f020ea50698ea0744"
SRCREV_FORMAT = "client"
