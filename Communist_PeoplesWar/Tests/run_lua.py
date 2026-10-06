"""Run focused gameplay mocks with the system Lua 5.4 shared library."""
import ctypes,ctypes.util
lib=ctypes.CDLL(ctypes.util.find_library('lua5.4'))
lib.luaL_newstate.restype=ctypes.c_void_p
lib.luaL_openlibs.argtypes=[ctypes.c_void_p]
lib.luaL_loadfilex.argtypes=[ctypes.c_void_p,ctypes.c_char_p,ctypes.c_char_p]
lib.lua_pcallk.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_longlong,ctypes.c_void_p]
lib.lua_tolstring.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.POINTER(ctypes.c_size_t)];lib.lua_tolstring.restype=ctypes.c_char_p
lib.lua_close.argtypes=[ctypes.c_void_p]
state=lib.luaL_newstate();lib.luaL_openlibs(state)
result=lib.luaL_loadfilex(state,b'Communist_PeoplesWar/Tests/pillage_cases.lua',None)
if not result:result=lib.lua_pcallk(state,0,-1,0,0,None)
if result:raise RuntimeError(lib.lua_tolstring(state,-1,None).decode())
lib.lua_close(state)
