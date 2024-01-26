-- Name: auto_length.lua
-- 名称: 自动码长翻译器
-- Version: 20240124
-- Author: 蓝落萧

local rime           = require "rime"
local yield          = rime.yield
local core           = require "sbxlm.core"

local this           = {}
local kEncodedPrefix = "\x7fenc\x1f"
local kTopSymbol     = " \xe2\x98\x86 "
local kUnitySymbol   = " \xe2\x98\xaf "

---@param phrase string
---@param position number
---@param code string[]
function this.dfs_encode(phrase, position, code)
  -- write this phrase to a file
  if position > utf8.len(phrase) then
    local encoded = core.word_rules(code, this.id)
    if encoded then
      rime.error("encode: " .. phrase .. " " .. table.concat(code, " ") .. " " .. encoded .. "\n")
      ---@type DictEntry
      local entry = rime.DictEntry()
      entry.text = phrase
      entry.custom_code = encoded .. ' '
      this.memory:update_userdict(entry, 0, kEncodedPrefix)
      return true
    else
      return false
    end
  end
  local chars = {}
  for p, c in utf8.codes(phrase)
  do
    table.insert(chars, utf8.char(c))
  end
  local translations = this.reverse:lookup_stems(chars[position])
  if translations == "" then
    translations = this.reverse:lookup(chars[position])
  end
  rime.error("stem lookup: " .. chars[position] .. " " .. translations .. "\n")
  local ret = false
  -- split translations by space
  for t in string.gmatch(translations, "[^ ]+") do
    if string.len(t) < 4 then
      -- 不管在哪个方案里，长度小于 4 的不可能是全码
      goto continue
    end
    table.insert(code, t)
    local ok = this.dfs_encode(phrase, position + 1, code)
    ret = ret or ok
    table.remove(code)
    ::continue::
  end
  return ret
end

---@param input string
function this.static(input)
  for _, pattern in ipairs(this.static_patterns) do
    if rime.match(input, pattern) then
      return true
    end
  end
  return false
end

---@param commit CommitEntry
---@param context Context
function this.callback(commit, context)
  -- 记忆刚上屏的字词
  for i, entry in ipairs(commit:get())
  do
    if this.static(entry.preedit) then
      goto continue
    end
    rime.error("memorize word: " .. entry.text .. " " .. entry.preedit)
    if string.find(entry.custom_code, kEncodedPrefix) then
      ---@type DictEntry
      local newentry = rime.DictEntry()
      newentry.text = entry.text
      newentry.custom_code = string.sub(entry.custom_code, string.len(kEncodedPrefix) + 1)
      this.memory:update_userdict(newentry, 1, "")
    else
      this.memory:update_userdict(entry, 1, "")
    end
    ::continue::
  end
  -- 对上屏历史造词
  local phrase = ""
  for _, record in context.commit_history:iter() do
    local t = record.type
    phrase = record.text .. phrase
    if utf8.len(phrase) > this.max_phrase_length then
      break
    elseif utf8.len(phrase) < 2 then
      goto continue
    end
    if t ~= "table" and t ~= "user_table" and t ~= "sentence" and t ~= "uniquified" and t ~= "raw" then
      break
    end
    ---@type string[]
    local code = {}
    this.dfs_encode(phrase, 1, code)
    ::continue::
  end
end

---@param env Env
function this.init(env)
  this.memory = rime.Memory(env.engine, env.engine.schema)
  this.id = env.engine.schema.schema_id
  local dict_name = this.id == "sbfd" and "sbfm" or this.id
  local config = env.engine.schema.config
  this.reverse = rime.ReverseLookup(dict_name)
  this.third_pop = false
  this.enable_filtering = config:get_bool("translator/enable_filtering") or false
  this.lower_case = config:get_bool("translator/lower_case") or false
  this.stop_change = config:get_bool("translator/stop_change") or false
  this.delete_threshold = config:get_int("translator/delete_threshold") or 1000
  this.max_phrase_length = config:get_int("translator/max_phrase_length") or 4
  this.static_patterns = rime.get_string_list(config, "translator/disable_user_dict_for_patterns");
  rime.error("static patterns: " .. table.concat(this.static_patterns, " ") .. "\n")
  this.memory:memorize(function(commit) this.callback(commit, env.engine.context) end)
end

---@enum DynamicCodeType
local dtypes = {
  invalid = -1,
  short = 0,
  base = 1,
  select = 2,
  full = 3,
}

local fx_exchange = {
  ["2"] = "a",
  ["3"] = "e",
  ["7"] = "u",
  ["8"] = "i",
  ["9"] = "o"
}

---@param entry DictEntry
---@param segment Segment
---@param type string
---@param input string
---@return Phrase | nil
function this.validate_phrase(entry, segment, type, input)
  local completion = string.sub(entry.comment, 2)
  local alt_completion = ""
  local to_match = ""
  if entry.comment == "" then
    goto valid
  end
  if string.find(completion, "'") then
    -- 声笔简码和声笔飞讯用，多字词有两种输入方式
    alt_completion = string.sub(completion, -1, -1) .. string.sub(completion, -4, -3)
    -- 如果简码没启用 lower_case，就消除掉原来的编码
    if core.jm(this.id) and (not this.lower_case or not this.third_pop) then
      completion = ""
    end
  end
  if string.len(input) == 3 then
    if core.jm(this.id) and this.enable_filtering and utf8.len(entry.text) > 3 then
      return nil
    end
    goto valid
  elseif this.dynamic(input) == dtypes.select then
    to_match = string.sub(input, 4, -2)
  else
    to_match = string.sub(input, 4)
  end
  if fx_exchange[string.sub(to_match, 1, 1)] then
    to_match = fx_exchange[string.sub(to_match, 1, 1)] .. string.sub(to_match, 2)
  end
  if string.sub(completion, 1, string.len(to_match)) == to_match then
    goto valid
  elseif string.sub(alt_completion, 1, string.len(to_match)) == to_match then
    goto valid
  else
    return nil
  end
  ::valid::
  local phrase = rime.Phrase(this.memory, type, segment.start, segment._end, entry)
  phrase.preedit = input
  if string.find(entry.custom_code, kEncodedPrefix) then
    phrase.comment = kUnitySymbol
  elseif string.len(entry.custom_code) > 0 and string.len(entry.custom_code) < 6 then
    phrase.comment = kTopSymbol
  else
    phrase.comment = ""
  end
  return phrase
