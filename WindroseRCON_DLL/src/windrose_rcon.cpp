/*
 * WindroseRCON networking DLL for UE4SS Lua
 *
 * Exposes a minimal TCP socket API to Lua so the RCON server can run inside
 * the game process without any external process.
 *
 * Build with Visual Studio or MinGW as a DLL named windrose_rcon.dll.
 * Place the DLL next to the mod's Lua scripts (WindroseRCON/Scripts/).
 */

#define WIN32_LEAN_AND_MEAN
#define FD_SETSIZE 1024
#include <windows.h>
#include <winsock2.h>
#include <ws2tcpip.h>
#include <string.h>
#include <stdio.h>

extern "C" {
#include "lua.h"
#include "lauxlib.h"
}

#pragma comment(lib, "ws2_32.lib")

#define WRC_VERSION "1.0.0"

static SOCKET checksocket(lua_State* L, int idx) {
    lua_Integer value = luaL_checkinteger(L, idx);
    return (SOCKET)value;
}

static void pushsocket(lua_State* L, SOCKET s) {
    lua_pushinteger(L, (lua_Integer)s);
}

static int wrc_init(lua_State* L) {
    WSADATA wsaData;
    int result = WSAStartup(MAKEWORD(2, 2), &wsaData);
    if (result != 0) {
        lua_pushnil(L);
        lua_pushstring(L, "WSAStartup failed");
        return 2;
    }
    lua_pushboolean(L, 1);
    return 1;
}

static int wrc_cleanup(lua_State* L) {
    WSACleanup();
    return 0;
}

static int wrc_connect(lua_State* L) {
    const char* host = luaL_checkstring(L, 1);
    int port = (int)luaL_checkinteger(L, 2);
    int timeout_ms = (int)luaL_optinteger(L, 3, 5000);

    SOCKET s = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (s == INVALID_SOCKET) {
        lua_pushnil(L);
        lua_pushstring(L, "socket creation failed");
        return 2;
    }

    sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons((u_short)port);
    if (inet_pton(AF_INET, host, &addr.sin_addr) != 1) {
        closesocket(s);
        lua_pushnil(L);
        lua_pushstring(L, "invalid address");
        return 2;
    }

    u_long nonblocking = 1;
    ioctlsocket(s, FIONBIO, &nonblocking);

    int result = connect(s, (sockaddr*)&addr, sizeof(addr));
    if (result == SOCKET_ERROR) {
        int err = WSAGetLastError();
        if (err != WSAEWOULDBLOCK) {
            closesocket(s);
            lua_pushnil(L);
            lua_pushstring(L, "connect failed");
            return 2;
        }
    }

    fd_set writefds;
    FD_ZERO(&writefds);
    FD_SET(s, &writefds);
    timeval tv;
    tv.tv_sec = timeout_ms / 1000;
    tv.tv_usec = (timeout_ms % 1000) * 1000;

    int ready = select(0, NULL, &writefds, NULL, &tv);
    if (ready <= 0 || !FD_ISSET(s, &writefds)) {
        closesocket(s);
        lua_pushnil(L);
        lua_pushstring(L, "connect timeout");
        return 2;
    }

    pushsocket(L, s);
    return 1;
}

static int wrc_bind(lua_State* L) {
    const char* host = luaL_checkstring(L, 1);
    int port = (int)luaL_checkinteger(L, 2);

    SOCKET s = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (s == INVALID_SOCKET) {
        lua_pushnil(L);
        lua_pushstring(L, "socket creation failed");
        return 2;
    }

    int reuse = 1;
    setsockopt(s, SOL_SOCKET, SO_REUSEADDR, (const char*)&reuse, sizeof(reuse));

    sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons((u_short)port);
    if (inet_pton(AF_INET, host, &addr.sin_addr) != 1) {
        closesocket(s);
        lua_pushnil(L);
        lua_pushstring(L, "invalid bind address");
        return 2;
    }

    if (bind(s, (sockaddr*)&addr, sizeof(addr)) == SOCKET_ERROR) {
        closesocket(s);
        lua_pushnil(L);
        lua_pushstring(L, "bind failed");
        return 2;
    }

    if (listen(s, SOMAXCONN) == SOCKET_ERROR) {
        closesocket(s);
        lua_pushnil(L);
        lua_pushstring(L, "listen failed");
        return 2;
    }

    u_long nonblocking = 1;
    ioctlsocket(s, FIONBIO, &nonblocking);

    pushsocket(L, s);
    return 1;
}

