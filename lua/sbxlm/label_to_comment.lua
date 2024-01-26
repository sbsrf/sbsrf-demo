-- Name: label_to_comment.lua
-- 名称: 标签转注释过滤器
-- Version: 20240125
-- Author: 戴石麟、蓝落萧

local rime = require "rime"

local this = {}

---@param env Env
function this.init(env)
  this.labels = rime.get_string_list(env.engine.schema.config, "menu/alternative_select_labels")
end

---@param translation Translation
---@param env Env
function this.func(translation, env)
  local enabled = env.engine.context:get_option("label_to_comment")
  local i = 0
  for candidate in translation:iter() do
    if enabled and string.len(candidate.preedit) >= 4 then
      candidate.comment = this.labels[i % #this.labels + 1] .. candidate.comment
    end
    i = i + 1
    rime.yield(candidate)
  end
end

return this
