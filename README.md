
Luaseq is a small library to make async calls in a sync way using coroutines.

Look at the examples for more understanding of the library.

# Build async function

Functions that will be used by the `async` function need to handle a special parameter (for better compatibility instead of using fenv), this parameter is a callback that needs to be called to return the function values.

For example, if we have an asynchronous process, like fetching a webpage content:

```lua
local Luaseq = require("Luaseq")
async = Luaseq.async

-- create the async function
function download(return_async, url)
  http_request(url, function(content)
    return_async(content)
  end)
end

-- download 10 url sequentially
-- need an async context first (in fact, it justs create a coroutine if there is none already running)
async(function()
  for i=1,10 do
    local content = async(download, "http://foo.bar/"..i..".txt")
    print(content)
  end
end)
```

```lua
-- API

-- call an async function in an "async context" to make them wait their results in this context
--- func: async function (just a function with the return callback as first argument)
--- ...: async function parameters
-- returns the function return values
Luaseq.async(func, ...)
end
```

# Versions

It is designed to works with luajit (Lua 5.1), but the code should be easy to adapt to other Lua versions.
