"""Confere a Maré Negra do motor de produção (shared/lua/Game/Battle.lua) contra o T0.

A luta do T0 (fase 1-10, Barba-Sal, time Pipo/Marina/Lina/Bento/Mirto, 1 estrela, 40 sementes do sim.py)
precisa dar as mesmas taxas de vitória que prototypes/t0-chefe-concept/results.md registrou para a variante V2:
Auto (solta ao encher) e jogador atento (0,3 s de reação, guarda o atordoamento para a carga, cura abaixo de 55%).

Uso, da raiz do repositório:  py -3.14 tools/testes/testar_mare_negra.py
"""
import os, sys
from lupa import LuaRuntime

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
SHARED = os.path.join(RAIZ, 'shared', 'lua').replace('\\', '/')

# taxas do T0 (results.md, coluna V2) por nível: (auto, atento)
ESPERADO = {5: (8, 0), 6: (30, 52), 7: (58, 98), 8: (78, 100), 9: (82, 100), 10: (85, 100), 12: (95, 100)}

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('package.path = "%s/?.lua;" .. package.path' % SHARED)
rodar = lua.execute('''
local data = {}
for _, n in ipairs({ 'Param', 'Herois', 'Skills', 'Inimigos', 'Ilhas', 'Raridade' }) do data[n] = require('Data.' .. n .. 'Data') end
local Formula = require('Game.Formula'); Formula.init(data)
local Battle = require('Game.Battle')
local TIME = { 'pipo', 'marina', 'lina', 'bento', 'mirto' }

local function atento(b)
  local chefe = b.chefeU
  local vivo = chefe and chefe.vivo
  local fase, idade = b:faseChefe()
  local menor = 1
  for _, a in ipairs(b:vivos('a')) do menor = math.min(menor, a.hp / a.max) end
  for _, u in ipairs(b:vivos('a')) do
    local ult = u.ult
    if ult and u.furia >= 100 and u.atord <= 0 then
      local soltar
      if not vivo then soltar = true
      elseif ult.tipo == 'cura' then soltar = menor < 0.55
      elseif ult.efeito == 'atordoar' then soltar = fase == 'carga' and idade >= 0.3
      else soltar = true end
      if soltar then b:pedirEspecial(u.guid) end
    end
  end
end

return function(politica, nivel)
  local v = 0
  for s = 1, 40 do
    local eq = {}
    for i, id in ipairs(TIME) do eq[i] = { slot = i, id = id, nivel = nivel, estrelas = 1 } end
    local b = Battle.new(data, 9, eq, s * 7919)
    b.autoJogador = (politica == 'auto')
    while not b.fim do
      if politica == 'atento' then atento(b) end
      b:passo()
      b:consumirEventos()
    end
    if b.fim.venceu then v = v + 1 end
  end
  return v
end
''')


def arred(x):  # como o '%3.0f' do Python usado no T0 (metade para o par)
    return round(x)


falhas = 0
for nivel, (ea, em) in sorted(ESPERADO.items()):
    a, m = arred(rodar('auto', nivel) * 2.5), arred(rodar('atento', nivel) * 2.5)
    ok = (a, m) == (ea, em)
    falhas += 0 if ok else 1
    print('nivel %2d  auto %3d (T0 %3d)  atento %3d (T0 %3d)  %s' % (nivel, a, ea, m, em, 'igual' if ok else 'DIFERENTE'))
print('OK: a Maré Negra de produção bate com o T0' if falhas == 0 else 'FALHOU: %d níveis diferentes' % falhas)
sys.exit(1 if falhas else 0)
