package.path = "src/?.lua;"..package.path
async = require("Luaseq").async

local function errcheck(perr, f, ...)
  local ok, err = pcall(f, ...)
  return not ok and not not err:find(perr)
end

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
  assert(errcheck("task already completed", t, 3)) -- must throw an error
  -- task can still be waited on
  async(function() for i=1,10 do sum = sum+t:wait() end end)
  assert(sum == 40)
end
do -- other error checks
  print("/!\\ Following async errors should be normal.")
  local t = async()
  assert(errcheck("async wait outside a coroutine", t.wait, t)) -- outside coroutine
  -- error on first resume
  assert(errcheck("error resuming coroutine", async, function() return 1*nil end))
  -- error on subsequent resume
  async(function() t:wait(); return 1*nil end)
  assert(errcheck("error resuming coroutine", t))
end
