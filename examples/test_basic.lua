-- basic tests

package.path = "src/?.lua;"..package.path
async = require("Luaseq").async

print("[test error]")
async(function()
  error("test")
end)
print()

local re = async()
async(function()
  re:wait()
  error("test2")
end)
re()

print("\n[test multiple wait]")
local r = async()

async(function()
  print("1", r:wait())
end)

async(function()
  print("2", r:wait())
end)

async(function()
  print("3", r:wait())
end)

r("ok")

print("\n[test post wait]")
async(function()
  print("4", r:wait())
end)

print("\n[test post return => nothing]")
r("ok")
