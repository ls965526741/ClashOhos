// Marker TU so CMake can produce libclash_core.so; Go c-archive is
// --whole-archive linked beside this file. ArkTS never imports this ELF.
extern "C" int clash_core_marker(void)
{
    return 1;
}
