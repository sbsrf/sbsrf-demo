local rime = require "rime"
local match = rime.match
local core = {}

local s = "[bpmfdtnlgkhjqxzcsrywv]";
local p = "[bpmfdtnlgkhjqxzcsrywv]";
local b = "[aeiou]";
local x = "[a-z]";

---@param input string
function core.s(input)
  return match(input, s)
end

---@param input string
function core.ss(input)
  return match(input, s .. s)
end

---@param input string
function core.sb(input)
  return match(input, s .. b)
end

---@param input string
function core.sxb(input)
  return match(input, s .. x .. b)
end

---@param input string
function core.spbb(input)
  return match(input, s .. p .. b .. b)
end

---@param input string
function core.sss(input)
  return match(input, s .. s .. s)
end

---@param input string
function core.sxs(input)
  return match(input, s .. x .. s)
end

---@param input string
function core.sbsb(input)
  return match(input, s .. b .. s .. b)
end

---@param input string
function core.sxsb(input)
  return match(input, s .. x .. s .. b)
end

---@param input string
function core.ssss(input)
  return match(input, s .. s .. s .. s)
end

---@param id string
function core.feixi(id)
  return id == "sbfd" or id == "sbfm" or id == "sbfx"
end

---@param id string
function core.jm(id)
  return id == "sbjm"
end

---@param id string
function core.fm(id)
  return id == "sbfm"
end

---@param id string
function core.fd(id)
  return id == "sbfd"
end

---@param id string
function core.fx(id)
  return id == "sbfx"
end

---@param id string
function core.sp(id)
  return id == "sbzr" or id == "sbxh"
end

---@param sb string
function core.invalid_pinyin(sb)
  for _, value in ipairs({ "[bpfw]e", "[gkhfwv]i", "[jqx][aoe]", "ra", "vu" }) do
    if match(sb, value) then
      return true
    end
  end
  return false
end

---@param code string[]
---@param id string
function core.word_rules(code, id)
  local base = ""
  local jm = core.jm(id)
  local fm = core.fm(id)
  local sp = core.sp(id)
  local fx = core.fx(id)
  if #code == 2 then
    if jm then           -- s1s2b2b2
      base = string.sub(code[1], 1, 1) .. string.sub(code[2], 1, 3)
    elseif fm or sp then -- s1z1s2z2
      base = string.sub(code[1], 1, 2) .. string.sub(code[2], 1, 2)
    elseif fx then       -- s1z1s2b2b2
      base = string.sub(code[1], 1, 2) .. string.sub(code[2], 1, 1) .. string.sub(code[2], 3, 4)
    end
  else
    base = string.sub(code[1], 1, 1) .. string.sub(code[2], 1, 1) .. string.sub(code[3], 1, 1)
    if #code == 3 then
      if jm or fm or sp then -- s1s2s3z3
        base = base .. string.sub(code[3], 2, 2)
      elseif fx then         -- s1s2s3b3b3
        base = base .. string.sub(code[3], 3, 4)
      end
    elseif #code >= 4 then
      if jm then           -- s1s2s3b0
        base = base .. string.sub(code[#code], 2, 2)
      elseif fm or sp then -- s1s2s3s0
        base = base .. string.sub(code[#code], 1, 1)
      elseif fx then       -- s1s2s3b0b0
        base = base .. string.sub(code[#code], 3, 4)
      end
    else
      return nil
    end
  end
  -- 扩展编码为首字前两笔，但是这个笔在不同方案中有不同的取法
  local extended = ""
  if jm then
    extended = string.sub(code[1], 2, 3)
  elseif fm or fx or sp then
    extended = string.sub(code[1], 3, 4)
  end
  local full = base .. extended
  if (jm or fx) and #code >= 4 then
    -- 简码和飞讯，增加一个取末字声母的选项
    full = full .. "'" .. string.sub(code[#code], 1, 1)
  end
  return full
end

return core
