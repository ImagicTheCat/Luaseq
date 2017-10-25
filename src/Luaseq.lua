
local Luaseq = {}

local unpack = table.unpack or unpack

local function wait(self)
  local r = self.r
  if r then
    return unpack(r) -- indirect immediate return
  else
    return coroutine.yield() -- indirect coroutine return
  end
end

local function areturn(self, ...)
  self.r = {...} -- set return values on the table (in case where the return is triggered immediatly)
  local co = self.co
  if coroutine.running() ~= co then
    local ok, err = coroutine.resume(co, ...)
    if not ok then
      print(err)
    end
  end
end

-- create an async context if a function is passed (execute the function in a coroutine if none exists)
-- force: if passed/true, will create a coroutine even if already inside one
--
-- without arguments, an async returner is created and returned
-- returner(...): call to pass return values
-- returner:wait(): call to wait for the return values
function Luaseq.async(func, force)
  local co = coroutine.running()

  if func then -- block use mode
    if not co or force then -- exec in coroutine
      co = coroutine.create(func)
      local ok, err = coroutine.resume(co)
      if not ok then
        print(err)
      end
    else -- exec 
      func()
    end
  else -- in definition mode
    if co then
      return setmetatable({ wait = wait, co = co }, { __call = areturn })
    else
      error("async call outside a coroutine")
    end
  end
end

return Luaseq
