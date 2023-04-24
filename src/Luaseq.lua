-- MIT License
-- 
-- Copyright (c) 2019 ImagicTheCat
-- 
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
-- 
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
-- 
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

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

-- Wait for task completion (still usable when done).
-- No arguments (sync): yield the current coroutine if the task is not done yet.
--- returns the task return values or propagates the task error.
-- With arguments (async):
--- callback(task): called when the task is done (completion or error)
function task:wait(callback)
  if callback then
    if not self.r then table_insert(self, callback)
    else callback(self) end
  else -- coroutine handling
    if not self.r then -- not done yet
      -- wait for the task to return
      local co, main = coroutine_running()
      if not co or main then error("async wait from a non-coroutine thread") end
      table_insert(self, co)
      coroutine_yield()
    end
    local r = self.r
    if not r[1] then error(r[2], 0) -- propagate error
    else return table_unpack(r, 2, r.n) end -- completed, return values
  end
end

-- Check if the task is done (completed or terminated with an error).
-- return boolean
function task:done() return self.r ~= nil end

-- Task return (completion or termination).
-- Waiting coroutines/callbacks are resumed in the same order of wait() calls.
-- Subsequent calls will throw an error.
--
-- ...: common soft error handling interface (ok, ...)
--- When ok is truthy, varargs are return values, otherwise an error object / message.
local function task_return(self, ...)
  if self.r then error("task already done") end
  self.r = table_pack(...)
  -- dispatch
  for _, callback in ipairs(self) do
    if type(callback) == "thread" then
      local ok, err = coroutine_resume(callback)
      if not ok then error(debug.traceback(callback, err), 0) end
    else callback(self) end
  end
end

-- Complete task (equivalent to task(true, ...)).
-- ...: task return values
function task:complete(...) task_return(self, true, ...) end

-- Terminate task with an error (equivalent to task(false, err)).
-- err: error object / message
function task:error(err) task_return(self, false, err) end

local meta_task = {
  __index = task,
  __call = task_return
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

-- Asynchronous operation.
--
-- No arguments: create a standalone task handle.
-- With arguments: create a task wrapping an asynchronous function call.
-- I.e. it executes the passed function as a coroutine, like a detached job.
--- f: function
--- ...: arguments
-- return task
function Luaseq.async(f, ...)
  local task = setmetatable({}, meta_task)
  if f then -- create coroutine
    local co = coroutine_create(function(...)
      local traceback
      local function error_handler(err) traceback = debug.traceback(err, 2) end
      local r = table_pack(xpcall(f, error_handler, ...)) -- call
      if r[1] then task(table_unpack(r, 1, r.n)) -- complete task
      else task(false, traceback, 0) end -- task error
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
