cmake_minimum_required(VERSION 3.5.0)
project(clash_ohos)

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

if(DEFINED PACKAGE_FIND_FILE)
    include(${PACKAGE_FIND_FILE})
endif()

include_directories(${NATIVERENDER_ROOT_PATH})

set(CMAKE_CXX_STANDARD 17)

# Tiny NAPI shell only. VpnExtension can dlopen this; the Go archive is
# too large / constructor-heavy to be the ArkTS native module.
add_library(clash_ohos SHARED napi_init.cpp clash_adapter.cpp)

find_library(hilog-lib hilog_ndk.z)
find_library(ace-lib ace_napi.z)
find_library(dl-lib dl)

if(NOT DEFINED OHOS_ARCH OR OHOS_ARCH STREQUAL "")
    set(OHOS_ARCH "arm64-v8a")
endif()
set(CLASH_A "${CMAKE_CURRENT_SOURCE_DIR}/prebuilt/${OHOS_ARCH}/libclash.a")

add_library(clash_core SHARED clash_core_marker.cpp)
if(EXISTS "${CLASH_A}")
    message(STATUS "Statically linking ${CLASH_A} into clash_core")
    target_link_libraries(clash_core PUBLIC
        "-Wl,--whole-archive"
        "${CLASH_A}"
        "-Wl,--no-whole-archive")
else()
    message(WARNING "libclash.a not found at ${CLASH_A}")
endif()
target_link_libraries(clash_core PUBLIC ${hilog-lib} ${dl-lib})

target_link_libraries(clash_ohos PUBLIC ${hilog-lib} ${ace-lib} ${dl-lib})
