-- Name: upper_case.lua
-- 名称: 大写字母处理器
-- Version: 20240125
-- Author: 蓝落萧

local rime = require("rime")
local core = require("sbxlm.core")

---@param key_event KeyEvent
---@param env Env
local function process(key_event, env)
  if key_event:release() or key_event:alt() or key_event:ctrl() or key_event:caps() then
    return rime.process_results.kNoop
  end
  local keycode = key_event.keycode
  if keycode < 65 or keycode > 90 then
    return rime.process_results.kNoop
  end
  local context = env.engine.context
  if not context:is_composing() then
    return rime.process_results.kNoop
  end
  local id = env.engine.schema.schema_id
  local third_pop = context:get_option("third_pop")
  local pro_char = context:get_option("pro_char")
  local input = context.input
  if core.sss(input) and (core.jm(id) and third_pop or core.fx(id)) then
    -- 这种情况下，不顶屏，只追加编码
    goto add
  elseif core.ss(input) and (core.fd(id) or (core.fm(id) or core.sp(id)) and pro_char) then
    goto add
  elseif rime.match(input, ".{4}") then
    context:pop_input(2)
    context:confirm_current_selection()
    context:commit()
    context:push_input(string.sub(input, 3))
  else
    context:confirm_current_selection()
    context:commit()
  end
  ::add::
  local char = utf8.char(keycode + 32)
  context:push_input(char)
  return rime.process_results.kAccepted
end

return process
