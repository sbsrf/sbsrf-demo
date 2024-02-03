-- 正则按键绑定处理器
-- 通用（不包含声笔系列码的特殊逻辑）
-- 本处理器在 Rime 标准库的按键绑定处理器（key_binder）的基础上增加了用正则表达式判断当前输入的编码的功能
-- 也即，在输入编码不同时，可以将按键绑定到不同的功能

local rime = require "rime"

local this = {}

---@class Binding
---element
---@field match string
---@field accept KeyEvent
---@field send_sequence KeySequence

---解析配置文件中的按键绑定配置
---@param value ConfigMap
---@return Binding | nil
local function parse(value)
  local match = value:get_value("match")
  local accept = value:get_value("accept")
  local send_sequence = value:get_value("send_sequence")
  if not match or not accept or not send_sequence then
    return nil
  end
  local key_event = rime.KeyEvent(accept:get_string())
  local sequence = rime.KeySequence(send_sequence:get_string())
  local binding = { match = match:get_string(), accept = key_event, send_sequence = sequence }
  return binding
end

---@param env Env
function this.init(env)
  this.redirecting = false
  ---@type Binding[]
  this.bindings = {}
  local bindings = env.engine.schema.config:get_list("key_binder/bindings")
  if not bindings then
    return
  end
  for i = 1, bindings.size do
    local item = bindings:get_at(i)
    if not item then goto continue end
    local value = item:get_map()
    if not value then goto continue end
    local binding = parse(value)
    if not binding then goto continue end
    table.insert(this.bindings, binding)
    ::continue::
  end
end

---@param key_event KeyEvent
---@param env Env
function this.func(key_event, env)
  if this.redirecting then
    return rime.process_results.kNoop
  end
  local input = env.engine.context.input
  for _, binding in ipairs(this.bindings) do
    -- 只有当按键和当前输入的模式都匹配的时候，才起作用
    if key_event:eq(binding.accept) and rime.match(input, binding.match) then
      this.redirecting = true
      for _, event in ipairs(binding.send_sequence:toKeyEvent()) do
        env.engine:process_key(event)
      end
      this.redirecting = false
      return rime.process_results.kAccepted
    end
  end
  return rime.process_results.kNoop
end

return this
