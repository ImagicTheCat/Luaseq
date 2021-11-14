package.path = "src/?.lua;"..package.path
async = require("Luaseq").async
mutex = require("Luaseq").mutex

local function errcheck(perr, f, ...)
  local ok, err = pcall(f, ...)
  assert(not ok and not not err:find(perr))
end

-- Task

do -- test multiple coroutines waiting on a task
  local t = async()
  local sum = 0
  for i=1,3 do async(function() sum = t:wait()+sum end) end
  assert(sum == 0)
  assert(not t:completed())
  t(2)
  assert(t:completed())
  assert(sum == 6)
end
do -- test subsequent completions/waits
  local t = async()
  local sum = 0
  async(function() for i=1,10 do sum = sum+t:wait() end end)
  t(2)
  assert(sum == 20)
  errcheck("task already completed", t, 3) -- must throw an error
  -- task can still be waited on
  async(function(n) for i=1,n do sum = sum+t:wait() end end, 10)
  assert(sum == 40)
end
do -- other error checks
  local t = async()
  errcheck("async wait outside a coroutine", t.wait, t) -- outside coroutine
  -- error on first resume
  errcheck("arithmetic on a nil value", async, function() return 1*nil end)
  -- error on subsequent resume
  async(function() t:wait(); return 1*nil end)
  errcheck("arithmetic on a nil value", t)
end

-- Mutex

do -- test mutex lock/unlock
  local m = mutex()
  assert(not m:locked())
  local t_begin, t_end = async(), async()
  local step
  local function launch(name)
    async(function()
      m:lock()
      step = name.."-lock"
      t_begin:wait()
      step = name.."-exec"
      t_end:wait()
      m:unlock()
    end)
  end
  launch("first")
  assert(m:locked())
  launch("second")
  assert(step == "first-lock")
  t_begin(); assert(step == "first-exec")
  t_end(); assert(step == "second-exec")
  assert(not m:locked())
end
do -- test reentrant mutex
  local m = mutex("reentrant")
  assert(not m:locked())
  local t = async()
  local step
  local function launch(name)
    async(function()
      for i=1,3 do m:lock() end
      step = name; t:wait()
      for i=1,3 do m:unlock() end
    end)
  end
  launch("first")
  assert(m:locked())
  launch("second")
  assert(step == "first")
  t(); assert(step == "second")
  assert(not m:locked())
end
do -- check errors
  errcheck("invalid mutex mode", mutex, "rentrant") -- typo
  local m = mutex()
  errcheck("mutex lock outside a coroutine", m.lock, m)
  errcheck("mutex unlock outside a coroutine", m.unlock, m)
  async(function()
    errcheck("mutex is not locked", m.unlock, m)
    m:lock()
    errcheck("mutex is not reentrant", m.lock, m)
  end)
  async(function() errcheck("mutex unlock in wrong thread", m.unlock, m) end)
  -- check resume error
  local m2 = mutex()
  local t = async()
  async(function()
    m2:lock(); t:wait()
    errcheck("arithmetic on a nil value", m2.unlock, m2)
  end)
  async(function()
    m2:lock()
    local a = 1*nil
    m2:unlock()
  end)
  t()
end
