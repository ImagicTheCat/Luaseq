-- https://github.com/ImagicTheCat/Luaseq
-- MIT license (see LICENSE)

--[[
MIT License

Copyright (c) 2019 Imagic

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

local select, error, ipairs = select, error, ipairs
local setmetatable = setmetatable
local table_unpack = table.unpack or unpack
local table_insert, table_remove = table.insert, table.remove
local coroutine_running = coroutine.running
local coroutine_yield = coroutine.yield
local coroutine_create = coroutine.create
local coroutine_resume = coroutine.resume
local debug_traceback = debug.traceback
local stderr = io.stderr

-- Task
-- A task is a table where the array part is the list of waiting coroutines.

local task = {}

-- Wait for task completion.
-- Will yield the current coroutine if the task is not completed.
--
-- return task return values
function task:wait()
  if self.r then return table_unpack(self.r, 1, self.n) end -- already done, return values
  local co, main = coroutine_running()
  if not co or main then error("async wait outside a coroutine") end
  table_insert(self, co)
  return coroutine_yield() -- wait for the task to return
end

-- Check if the task is completed.
-- return boolean
function task:completed() return self.r ~= nil end

-- Complete task (subsequent calls will throw an error).
-- Waiting coroutines are resumed in the same order of wait() calls.
--
-- ...: task return values
local function task_return(self, ...)
  if self.r then error("task already completed") end
  self.r, self.n = {...}, select("#", ...)
  for _, co in ipairs(self) do
    local ok, err = coroutine_resume(co, ...)
    if not ok then
      stderr:write(debug_traceback(co, "async: "..err).."\n")
      error("error resuming coroutine")
    end
  end
end

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
        if not ok then
          stderr:write(debug_traceback(co, "async: "..err).."\n")
          error("error resuming coroutine")
        end
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
-- With arguments: execute a function as a coroutine (directly resumed).
-- Note: this does nothing special, any coroutine can be used with tasks.
--
--- f: function
--- return created coroutine (thread)
function Luaseq.async(f)
  if f then -- create coroutine
    local co = coroutine_create(f)
    local ok, err = coroutine_resume(co)
    if not ok then
      stderr:write(debug_traceback(co, "async: "..err).."\n")
      error("error resuming coroutine")
    end
    return co
  else -- create task
    return setmetatable({}, meta_task)
  end
end

-- Create a mutex.
-- mode: (optional) "reentrant"
-- return mutex
function Luaseq.mutex(mode)
  local o = setmetatable({locks = 0}, meta_mutex)
  if mode == "reentrant" then o.reentrant = true end
  return o
end

return Luaseq
