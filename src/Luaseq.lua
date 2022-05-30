-- https://github.com/ImagicTheCat/Luaseq
-- MIT license (see LICENSE or src/Luaseq.lua)

--[[
MIT License

Copyright (c) 2019 ImagicTheCat

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

local Luaseq = {}

local select, ipairs, setmetatable, xpcall = select, ipairs, setmetatable, xpcall
local table_unpack = table.unpack or unpack
local function table_pack(...) return {n = select("#", ...), ...} end
local table_insert, table_remove = table.insert, table.remove
local coroutine_running = coroutine.running
local coroutine_yield = coroutine.yield
local coroutine_create = coroutine.create
local coroutine_resume = coroutine.resume

-- Task
-- A task is a table where the array part is the list of waiting coroutines.

local task = {}

-- Wait for task completion.
-- Will yield the current coroutine if the task is not done.
--
-- returns task return values or propagates the task error
function task:wait()
  if not self.r then -- not done yet
    -- wait for the task to return
    local co, main = coroutine_running()
    if not co or main then error("async wait outside a coroutine") end
    table_insert(self, co)
    coroutine_yield()
  end
  if self.err then error(table_unpack(self.r, 1, self.n)) -- propagate error
  else return table_unpack(self.r, 1, self.n) end -- completed, return values
end

-- Check if the task is done (completed or terminated with an error).
function task:done() return self.r ~= nil end

-- Complete task (subsequent calls will throw an error).
-- Waiting coroutines are resumed in the same order of wait() calls.
--
-- ...: task return values
function task:complete(...)
  if self.r then error("task already done") end
  self.r = table_pack(...)
  for _, co in ipairs(self) do
    local ok, err = coroutine_resume(co)
    if not ok then error(debug.traceback(co, err), 0) end
  end
end

-- Terminate task with an error (subsequent calls will throw an error).
-- Waiting coroutines are resumed in the same order of wait() calls.
--
-- ...: arguments passed to standard error()
function task:error(...)
  if self.r then error("task already done") end
  self.r, self.err = table_pack(...), true
  for _, co in ipairs(self) do
    local ok, err = coroutine_resume(co)
    if not ok then error(debug.traceback(co, err), 0) end
  end
end

local meta_task = {
  __index = task,
  __call = task.complete
}

-- Mutex
-- A mutex is a table where the array part is the list of locking coroutines,
-- the first being the active one followed by the waiting ones.

local mutex = {}

-- Lock mutex.
function mutex:lock()
  local co, main = coroutine_running()
  if not co or main then error("mutex lock outside a coroutine") end
  if self.locks > 0 then -- already locked
    if self[1] == co then -- same thread
      if not self.reentrant then error("mutex is not reentrant") end
      self.locks = self.locks+1
    else -- other thread, wait
      table_insert(self, co)
      coroutine_yield()
    end
  else -- first lock
    self.locks = 1
    table_insert(self, co)
  end
end

-- Unlock mutex.
-- Waiting coroutines are resumed in the same order of lock() calls.
function mutex:unlock()
  local co, main = coroutine_running()
  if not co or main then error("mutex unlock outside a coroutine") end
  if self.locks == 0 then error("mutex is not locked") end
  if self[1] == co then -- same thread
    self.locks = self.locks-1
    if self.locks == 0 then -- completely unlocked
      table_remove(self, 1) -- remove from queue
      if #self > 0 then
        -- give lock to next thread
        self.locks = 1
        local ok, err = coroutine_resume(self[1])
        if not ok then error(debug.traceback(co, err), 0) end
      end
    end
  else error("mutex unlock in wrong thread") end
end

-- Check if the mutex is locked.
-- return boolean
function mutex:locked() return self.locks > 0 end

local meta_mutex = {__index = mutex}

-- Luaseq

-- Async utility.
--
-- No arguments: create a task.
--- return task
--
-- With arguments: create a VM thread wrapped as a task.
-- I.e. it executes the passed function as a coroutine, like a detached job.
--- f: function
--- ...: arguments
--- return task
function Luaseq.async(f, ...)
  local task = setmetatable({}, meta_task)
  if f then -- create coroutine
    local co = coroutine_create(function(...)
      local traceback
      local function error_handler(err) traceback = debug.traceback(err, 2) end
      local r = table_pack(xpcall(f, error_handler, ...)) -- call
      if r[1] then task(table_unpack(r, 2, r.n)) -- complete task
      else task:error(traceback, 0) end -- task error
    end)
    local ok, err = coroutine_resume(co, ...)
    if not ok then error(debug.traceback(co, err), 0) end
  end
  return task
end

-- Create a mutex.
-- mode: (optional) "reentrant"
-- return mutex
function Luaseq.mutex(mode)
  local o = setmetatable({locks = 0}, meta_mutex)
  if mode then
    if mode == "reentrant" then o.reentrant = true
    else error("invalid mutex mode") end
  end
  return o
end

return Luaseq
