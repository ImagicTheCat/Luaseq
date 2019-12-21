-- https://github.com/ImagicTheCat/Luaseq
-- MIT license (see LICENSE)

local Luaseq = {}

local select = select
local error = error
local setmetatable = setmetatable
local table_unpack = table.unpack or unpack
local table_insert = table.insert
local coroutine_running = coroutine.running
local coroutine_yield = coroutine.yield
local coroutine_create = coroutine.create
local coroutine_resume = coroutine.resume
local debug_traceback = debug.traceback
local stderr = io.stderr

-- Task

-- yield current coroutine (wait for task to return)
-- return task return values
local function task_wait(self)
  if self.r then return unpack(self.r,1,self.n) end -- already done, return values

  local co = coroutine_running()
  if not co then error("async wait outside a coroutine") end
  table_insert(self, co)
  return coroutine_yield(co) -- wait for the task to return
end

-- return/end task
-- ...: return values
local function task_return(self, ...)
  if not self.r then
    self.r, self.n = {...}, select("#", ...)

    for _, co in ipairs(self) do
      local ok, err = coroutine_resume(co, ...)
      if not ok then stderr:write(debug_traceback(co, "async: "..err).."\n") end
    end
  end
end

local meta_task = {
  __index = {wait = task_wait},
  __call = task_return
}

-- Luaseq

-- no parameters: create a task
--- return task
-- parameters: execute function as coroutine (shortcut)
--- f: function
function Luaseq.async(f)
  if f then
    local co = coroutine_create(f)
    local ok, err = coroutine_resume(co)
    if not ok then stderr:write(debug_traceback(co, "async: "..err).."\n") end
  else
    return setmetatable({}, meta_task)
  end
end

return Luaseq