end

---@param input string
---@return DynamicCodeType
function this.dynamic(input)
  if core.jm(this.id) or core.fm(this.id) or core.fd(this.id) or core.sp(this.id) then
    return string.len(input) - 3
  elseif core.fx(this.id) then
    if rime.match(input, "[bpmfdtnlgkhjqxzcsrywv]{4}.*") then
      return string.len(input) - 3
    end
    if string.len(input) == 4 and not rime.match(input, ".{3}[23789]") then
      return dtypes.invalid
    end
    return string.len(input) - 4
  else
    return 0
  end
end

---@param input string
---@param segment Segment
---@param env Env
function this.func(input, segment, env)
  this.third_pop = env.engine.context:get_option("third_pop")
  local memory = this.memory
  if this.static(input) then
    ---@type { string: number }
    this.known_candidates = {}
    memory:dict_lookup(input, false, 0)
    for entry in memory:iter_dict()
    do
      local phrase = rime.Phrase(memory, "table", segment.start, segment._end, entry)
      phrase.preedit = input
      rime.yield(phrase:toCandidate())
    end
    return
  end
  -- 在四顶模式下，三码时的候选是 ss 词 + s 字
  if (core.sxs(input) and not this.third_pop)
      or (core.feixi(this.id) and core.sbsb(input))
      or (core.fx(this.id) and core.sxsb(input)) then
    memory:dict_lookup(string.sub(input, 1, 2), false, 1)
    local text = ""
    for entry in memory:iter_dict()
    do
      text = text .. entry.text
      break
    end
    memory:dict_lookup(string.sub(input, 3), false, 1)
    for entry in memory:iter_dict()
    do
      text = text .. entry.text
      break
    end
    local candidate = rime.Candidate("combination", segment.start, segment._end, text, "")
    candidate.preedit = input
    yield(candidate)
    return
  end
  local lookup_code = string.sub(input, 0, 3)
  ---@type Phrase[]
  local phrases = {}
  memory:user_lookup(lookup_code, true)
  for entry in memory:iter_user()
  do
    local phrase = this.validate_phrase(entry, segment, "user_table", input)
    if phrase then table.insert(phrases, phrase) end
  end
  memory:dict_lookup(lookup_code, true, 0)
  for entry in memory:iter_dict()
  do
    local phrase = this.validate_phrase(entry, segment, "table", input)
    if phrase then table.insert(phrases, phrase) end
  end
  table.sort(phrases, function(a, b)
    if a.comment == kTopSymbol and b.comment ~= kTopSymbol then
      return true
    end
    if a.comment ~= kTopSymbol and b.comment == kTopSymbol then
      return false
    end
    return a.weight > b.weight
  end)
  memory:user_lookup(kEncodedPrefix .. lookup_code, true)
  for entry in memory:iter_user()
  do
    local phrase = this.validate_phrase(entry, segment, "user_table", input)
    if phrase then table.insert(phrases, phrase) end
  end
  rime.error("phrases: " .. tostring(#phrases) .. "\n")
  if #phrases == 0 then
    if core.sp(this.id) and rime.match(input, "[a-z]{4}") then
      memory:dict_lookup(string.sub(input, 1, 2), false, 1)
      local text = ""
      for entry in memory:iter_dict()
      do
        text = text .. entry.text
        break
      end
      memory:dict_lookup(string.sub(input, 3), false, 1)
      for entry in memory:iter_dict()
      do
        text = text .. entry.text
        break
      end
      local candidate = rime.Candidate("combination", segment.start, segment._end, text, "")
      candidate.preedit = input
      yield(candidate)
    end
    return
  end
  if this.dynamic(input) == dtypes.short then
    local cand = phrases[1]:toCandidate()
    this.known_candidates[cand.text] = 0
    yield(cand)
  elseif this.dynamic(input) == dtypes.base then
    local count = 1
    for _, phrase in ipairs(phrases)
    do
      local cand = phrase:toCandidate()
      if (this.known_candidates[cand.text] or 10) < count then
        goto continue
      end
      if count <= 6 then
        this.known_candidates[cand.text] = count
      end
      yield(cand)
      count = count + 1
      ::continue::
    end
  elseif this.dynamic(input) == dtypes.select then
    local last = string.sub(input, -1)
    local order = string.find(env.engine.schema.select_keys, last)
    for _, phrase in ipairs(phrases)
    do
      local cand = phrase:toCandidate()
      if this.known_candidates[cand.text] == order then
        yield(cand)
        break
      end
    end
  elseif this.dynamic(input) == dtypes.full then
    for _, phrase in ipairs(phrases)
    do
      local cand = phrase:toCandidate()
      if this.known_candidates[cand.text] then
        goto continue
      end
      yield(cand)
      ::continue::
    end
  end
end

return this
