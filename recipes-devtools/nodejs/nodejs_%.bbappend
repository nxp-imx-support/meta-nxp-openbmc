# OpenBMC wrynose requires C++20. Override the default C++17 flag set by the
# nodejs recipe to use gnu++20 for native builds.
# Compatible with all Ubuntu build hosts:
#   Ubuntu 20.04 (gcc-10): supports gnu++20 with explicit flag
#   Ubuntu 22.04 (gcc-11): supports gnu++20 natively
#   Ubuntu 24.04 (gcc-13): supports gnu++20 natively
BUILD_CXXFLAGS:remove = "-std=c++17"
BUILD_CXXFLAGS:append = " -std=gnu++20"

EXTRA_OEMAKE:append:class-native = " \
    CFLAGS_CC.host='${BUILD_CXXFLAGS}' \
    CXXFLAGS.host='${BUILD_CXXFLAGS}' \
"

# Node.js V8 compilation is extremely memory-hungry (each cc1plus instance
# can use 2-4GB RAM). Limit parallel jobs to avoid OOM kills on build hosts.
PARALLEL_MAKE:class-native = "-j 4"

