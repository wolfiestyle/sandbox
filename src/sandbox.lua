--- Small library for running Lua code in a sandbox.
--
-- @module sandbox
-- @author darkstalker <https://github.com/darkstalker>
-- @license MIT/X11
local assert, error, getmetatable, loadstring, pairs, pcall, select, setfenv, setmetatable, table_concat, type =
      assert, error, getmetatable, loadstring, pairs, pcall, select, setfenv, setmetatable, table.concat, type

local table_pack = table.pack or function(...) return { n = select("#", ...), ... } end
local table_unpack = table.unpack or unpack

local has_52_compatible_load = _VERSION ~= "Lua 5.1" or tostring(assert):match "builtin"
local load = has_52_compatible_load and load or function(code, name, mode, env)
    --mode = mode or "bt"
    if code:byte(1) == 27 --[[and not mode:match "b"]] then return nil, "can't load binary chunk" end
    local chunk, err = loadstring(code, name)
    if chunk and env then setfenv(chunk, env) end
    return chunk, err
end

local function pack_1(first, ...) return first, table_pack(...) end

local _M = {}

-- Builds the environment table for a sandbox.
local function build_env(src_env, dest_env, whitelist)
    dest_env = dest_env or {}
    assert(getmetatable(dest_env) == nil, "env has a metatable")

    local env = {}
    for name in whitelist:gmatch "%S+" do
        local t_name, field = name:match "^([^%.]+)%.([^%.]+)$"
        if t_name then
            local tbl = env[t_name]
            local env_t = src_env[t_name]
            if tbl == nil and env_t then
                tbl = {}
                env[t_name] = tbl
            end
            if env_t then
                local t_tbl = type(tbl)
                if t_tbl ~= "table" then
                    error("field '".. t_name .. "' already added as " .. t_tbl)
                end
                tbl[field] = env_t[field]
            end
        else
            local val = src_env[name]
            assert(type(val) ~= "table", "can't copy table reference")
            env[name] = val
        end
    end

    env._G = dest_env

    return setmetatable(dest_env, { __index = env })
end

--- List of safe library methods (5.1 to 5.3)
_M.whitelist = [[
_VERSION assert error ipairs next pairs pcall select tonumber tostring type unpack xpcall

bit32.arshift bit32.band bit32.bnot bit32.bor bit32.btest bit32.bxor bit32.extract bit32.lrotate
bit32.lshift bit32.replace bit32.rrotate bit32.rshift

coroutine.create coroutine.isyieldable coroutine.resume coroutine.running coroutine.status
coroutine.wrap coroutine.yield

math.abs math.acos math.asin math.atan math.atan2 math.ceil math.cos math.cosh math.deg math.exp
math.floor math.fmod math.frexp math.huge math.ldexp math.log math.log10 math.max math.maxinteger
math.min math.mininteger math.mod math.modf math.pi math.pow math.rad math.random math.sin
math.sinh math.sqrt math.tan math.tanh math.tointeger math.type math.ult

os.clock os.difftime os.time

string.byte string.char string.find string.format string.gmatch string.gsub string.len string.lower
string.match string.pack string.packsize string.rep string.reverse string.sub string.unpack
string.upper

table.concat table.insert table.maxn table.pack table.remove table.sort table.unpack

utf8.char utf8.charpattern utf8.codepoint utf8.codes utf8.len utf8.offset
]]

--- Executes Lua code in a sandbox.
--
-- @param code      Lua source code string.
-- @param name      Name of the chunk (for errors, default "sandbox").
-- @param env       Table used as environment (default a new empty table).
-- @param whitelist String with a list of library functions imported from the global namespace (default `sandbox.whitelist`).
-- @return          The `env` where the code was ran, or `nil` in case of error.
-- @return          The chunk return values, or an error message.
function _M.eval(code, name, env, whitelist)
    assert(type(code) == "string", "code must be a string")
    env = build_env(_G or _ENV, env, whitelist or _M.whitelist)
    local fn, err = load(code, name or "sandbox", "t", env)
    if fn == nil then
        return nil, err
    end
    local ok, ret = pack_1(pcall(fn))
    if not ok then
        return nil, ret[1]
    end
    return env, table_unpack(ret, 1, ret.n)
end

return _M
