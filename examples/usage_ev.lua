-- this example use lua-ev (see luarocks)

-- add package path for the example
package.path = ";../src/?.lua;"..package.path

-- lib
local ev = require("ev")
local Luaseq = require("Luaseq")
async = Luaseq.async

function setTimeout(msec, cb)
  local timer = ev.Timer.new(function(loop, timer, revents)
    cb()
    timer:stop(loop)
  end, msec/1000)

  timer:start(ev.Loop.default)
end

-- tasks

function async_add(a,b)
  local areturn = async()

  setTimeout(math.random(250,500), function()
    areturn(a+b)
  end)

  return areturn:wait()
end

function async_mult(a, b)
  local res = 0
  for i=1,b do
    res = async_add(res, a)
  end

  return res
end

-- async functions must be called inside an "async context" (just a coroutine) to have their results synced

async(function()
  print("simple sequential async tasks")
  for i=1,10 do
    print(async_add(10, i))
  end

  print("task using tasks, multiplication using async_add")
  print("mult = "..async_mult(5, 10))

  print("end")

  setTimeout(2000, function()
    running = false
  end)
end)

async(function()
  print("simple sequential async tasks2")
  for i=1,10 do
    print(async_add(10, i))
  end

  print("task using tasks, multiplication using async_add2")
  print("mult = "..async_mult(6, 10))

  print("end2")
end)

async(function()
  print("simple sequential async tasks3")
  for i=1,10 do
    print(async_add(10, i))
  end

  print("task using tasks, multiplication using async_add3")
  print("mult = "..async_mult(7, 10))

  print("end3")
end, true)

ev.Loop.default:loop()
