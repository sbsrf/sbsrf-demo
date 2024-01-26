-- Name: popping.lua
-- 名称: 通用顶功处理器
-- Version: 20240128
-- Author: 蓝落萧

local rime = require("rime")

local this = {}

---@class PoppingConfig
---@field when string | nil
---@field when_not string | nil
---@field match string
---@field accept string
---@field prefix number | nil

---@param env Env
function this.init(env)
  local config = env.engine.schema.config
  local popping_config = config:get_list("speller/popping")
  if not popping_config then
    return
  end
  ---@type PoppingConfig[]
  this.popping = {}
  for i = 1, popping_config.size do
    local item = popping_config:get_at(i - 1)
    if not item then goto continue end
    local value = item:get_map()
    if not value then goto continue end
    local popping = {
      when = value:get_value("when") and value:get_value("when"):get_string(),
      when_not = value:get_value("when_not") and value:get_value("when_not"):get_string(),
      match = value:get_value("match"):get_string(),
      accept = value:get_value("accept"):get_string(),
      prefix = value:get_value("prefix") and value:get_value("prefix"):get_int(),
    }
    table.insert(this.popping, popping)
    ::continue::
  end
end

---@param key_event KeyEvent
---@param env Env
function this.func(key_event, env)
  local context = env.engine.context
  if key_event:release() or key_event:shift() or key_event:alt() or key_event:ctrl() or key_event:caps() then
    return rime.process_results.kNoop
  end
  local input = context.input
  if string.len(input) == 0 then
    return rime.process_results.kNoop
  end
  if rime.match(input, ".+\\.") then
    context:pop_input(1)
  end
  local incoming = key_event:repr()
  for _, rule in ipairs(this.popping) do
    local when = rule.when
    local when_not = rule.when_not
    if when and not context:get_option(when) then
      goto continue
    end
    if when_not and context:get_option(when_not) then
      goto continue
    end
    if not rime.match(input, rule.match) then
      goto continue
    end
    if not rime.match(incoming, rule.accept) then
      goto continue
    end
    if context:has_menu() then
      if rule.prefix then
        context:pop_input(string.len(input) - rule.prefix)
      end
      context:confirm_current_selection()
      context:commit()
      if rule.prefix then
        context:push_input(string.sub(input, rule.prefix + 1))
      end
    else
      context:clear()
    end
    goto finish
    ::continue::
  end
  ::finish::
  return rime.process_results.kNoop
end

return this
