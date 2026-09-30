FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

# Workaround for uboot-config.bbclass
do_configure:prepend() {
    uboot_config_get_indexed_value() {
        if [ "$1" = "?" ] || [ "$1" = " ? " ] || [ -z "$1" ]; then
            echo ""
            return 0
        fi

        local list="$1"
        local index="$2"
        local k=0

        IFS='?'
        for value in $list; do
            k=$(expr $k + 1)
            if [ "$k" -eq "$index" ]; then
                break
            fi
        done
        unset IFS

        echo "$value"
    }
}

do_compile:prepend() {
    uboot_config_get_indexed_value() {
        if [ "$1" = "?" ] || [ "$1" = " ? " ] || [ -z "$1" ]; then
            echo ""
            return 0
        fi

        local list="$1"
        local index="$2"
        local k=0

        IFS='?'
        for value in $list; do
            k=$(expr $k + 1)
            if [ "$k" -eq "$index" ]; then
                break
            fi
        done
        unset IFS

        echo "$value"
    }
}

do_uboot_assemble_fitimage:prepend() {
    uboot_config_get_indexed_value() {
        if [ "$1" = "?" ] || [ "$1" = " ? " ] || [ -z "$1" ]; then
            echo ""
            return 0
        fi

        local list="$1"
        local index="$2"
        local k=0

        IFS='?'
        for value in $list; do
            k=$(expr $k + 1)
            if [ "$k" -eq "$index" ]; then
                break
            fi
        done
        unset IFS

        echo "$value"
    }
}
