-- this example use luajit and FFI

-- add package path for the example
package.path = package.path..";../src/?.lua;"

-- lib
local Luaseq = require("Luaseq")
async = Luaseq.async

-- utils to create async task
local ffi = require("ffi")
ffi.cdef([[
  typedef struct timespec {long tv_sec; long   tv_nsec;};
  int nanosleep(const struct timespec *rqtp, struct timespec *rmtp);
]])

local sleep_acc = 0
local os_clock = os.clock
function os.clock()
  return os_clock()+sleep_acc
end

local rt = ffi.new("struct timespec", 0, 0)
function sleep(msec)
  rt.tv_nsec = 1000000*msec
  ffi.C.nanosleep(rt, nil)
  sleep_acc = sleep_acc+msec/1000
end

local timeouts = {}

function timeout_loop()
  local rms = {}
  local calls = {}

  for k,timeout in pairs(timeouts) do
    if os.clock() >= timeout[1] then
      table.insert(rms, k)
      table.insert(calls, timeout[2])
    end
  end

  for k,v in pairs(rms) do
    timeouts[v] = nil
  end

  for k,v in pairs(calls) do
    v()
  end
end

function setTimeout(msec, cb)
  table.insert(timeouts, {os.clock()+msec/1000, cb})
end


-- tasks

local running = true

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
end)

while running do
  timeout_loop()
  sleep(10)
end
