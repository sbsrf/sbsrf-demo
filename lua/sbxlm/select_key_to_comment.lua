-- Name: select_key_to_comment.lua
-- 名称: 选择键转注释过滤器
-- Version: 20240125
-- Author: 戴石麟

local rime = require "rime"

local this = {}

---@param env Env
function this.init(env)
  local config = env.engine.schema.config
  this.keys = config.get_string(config, "menu/alternative_select_keys")
end

---@param translation Translation
---@param env Env
function this.func(translation, env)
  local i = 0
  for candidate in translation:iter() do
    if string.len(candidate.preedit) >= 4 then
      j = i % 6 + 1
      local comment = candidate.comment
      candidate.comment = string.sub(this.keys, j, j)
      if candidate.comment == "_" then
        candidate.comment = ""
      end
      
      if string.len(comment) > 0 then
            candidate.comment = candidate.comment .. ' |' .. comment
      end
    end
    i = i + 1
    rime.yield(candidate)
  end
end

return this
