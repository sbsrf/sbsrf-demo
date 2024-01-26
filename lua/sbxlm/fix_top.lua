-- Name: fix_top.lua
-- 名称: 固顶处理器
-- Version: 20240124
-- Author: 蓝落萧

local rime = require "rime"

local this = {}

---@param env Env
function this.init(env)
  this.memory = rime.Memory(env.engine, env.engine.schema)
end

---@param key_event KeyEvent
---@param env Env
function this.func(key_event, env)
  if key_event:release() or key_event:shift() or key_event:alt() or key_event:caps() then
    return rime.process_results.kNoop
  end
  -- j for add, l for delete
  if not key_event:ctrl() or (key_event.keycode ~= 106 and key_event.keycode ~= 108) then
    return rime.process_results.kNoop
  end
  local context = env.engine.context
  local candidate = context:get_selected_candidate()
  if not candidate then
    return rime.process_results.kRejected
  end
  if not rime.match(candidate.preedit, "[bpmfdtnlgkhjqxzcsrywv][a-z]{2}[aeiou]?") then
    return rime.process_results.kRejected
  end
  local entry = rime.DictEntry()
  entry.text = candidate.text
  entry.custom_code = candidate.preedit .. ' '
  if key_event.keycode == 106 then
    rime.error("fixing word: " .. entry.text .. " at " .. entry.custom_code)
    this.memory:update_userdict(entry, 1, "")
  else
    rime.error("unfixing word: " .. entry.text .. " at " .. entry.custom_code)
    this.memory:update_userdict(entry, -1, "")
  end
  context:refresh_non_confirmed_composition()
  return rime.process_results.kAccepted
end

return this
