-- Name: letter_select.lua
-- 名称: 字母选重处理器
-- Version: 20240124
-- Author: 蓝落萧

local rime = require "rime"
local core = require "sbxlm.core"

local this = {}

---@param env Env
function this.init(env)
  this.select_keys = core.select_keys(env.engine.schema.config)
end

---@param key_event KeyEvent
---@param env Env
function this.func(key_event, env)
  if key_event:release() or key_event:shift() or key_event:alt() or key_event:ctrl() or key_event:caps() then
    return rime.process_results.kNoop
  end
  local maybe_letter = key_event:repr()
  local maybe_index = this.select_keys[maybe_letter]
  if not maybe_index then
    return rime.process_results.kNoop
  end
  local context = env.engine.context
  local input = env.engine.context.input
  if string.len(input) ~= 6 then
    return rime.process_results.kNoop
  end
  if context.composition:back().menu:get_candidate_at(maybe_index) then
    context:select(maybe_index - 1)
    context:commit()
    return rime.process_results.kAccepted
  else
    return rime.process_results.kRejected
  end
end

return this
