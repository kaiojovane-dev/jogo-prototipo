-- Gerador aleatório com semente (mulberry32), idêntico no cliente e no servidor.
local Random = {}
Random.__index = Random

local M32 = 0xFFFFFFFF

local function imul(a, b)
  return (a * b) & M32
end

function Random.new(seed)
  return setmetatable({ s = math.floor(seed or 1) & M32 }, Random)
end

-- número em [0, 1)
function Random:next()
  self.s = (self.s + 0x6D2B79F5) & M32
  local t = self.s
  t = imul(t ~ (t >> 15), t | 1)
  t = t ~ ((t + imul(t ~ (t >> 7), t | 61)) & M32)
  return ((t ~ (t >> 14)) & M32) / 4294967296
end

-- inteiro em [1, n]
function Random:int(n)
  return math.floor(self:next() * n) + 1
end

function Random:pick(list)
  return list[self:int(#list)]
end

return Random
