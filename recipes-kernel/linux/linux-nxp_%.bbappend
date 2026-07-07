
do_install:prepend() {
    install -d ${D}/boot || true

    # Handle NXP's DTB directory pattern derived from KERNEL_DEVICETREE
    dtb="${KERNEL_DEVICETREE}"

    # Remove slashes and .dtb so it matches the directory NXP uses
    dtbdir="$(echo $dtb | sed 's/\.dtb$//' | sed 's/\//./g' | awk -F',' '{print $1}')"

    if [ -n "$dtbdir" ]; then
        install -d ${D}/boot/$dtbdir || true
    fi
}
