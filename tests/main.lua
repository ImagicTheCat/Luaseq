package.path = "src/?.lua;"..package.path

local async = require("Luaseq").async
local mutex = require("Luaseq").mutex
local semaphore = require("Luaseq").semaphore

local function asyncR(f, ...) coroutine.wrap(f)(...) end

local function errcheck(perr, f, ...)
  local ok, err = pcall(f, ...)
  assert(not ok and not not err:find(perr, 1, true))
end

-- Task

do -- test callback and multiple coroutines waiting on a task
  local t = async()
  local sum = 0
  t:wait(function(t) sum = t:wait()+sum end)
  for i=1,3 do asyncR(function() sum = t:wait()+sum end) end
  assert(sum == 0)
  assert(not t:done())
  t(true, 2)
  assert(t:done())
  assert(sum == 8)
end
do -- test subsequent completions/waits
  local t = async()
  local sum = 0
  asyncR(function() for i=1,10 do sum = sum+t:wait() end end)
  t:complete(2)
  assert(sum == 20)
  errcheck("task already done", t, true, 3) -- must throw an error
  errcheck("task already done", t.error, t, "errmsg") -- must throw an error
  -- task can still be waited on
  asyncR(function(n) for i=1,n do sum = sum+t:wait() end end, 10)
  assert(sum == 40)
end
do -- standalone error tests
  local t = async()
  local tc = async(function() t:wait() end)
  t:error("test error #42")
  errcheck("task already done", t)
  errcheck("test error #42", t.wait, t)
  errcheck("test error #42", t.wait, t, function(t) t:wait() end)
  errcheck("test error #42", tc.wait, tc)
end
do -- other error checks
  local t = async()
  -- non-coroutine thread
  errcheck("async wait from a non-coroutine thread", t.wait, t)
  -- error on first resume
  local t2 = async(function() return 1*nil end)
  errcheck("arithmetic on a nil value", t2.wait, t2)
  -- error on subsequent resume
  local t3 = async(function() t:wait(); return 1*nil end)
  t:complete()
  errcheck("arithmetic on a nil value", t3.wait, t3)
end

-- Mutex

do -- test mutex lock/unlock
  local m = mutex()
  assert(not m:locked())
  local t_begin, t_end = async(), async()
  local step
  local function launch(name)
    asyncR(function()
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
  t_begin:complete(); assert(step == "first-exec")
  t_end:complete(); assert(step == "second-exec")
  assert(not m:locked())
end
do -- test reentrant mutex
  local m = mutex("reentrant")
  assert(not m:locked())
  local t = async()
  local step
  local function launch(name)
    asyncR(function()
      for i=1,3 do m:lock() end
      step = name; t:wait()
      for i=1,3 do m:unlock() end
    end)
  end
  launch("first")
  assert(m:locked())
  launch("second")
  assert(step == "first")
  t:complete(); assert(step == "second")
  assert(not m:locked())
end
do -- check errors
  errcheck("invalid mutex mode", mutex, "rentrant") -- typo
  local m = mutex()
  errcheck("mutex lock outside a coroutine", m.lock, m)
  errcheck("mutex unlock outside a coroutine", m.unlock, m)
  asyncR(function()
    errcheck("mutex is not locked", m.unlock, m)
    m:lock()
    errcheck("mutex is not reentrant", m.lock, m)
  end)
  asyncR(function() errcheck("mutex unlock in wrong thread", m.unlock, m) end)
  -- check resume error
  local m2 = mutex()
  local t = async()
  asyncR(function()
    m2:lock(); t:wait()
    errcheck("arithmetic on a nil value", m2.unlock, m2)
  end)
  asyncR(function()
    m2:lock()
    local a = 1*nil
    m2:unlock()
  end)
  t:complete()
end

-- Semaphore
do -- test basics
  local sem = semaphore(2)
  local done
  assert(sem.units == 2)
  asyncR(function()
    for i=1,4 do sem:demand() end
    done = true
  end)
  assert(sem.units == 0 and not done)
  sem:supply()
  assert(sem.units == 0 and not done)
  sem:supply()
  assert(sem.units == 0 and done)
  sem:supply()
  assert(sem.units == 1)
  sem:demand()
  assert(sem.units == 0)
end
do -- check errors
  errcheck("units must be >= 0", semaphore, -1)
  --
  local sem = semaphore(0)
  errcheck("demand from a non-coroutine thread", sem.demand, sem)
  --
  asyncR(function()
    sem:demand()
    error "test#1"
  end)
  errcheck("test#1", sem.supply, sem)
end
