"""Run Lua 5.4 regression tests with the installed shared library (no FiveM required)."""
import ctypes
import ctypes.util
import pathlib
import os
import sys

os.chdir(pathlib.Path(__file__).resolve().parents[1])
lua = ctypes.CDLL(ctypes.util.find_library('lua5.4'))
lua.luaL_newstate.restype = ctypes.c_void_p
lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
lua.luaL_loadfilex.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p]
lua.lua_pcallk.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_longlong, ctypes.c_void_p]
lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
lua.lua_tolstring.restype = ctypes.c_char_p
lua.lua_close.argtypes = [ctypes.c_void_p]
for path in sorted(pathlib.Path('tests').glob('*_spec.lua')):
    state = lua.luaL_newstate()
    lua.luaL_openlibs(state)
    code = lua.luaL_loadfilex(state, str(path).encode(), None)
    if not code:
        code = lua.lua_pcallk(state, 0, -1, 0, 0, None)
    if code:
        print(lua.lua_tolstring(state, -1, None).decode(), file=sys.stderr)
        sys.exit(1)
    lua.lua_close(state)
    print('PASS', path)
