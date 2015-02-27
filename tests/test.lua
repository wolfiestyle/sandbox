#!/usr/bin/env lua
package.path = "../src/?.lua;" .. package.path
local sandbox = require "sandbox"

local code = [[
stuff = 42

function get_secret()
    return secret
end

function get_globals()
    local res = {}
    for k, v in pairs(_G) do
        res[#res + 1] = k .. "=" .. type(v)
    end
    table.sort(res)
    return table.concat(res, " ")
end

function read_file(filename)
    local file = assert(io.open(filename))
    local data = file:read "*a"
    file:close()
    return data
end

function hack(fn)
    local g
    if getfenv then 
        g = getfenv(fn)
    elseif debug and debug.getupvalue then
        local i, n = 1
        repeat
            n, g = debug.getupvalue(fn, i)
            i = i + 1
        until n == "_ENV" or n == nil
    end
    return g and g.secret or nil
end

return stuff
]]

secret = "asdf1234"

local env, ret = sandbox.eval(code)
assert(env, ret)

assert(ret == env.stuff, "return value")
assert(env.get_secret() ~= secret, "get_secret")
assert(env.get_globals() == "get_globals=function get_secret=function hack=function read_file=function stuff=number", "get_globals")
assert(pcall(env.read_file, "./test.lua") == false, "read_file")
assert(env.hack(function() return asdf end) ~= secret, "hack")

print "tests OK"
