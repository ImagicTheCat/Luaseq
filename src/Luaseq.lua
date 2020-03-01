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

-- wait for task to return
-- (will yield the current coroutine if the task is not completed)
-- return task return values
local function task_wait(self)
  if self.r then return unpack(self.r,1,self.n) end -- already done, return values

  local co = coroutine_running()
  if not co then error("async wait outside a coroutine") end
  table_insert(self, co)
  return coroutine_yield(co) -- wait for the task to return
end

-- return/complete/end task
-- (multiple calls will do nothing)
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
