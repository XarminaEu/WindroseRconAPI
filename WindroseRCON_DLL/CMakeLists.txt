cmake_minimum_required(VERSION 3.20)
project(WindroseRCON_DLL C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

set(LUA_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/deps/lua-5.4.7)

set(LUA_CORE_SOURCES
    ${LUA_ROOT}/lapi.c
    ${LUA_ROOT}/lauxlib.c
    ${LUA_ROOT}/lbaselib.c
    ${LUA_ROOT}/lcode.c
    ${LUA_ROOT}/lcorolib.c
    ${LUA_ROOT}/lctype.c
    ${LUA_ROOT}/ldblib.c
    ${LUA_ROOT}/ldebug.c
    ${LUA_ROOT}/ldo.c
    ${LUA_ROOT}/ldump.c
    ${LUA_ROOT}/lfunc.c
    ${LUA_ROOT}/lgc.c
    ${LUA_ROOT}/linit.c
    ${LUA_ROOT}/liolib.c
    ${LUA_ROOT}/llex.c
    ${LUA_ROOT}/lmathlib.c
    ${LUA_ROOT}/lmem.c
    ${LUA_ROOT}/loadlib.c
    ${LUA_ROOT}/lobject.c
    ${LUA_ROOT}/lopcodes.c
    ${LUA_ROOT}/loslib.c
    ${LUA_ROOT}/lparser.c
    ${LUA_ROOT}/lstate.c
    ${LUA_ROOT}/lstring.c
    ${LUA_ROOT}/lstrlib.c
    ${LUA_ROOT}/ltable.c
    ${LUA_ROOT}/ltablib.c
    ${LUA_ROOT}/ltm.c
    ${LUA_ROOT}/lundump.c
    ${LUA_ROOT}/lutf8lib.c
    ${LUA_ROOT}/lvm.c
    ${LUA_ROOT}/lzio.c
)

add_library(windrose_rcon SHARED
    src/windrose_rcon.cpp
    ${LUA_CORE_SOURCES}
)

target_include_directories(windrose_rcon PRIVATE
    ${LUA_ROOT}
)

target_compile_definitions(windrose_rcon PRIVATE
    LUA_USE_WINDOWS
)

target_link_libraries(windrose_rcon PRIVATE
    ws2_32
)

set_target_properties(windrose_rcon PROPERTIES
    PREFIX ""
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/../WindroseRCON/Scripts
    RUNTIME_OUTPUT_DIRECTORY_RELEASE ${CMAKE_CURRENT_SOURCE_DIR}/../WindroseRCON/Scripts
    RUNTIME_OUTPUT_DIRECTORY_DEBUG ${CMAKE_CURRENT_SOURCE_DIR}/../WindroseRCON/Scripts
)

# Test executable: minimal Lua interpreter to verify the DLL loads.
add_executable(lua_test
    ${LUA_ROOT}/lua.c
    ${LUA_CORE_SOURCES}
)

target_include_directories(lua_test PRIVATE
    ${LUA_ROOT}
)

target_compile_definitions(lua_test PRIVATE
    LUA_USE_WINDOWS
)
