
Luaseq is a small library to make async calls in a sync way using coroutines.

Look at the examples for more understanding of the library.

# Build async function

For example, if we have an asynchronous process, like fetching a webpage content:

```lua
local Luaseq = require("Luaseq")
async = Luaseq.async

-- create the async function
function download(url)
  local r = async() -- create "returner"

  http_request(url, function(content)
    r(content) -- return content
  end)

  return r:wait() -- wait for the returned values
end

-- download 10 url sequentially
-- need to be inside a coroutine (like inside an async context)
async(function()
  for i=1,10 do
    local content = download("http://foo.bar/"..i..".txt")
    print(content)
  end
end)
```

```lua
-- API

-- create an async context if a function is passed (execute the function in a coroutine if none exists)
-- force: if passed/true, will create a coroutine even if already inside one
--
-- without arguments, an async returner is created and returned
-- returner(...): call to pass return values
-- returner:wait(): call to wait for the return values
Luaseq.async(func, force)
```

# Versions

It is designed to works with luajit (Lua 5.1), but the code should work on latest versions.
