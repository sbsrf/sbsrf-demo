-- Name: hint.lua
-- 名称: 提示数选字词、声笔字、缩减码
-- Version: 20240123
-- Author: 戴石麟、蓝落萧

local rime = require "rime"
local core = require "sbxlm.core"

local this = {}

---@param env Env
function this.init(env)
	this.memory = rime.Memory(env.engine, env.engine.schema)
	local id = env.engine.schema.schema_id
	local dict_name = id == "sbfd" and "sbfm" or id
	this.reverse = rime.ReverseLookup(dict_name)
end

---@param translation Translation
---@param env Env
function this.func(translation, env)
	local is_enhanced = env.engine.context:get_option("is_enhanced")
	local id = env.engine.schema.schema_id
	local hint_n1 = { '2', '3', '7', '8', '9' }
	local hint_n2 = { '1', '4', '5', '6', '0' }
	local hint_b = { "a", "e", "u", "i", "o" }
	local i = 1
	local memory = this.memory
	for candidate in translation:iter() do
		local input = candidate.preedit
		if core.feixi(id) and rime.match(input, "[bpmfdtnlgkhjqxzcsrywv]{2}[aeuio]{2,}") then
			local codes = this.reverse:lookup(candidate.text)
			for code in string.gmatch(codes, "[^ ]+") do
				if rime.match(code, "[bpmfdtnlgkhjqxzcsrywv][aeiou]{2,}") then
					candidate.comment = candidate.comment .. " " .. code
				end
			end
		end
		if i > 1 then
			rime.yield(candidate)
			goto continue
		end
		-- ss 格式输入，需要提示 ss_ 格式编码
		if core.ss(input) and core.feixi(id) then
			memory:dict_lookup(candidate.preedit .. "_", false, 1)
			for dictentry in memory:iter_dict()
			do
				candidate:get_genuine().comment = dictentry.text
				break
			end
		end
		rime.yield(candidate)
		-- 一般的情况，分为 23789, 14560 三组处理
		if (core.s(input) or core.sb(input) or core.ss(input) or core.sxb(input)) and is_enhanced then
			for j = 1, #hint_n1 do
				local n1 = hint_n1[j]
				local n2 = hint_n2[j]
				memory:dict_lookup(candidate.preedit .. n1, false, 1)
				local entry_n1 = nil
				for entry in memory:iter_dict() do
					entry_n1 = entry
					break
				end
				if not entry_n1 then
					goto continue
				end
				memory:dict_lookup(candidate.preedit .. n2, false, 1)
				local entry_n2 = nil
				for entry in memory:iter_dict() do
					entry_n2 = entry
					break
				end
				local comment = n1
				if entry_n2 then
					comment = comment .. entry_n2.text .. n2
				end
				local forward = rime.Candidate("hint", candidate.start, candidate._end, entry_n1.text, comment)
				rime.yield(forward)
				::continue::
			end
		end
		-- 在 s 和 sxs 码位上，提示声笔字
		-- 对于飞系，所有 sb 都提示
		-- 对于小鹤和自然，只有几个 sb 格式的编码是真正的声笔字，通过声韵拼合规律判断出来
		if ((core.s(input) or core.sxs(input)) and (core.feixi(id) or core.sp(id)))
				or rime.match(input, "[bpmfdtnlgkhjqxzcsrywv][a-z]?[0123456789]") then
			for _, bihua in ipairs(hint_b) do
				local shengmu = string.sub(candidate.preedit, -1)
				-- hack，假设 UTF-8 编码都是 3 字节的
				local prev_text = string.sub(candidate.text, 1, -4)
				if core.sp(id) and not core.invalid_pinyin(shengmu .. bihua) then
					goto continue
				end
				memory:dict_lookup(shengmu .. bihua, false, 1)
				for entry in memory:iter_dict() do
					local forward = rime.Candidate("hint", candidate.start, candidate._end, prev_text .. entry.text, bihua)
					rime.yield(forward)
					break
				end
				::continue::
			end
		end
		::continue::
		i = i + 1
	end
end

return this
