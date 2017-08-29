
local Luaseq = {}

local unpack = table.unpack or unpack

function Luaseq.async(func, ...)
  local co = coroutine.running()
  if co then -- in coroutine
    local ret = nil
    local params = {...}
    local function return_async(...)
      if not ret then -- prevents double or more calls
        ret = {...}

        --[[
        local log = tostring(co)..":"..tostring(func)
        for k,v in pairs(params) do
          log = log.." "..tostring(v)
        end
        log = log.." => "
        for k,v in pairs(ret) do
          log = log.." "..tostring(v)
        end
        print(log)
        --]]

        if coroutine.running() ~= co then
          local ok, err = coroutine.resume(co, ...)
          if not ok then
            print(err)
          end
        end
      end
    end

    func(return_async, ...)

    if ret then -- sync
      return unpack(ret)
    else -- async
      return coroutine.yield()
    end
  else -- not in a coroutine, create coroutine
    co = coroutine.create(function(func, ...)
      Luaseq.async(func, ...)
    end)
    local ok, err = coroutine.resume(co, func, ...)
    if not ok then
      print(err)
    end
  end
end

return Luaseq
