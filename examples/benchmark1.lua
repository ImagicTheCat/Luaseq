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

local time = 0
function start()
  time = os.clock()
end

function stop()
  time = os.clock()-time
  print(time.." s")
  return time
end

-- compare callback hell to Luaseq spent time

function do_callback(n, func)
  if n > 0 then
    setTimeout(10, function()
      func(n-1, do_callback)
    end)
  else
    print(n)
    ev.Loop.default:unloop()
  end
end

function do_async(n)
  if n > 0 then
    local r = async()

    setTimeout(10, function()
      r(n-1)
    end)

    do_async(r:wait())
  else
    print(n)
    ev.Loop.default:unloop()
  end
end

local it = ...
if not it then 
  it = 500 
else
  it = tonumber(it)
end

start()
do_callback(it, do_callback)
ev.Loop.default:loop()
local ctime = stop()

start()
async(function()
  do_async(it)
end)
ev.Loop.default:loop()
local atime = stop()

if atime > ctime then
  print("Luaseq async "..atime/ctime.." times slower than callback hell")
else
  print("callback hell "..atime/ctime.." times slower than Luaseq async")
end

