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

-- 5ms operation
function op(cb)
  setTimeout(5, function()
    cb()
  end)
end

-- 10 op
function do_callback(finished)
  op(function()
    op(function()
      op(function()
        op(function()
          op(function()
            op(function()
              op(function()
                op(function()
                  op(function()
                    op(function()
                      finished()
                    end)
                  end)
                end)
              end)
            end)
          end)
        end)
      end)
    end)
  end)
end



-- async -> sync way
function async_op()
  local r = async()
  op(r)
  r:wait()
end

-- 10 op
function do_async(finished)
  async(function()
    async_op()
    async_op()
    async_op()
    async_op()
    async_op()
    async_op()
    async_op()
    async_op()
    async_op()
    async_op()
    finished()
  end)
end


function do_test(n, func)
  if n > 0 then
    func(function()
      do_test(n-1, func)
    end)
  else
    print("n = "..n)
    ev.Loop.default:unloop()
  end
end

local it = ...
if not it then 
  it = 100 
else
  it = tonumber(it)
end

start()
do_test(it, do_callback)
ev.Loop.default:loop()
local ctime = stop()

start()
do_test(it, do_async)
ev.Loop.default:loop()
local atime = stop()

if atime > ctime then
  print("Luaseq async "..atime/ctime.." times slower than callback hell")
else
  print("callback hell "..atime/ctime.." times slower than Luaseq async")
end

