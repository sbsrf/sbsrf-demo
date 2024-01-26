-- Name: radicals.lua
-- 名称: 飞系部首反查
-- Version: 20240123
-- Author: 蓝落萧

local rime = require "rime"

local this = {}

---@param env Env
function this.init(env)
  this.lookup_tags = { "sbjm_lookup", "bihua_lookup", "pinyin_lookup", "zhlf_lookup" }
  ---@type { string : string }
  this.radicals = {}
  local path = rime.api.get_user_data_dir() .. "/lua/sbxlm/radicals.txt"
  local file = io.open(path, "r")
  if not file then
    return
  end
  for line in file:lines() do
    local char, radical = line:match("([^\t]+)\t([^\t]+)")
    this.radicals[char] = radical
  end
  file:close()
end

---@param translation Translation
---@param env Env
function this.func(translation, env)
  local segment = env.engine.context.composition:back()
  for _, tag in ipairs(this.lookup_tags) do
    if segment:has_tag(tag) then
      goto lookup
    end
  end
  goto default
  ::lookup::
  for candidate in translation:iter() do
    candidate.comment = candidate.comment .. " 【" .. (this.radicals[candidate.text] or "") .. "】"
    rime.yield(candidate)
  end
  ::default::
  for candidate in translation:iter() do
    rime.yield(candidate)
  end
end

return this
