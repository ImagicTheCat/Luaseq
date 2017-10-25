package = "Luaseq"
version = "scm-1"
source = {
  url = "git://github.com/ImagicTheCat/Luaseq",
}

description = {
  summary = "One file simple Lua library to manage async calls in a sync way using coroutines.",
  detailed = [[
  ]],
  homepage = "https://github.com/ImagicTheCat/Luaseq",
  license = "MIT"
}

dependencies = {
  "lua >= 5.1, < 5.4"
}

build = {
  type = "builtin",
  modules = {
    Luaseq = "src/Luaseq.lua"
  }
}
