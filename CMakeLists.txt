cmake_minimum_required(VERSION 3.20)

# Do not allow building in root
if (CMAKE_BINARY_DIR STREQUAL CMAKE_SOURCE_DIR)
    message(FATAL_ERROR "Do not build in the root. Create a bin directory and remove ${CMAKE_SOURCE_DIR}/CMakeCache.txt")
endif ()

project(keeperfx C CXX)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 20)

include(FetchContent)

# Dependencies
find_package(SDL2 CONFIG REQUIRED)
find_package(SDL2_image CONFIG REQUIRED)
find_package(SDL2_mixer CONFIG REQUIRED)
find_package(SDL2_net CONFIG REQUIRED)
find_package(unofficial-enet CONFIG REQUIRED)
find_package(SPNG CONFIG REQUIRED)
find_package(FFMPEG REQUIRED)
find_package(PkgConfig REQUIRED)
pkg_check_modules(LUAJIT REQUIRED luajit IMPORTED_TARGET)
find_package(minizip CONFIG REQUIRED)
find_package(OpenAL CONFIG REQUIRED)

# Fetch CentiJSON
FetchContent_Declare(
    centijson
    GIT_REPOSITORY https://github.com/mity/centijson.git
    GIT_TAG master
)
FetchContent_MakeAvailable(centijson)

# Fetch Astronomy
FetchContent_Declare(
    astronomy
    GIT_REPOSITORY https://github.com/cosinekitty/astronomy.git
    GIT_TAG master
)
FetchContent_GetProperties(astronomy)
if(NOT astronomy_POPULATED)
    FetchContent_Populate(astronomy)
    add_library(astronomy STATIC "${astronomy_SOURCE_DIR}/source/c/astronomy.c")
    target_include_directories(astronomy PUBLIC "${astronomy_SOURCE_DIR}/source/c")
endif()

# Version info
find_package(Git REQUIRED)
execute_process(COMMAND "${GIT_EXECUTABLE}" describe --always OUTPUT_VARIABLE COMMIT_ID OUTPUT_STRIP_TRAILING_WHITESPACE)

set(VER_MAJOR       1)
set(VER_MINOR       2)
set(VER_RELEASE     0)
set(VER_BUILD       0)
set(VER_STRING      "${VER_MAJOR}.${VER_MINOR}.${VER_RELEASE}.${VER_BUILD} ${PACKAGE_SUFFIX}")
set(PACKAGE_SUFFIX  "")
set(GIT_REVISION    "${COMMIT_ID}")

set(KEEPERFX_VER_DEFS_H_IN ${CMAKE_SOURCE_DIR}/ver_defs.h.in)
set(KEEPERFX_VER_DEFS_H_OUT ${CMAKE_SOURCE_DIR}/ver_defs.h)
configure_file(${KEEPERFX_VER_DEFS_H_IN} ${KEEPERFX_VER_DEFS_H_OUT})

# Sources
file(GLOB_RECURSE KEEPERFX_SOURCES_C "src/*.c")
file(GLOB_RECURSE KEEPERFX_SOURCES_CXX "src/*.cpp")

# Exclude platform specific files
if(WIN32)
    list(FILTER KEEPERFX_SOURCES_CXX EXCLUDE REGEX "src/linux.cpp")
else()
    # Unix/MacOS
    list(FILTER KEEPERFX_SOURCES_C EXCLUDE REGEX "src/bflib_crash.c")
    list(FILTER KEEPERFX_SOURCES_CXX EXCLUDE REGEX "src/windows.cpp")
    list(FILTER KEEPERFX_SOURCES_CXX EXCLUDE REGEX "src/cdrom.cpp")
    list(FILTER KEEPERFX_SOURCES_CXX EXCLUDE REGEX "src/steam_api.cpp")
endif()

# Global definitions
add_compile_definitions("DEBUG=$<IF:$<CONFIG:Debug>,1,0>")
add_compile_definitions("SPNG_STATIC=1")

# CentiTOML (internal dep)
add_library(centitoml OBJECT "deps/centitoml/toml_api.c")
target_include_directories(centitoml PUBLIC "deps/centitoml")
# centijson target is named 'json'
target_link_libraries(centitoml PUBLIC json)
target_include_directories(centitoml PUBLIC "${centijson_SOURCE_DIR}/src")

# Executable: keeperfx
add_executable(keeperfx ${KEEPERFX_SOURCES_C} ${KEEPERFX_SOURCES_CXX})
target_compile_definitions(keeperfx PUBLIC BFDEBUG_LEVEL=0)
target_sources(keeperfx PRIVATE "res/keeperfx_stdres.rc")
if(NOT WIN32)
    set_source_files_properties("res/keeperfx_stdres.rc" PROPERTIES HEADER_FILE_ONLY TRUE)
endif()

# Executable: keeperfx_hvlog
add_executable(keeperfx_hvlog ${KEEPERFX_SOURCES_C} ${KEEPERFX_SOURCES_CXX})
target_compile_definitions(keeperfx_hvlog PUBLIC BFDEBUG_LEVEL=10)
target_sources(keeperfx_hvlog PRIVATE "res/keeperfx_stdres.rc")
if(NOT WIN32)
    set_source_files_properties("res/keeperfx_stdres.rc" PROPERTIES HEADER_FILE_ONLY TRUE)
endif()


# Link libraries
foreach(TARGET keeperfx keeperfx_hvlog)
    target_link_libraries(${TARGET} PUBLIC
        $<IF:$<TARGET_EXISTS:SDL2::SDL2>,SDL2::SDL2,SDL2::SDL2-static>
        $<IF:$<TARGET_EXISTS:SDL2_image::SDL2_image>,SDL2_image::SDL2_image,SDL2_image::SDL2_image-static>
        $<IF:$<TARGET_EXISTS:SDL2_mixer::SDL2_mixer>,SDL2_mixer::SDL2_mixer,SDL2_mixer::SDL2_mixer-static>
        $<IF:$<TARGET_EXISTS:SDL2_net::SDL2_net>,SDL2_net::SDL2_net,SDL2_net::SDL2_net-static>
        unofficial::enet::enet
        $<IF:$<TARGET_EXISTS:spng::spng>,spng::spng,spng::spng_static>
        PkgConfig::LUAJIT
        minizip::minizip
        OpenAL::OpenAL
        json
        astronomy
        centitoml
        ${FFMPEG_LIBRARIES}
    )
    # Add includes for centijson (json) as it doesn't export them
    target_include_directories(${TARGET} PUBLIC "${centijson_SOURCE_DIR}/src")
    target_include_directories(${TARGET} PUBLIC ${FFMPEG_INCLUDE_DIRS})
    target_include_directories(${TARGET} PUBLIC ${LUAJIT_INCLUDE_DIRS})
    target_include_directories(${TARGET} PUBLIC ${CMAKE_SOURCE_DIR})
    
    if(WIN32)
         target_link_libraries(${TARGET} PRIVATE imagehlp dbghelp)
         target_link_options(${TARGET} PRIVATE -mwindows -Wl,--enable-auto-import)
    else()
         target_link_libraries(${TARGET} PRIVATE m pthread)
    endif()
endforeach()