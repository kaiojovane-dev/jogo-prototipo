"""Roda o motor de batalha compartilhado (shared/lua) num Lua 5.4 embutido, sem Unity.
Uso: py -3.14 tools/testes/testar_batalha.py"""
import os
from lupa.lua54 import LuaRuntime

RAIZ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'shared', 'lua')).replace(os.sep, '/')

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('package.path = "' + RAIZ + '/?.lua;" .. package.path')

SCRIPT = r'''
local data = {}
for _, n in ipairs({'Param', 'Herois', 'Skills', 'Inimigos', 'Ilhas', 'Raridade'}) do data[n] = require('Data.' .. n .. 'Data') end
local Formula = require('Game.Formula'); Formula.init(data)
local Battle = require('Game.Battle')
local base = {'pipo', 'marina', 'lina', 'bento', 'mirto'}
local function equipe(nivel, estrelas)
  local e = {}
  for i, id in ipairs(base) do e[i] = {slot = i, id = id, nivel = nivel, estrelas = estrelas} end
  return e
end
local out = {}
for _, caso in ipairs({{0, 1, 1}, {4, 3, 1}, {9, 8, 1}, {14, 14, 2}, {19, 22, 2}, {24, 30, 3}, {29, 38, 3}}) do
  local fase, nivel, est = caso[1], caso[2], caso[3]
  local r = Battle.new(data, fase, equipe(nivel, est), 12345):simular()
  local r2 = Battle.new(data, fase, equipe(nivel, est), 12345):simular()
  local vit = 0
  for s = 1, 40 do if Battle.new(data, fase, equipe(nivel, est), s * 7919):simular().venceu then vit = vit + 1 end end
  out[#out + 1] = string.format('fase %2d  time nv%2d %d*  vitorias %2d/40  tempo %5.1fs  deterministico=%s',
    fase + 1, nivel, est, vit, r.tempo, tostring(r.tempo == r2.tempo and r.estrelas == r2.estrelas))
end
return table.concat(out, '\n')
'''

print(lua.execute(SCRIPT))
