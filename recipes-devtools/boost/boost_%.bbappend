# boost 1.90.0 boost::process::v2 uses std::filesystem which requires C++17.
# gcc-10 (Ubuntu 20.04) defaults to C++14 causing build failure in boost-native:
#   boost/process/v2/detail/config.hpp: error: 'filesystem' is not a namespace-name
# Adding -std=c++17 is safe on all Ubuntu versions (20.04/22.04/24.04):
#   Ubuntu 20.04 (gcc-10): required fix
#   Ubuntu 22.04 (gcc-11): redundant but harmless (already defaults to C++17)
#   Ubuntu 24.04 (gcc-13): redundant but harmless (already defaults to C++17)
# Limit to native class only to avoid affecting AArch64 target builds.
BUILD_CXXFLAGS:append:class-native = " -std=c++17"
