-- Name: key_binder.lua
-- 名称: 正则按键绑定器
-- Version: 20240125
-- Author: 蓝落萧

local rime = require "rime"

local this = {}

---@class Binding
---element
---@field match string
---@field accept KeyEvent
---@field send_sequence KeySequence

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
  ---@type Binding[]
  this.bindings = {}
  local config = env.engine.schema.config:get_list("key_binder/bindings")
  if not config then
    return
  end
  for i = 1, config.size do
    local item = config:get_at(i)
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
  local repr = key_event:repr()
  for _, binding in ipairs(this.bindings) do
    if key_event:eq(binding.accept) then
      local input = env.engine.context.input
      local matched = rime.match(input, binding.match)
      if matched then
        for _, event in ipairs(binding.send_sequence:toKeyEvent())
        do
          env.engine:process_key(event)
        end
        return rime.process_results.kAccepted
      end
    end
  end
  return rime.process_results.kNoop
end

return this
