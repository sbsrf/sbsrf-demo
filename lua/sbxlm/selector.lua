-- Name: letter_select.lua
-- 名称: 字母选重处理器
-- Version: 20240124
-- Author: 蓝落萧

local rime = require "rime"

local this = {}

---@param env Env
function this.init(env)
  local config = env.engine.schema.config;
  this.select_keys = env.engine.schema.select_keys;
  this.select_patterns = rime.get_string_list(config, "menu/alternative_select_patterns")
  this.selector = rime.Processor(env.engine, "", "selector")
end

---@param key_event KeyEvent
---@param env Env
---@return ProcessResult
function this.func(key_event, env)
  if key_event.modifier > 0 then
    return rime.process_results.kNoop
  end
  local key = key_event:repr()
  if not string.find(this.select_keys, key) then
    return rime.process_results.kNoop
  end
  local input = env.engine.context.input
  for _, pattern in ipairs(this.select_patterns) do
    if rime.match(input, pattern) then
      return this.selector:process_key_event(key_event)
    end
  end
  return rime.process_results.kNoop
end

return this