static int wrc_accept(lua_State* L) {
    SOCKET server = checksocket(L, 1);
    int timeout_ms = (int)luaL_optinteger(L, 2, 1000);

    fd_set readfds;
    FD_ZERO(&readfds);
    FD_SET(server, &readfds);

    timeval tv;
    tv.tv_sec = timeout_ms / 1000;
    tv.tv_usec = (timeout_ms % 1000) * 1000;

    int ready = select(0, &readfds, NULL, NULL, &tv);
    if (ready <= 0) {
        lua_pushnil(L);
        lua_pushstring(L, "timeout");
        return 2;
    }

    SOCKET client = accept(server, NULL, NULL);
    if (client == INVALID_SOCKET) {
        lua_pushnil(L);
        lua_pushstring(L, "accept failed");
        return 2;
    }

    u_long nonblocking = 1;
    ioctlsocket(client, FIONBIO, &nonblocking);

    pushsocket(L, client);
    return 1;
}

static int wrc_receive(lua_State* L) {
    SOCKET s = checksocket(L, 1);
    int max_len = (int)luaL_optinteger(L, 2, 4096);
    if (max_len <= 0 || max_len > 65536) max_len = 65536;

    char* buffer = new char[max_len];
    int received = recv(s, buffer, max_len, 0);

    if (received == SOCKET_ERROR) {
        int err = WSAGetLastError();
        delete[] buffer;
        if (err == WSAEWOULDBLOCK) {
            lua_pushnil(L);
            lua_pushstring(L, "wouldblock");
        } else {
            lua_pushnil(L);
            lua_pushstring(L, "recv failed");
        }
        return 2;
    }

    if (received == 0) {
        delete[] buffer;
        lua_pushnil(L);
        lua_pushstring(L, "disconnected");
        return 2;
    }

    lua_pushlstring(L, buffer, received);
    delete[] buffer;
    return 1;
}

static int wrc_send(lua_State* L) {
    SOCKET s = checksocket(L, 1);
    size_t len;
    const char* data = luaL_checklstring(L, 2, &len);

    int sent = ::send(s, data, (int)len, 0);
    if (sent == SOCKET_ERROR) {
        lua_pushnil(L);
        lua_pushstring(L, "send failed");
        return 2;
    }

    lua_pushinteger(L, sent);
    return 1;
}

static int wrc_close(lua_State* L) {
    SOCKET s = checksocket(L, 1);
    closesocket(s);
    lua_pushboolean(L, 1);
    return 1;
}

static int wrc_select(lua_State* L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    int timeout_ms = (int)luaL_optinteger(L, 2, 1000);

    fd_set readfds;
    FD_ZERO(&readfds);
    SOCKET max_fd = 0;

    int n = (int)luaL_len(L, 1);
    for (int i = 1; i <= n; ++i) {
        lua_rawgeti(L, 1, i);
        SOCKET s = (SOCKET)luaL_checkinteger(L, -1);
        lua_pop(L, 1);
        FD_SET(s, &readfds);
        if (s > max_fd) max_fd = s;
    }

    timeval tv;
    tv.tv_sec = timeout_ms / 1000;
    tv.tv_usec = (timeout_ms % 1000) * 1000;

    int ready = select((int)max_fd + 1, &readfds, NULL, NULL, &tv);
    if (ready <= 0) {
        lua_pushnil(L);
        return 1;
    }

    lua_newtable(L);
    int out_idx = 1;
    for (int i = 1; i <= n; ++i) {
        lua_rawgeti(L, 1, i);
        SOCKET s = (SOCKET)luaL_checkinteger(L, -1);
        if (FD_ISSET(s, &readfds)) {
            lua_pushinteger(L, out_idx);
            lua_pushvalue(L, -2);
            lua_settable(L, -4);
            out_idx++;
        }
        lua_pop(L, 1);
    }
    return 1;
}

static int wrc_getsockname(lua_State* L) {
    SOCKET s = checksocket(L, 1);
    sockaddr_in addr;
    int len = sizeof(addr);
    if (getsockname(s, (sockaddr*)&addr, &len) != 0) {
        lua_pushnil(L);
        return 1;
    }
    char ip[16];
    inet_ntop(AF_INET, &addr.sin_addr, ip, sizeof(ip));
    lua_pushstring(L, ip);
    lua_pushinteger(L, ntohs(addr.sin_port));
    return 2;
}

static const luaL_Reg windrose_rcon_lib[] = {
    { "init", wrc_init },
    { "cleanup", wrc_cleanup },
    { "connect", wrc_connect },
    { "bind", wrc_bind },
    { "accept", wrc_accept },
    { "receive", wrc_receive },
    { "send", wrc_send },
    { "close", wrc_close },
    { "select", wrc_select },
    { "getsockname", wrc_getsockname },
    { NULL, NULL }
};

extern "C" __declspec(dllexport) int luaopen_windrose_rcon(lua_State* L) {
    luaL_newlib(L, windrose_rcon_lib);
    lua_pushstring(L, WRC_VERSION);
    lua_setfield(L, -2, "version");
    return 1;
}

BOOL APIENTRY DllMain(HMODULE hModule, DWORD ul_reason_for_call, LPVOID lpReserved) {
    return TRUE;
}
