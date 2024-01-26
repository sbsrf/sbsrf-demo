-- Name: hint_forward.lua
-- 名称: 在 s, sb, ss 格式上提示数选字词
-- Version: 20240123
-- Author: 蓝落萧

local rime = require "rime"
local core = require "sbxlm.core"

local this = {}

---@param env Env
function this.init(env)
	this.memory = rime.Memory(env.engine, env.engine.schema)
end

---@param translation Translation
---@param env Env
function this.func(translation, env)
	local is_enhanced = env.engine.context:get_option("is_enhanced")
	local id = env.engine.schema.schema_id
	-- 测试是否为声笔飞系方案
	local is_feixi = core.feixi(id)
	local hint_n1 = { '2', '3', '7', '8', '9' }
	local hint_n2 = { '1', '4', '5', '6', '0' }
	local hint_b = { "a", "e", "u", "i", "o" }
	local i = 1
	local memory = this.memory
	for cand in translation:iter() do
		local input = cand.preedit
		if i > 1 then
			rime.yield(cand)
			goto continue
		end
		-- ss 格式输入，需要提示 ss_ 格式编码
		if core.ss(input) and is_feixi then
			memory:dict_lookup(cand.preedit .. "_", false, 1)
			for dictentry in memory:iter_dict()
			do
				cand:get_genuine().comment = dictentry.text
				break
			end
		end
		rime.yield(cand)
		-- 一般的情况，分为 23789, 14560 三组处理
		if (core.s(input) or core.sb(input) or core.ss(input) or core.sxb(input)) and is_enhanced then
			for j = 1, #hint_n1 do
				local n1 = hint_n1[j]
				local n2 = hint_n2[j]
				memory:dict_lookup(cand.preedit .. n1, false, 1)
				local entry_n1 = nil
				for entry in memory:iter_dict() do
					entry_n1 = entry
					break
				end
				if not entry_n1 then
					goto continue
				end
				memory:dict_lookup(cand.preedit .. n2, false, 1)
				local entry_n2 = nil
				for entry in memory:iter_dict() do
					entry_n2 = entry
					break
				end
				local comment = n1
				if entry_n2 then
					comment = comment .. entry_n2.text .. n2
				end
				local forward = rime.Candidate("hint", cand.start, cand._end, entry_n1.text, comment)
				rime.yield(forward)
				::continue::
			end
		end
		-- sb, s?sb
		if ((core.s(input) or core.sxs(input)) and is_feixi) or rime.match(input, "[bpmfdtnlgkhjqxzcsrywv][a-z]?[0123456789]") then
			for j = 1, #hint_b do
				local s = string.sub(cand.preedit, -1)
				local c = hint_b[j]
				-- hack，假设 UTF-8 编码都是 3 字节的
				local prev_text = string.sub(cand.text, 1, -4)
				memory:dict_lookup(s .. c, false, 1)
				for dictentry in memory:iter_dict()
				do
					local forward = rime.Candidate("hint", cand.start, cand._end, prev_text .. dictentry.text, c)
					rime.yield(forward)
					break
				end
			end
		end
		::continue::
		i = i + 1
	end
end

return this
