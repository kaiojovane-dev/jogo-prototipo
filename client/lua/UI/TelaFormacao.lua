-- Formação: 2 posições na frente e 3 atrás, no mesmo arranjo da batalha. Toque numa posição e depois num herói.
local K, U, D, Estado, Formula = G.K, G.U, G.D, G.Estado, G.Formula
local C = G.camadas
local M = {}

M.formacao = {}
local fm = {}

local function slotPos(slot)
  local cx = -K.W() / 4 + 40
  local P = {
    { cx + 230, 130 }, { cx + 230, -160 },
    { cx - 190, 240 }, { cx - 190, -20 }, { cx - 190, -280 },
  }
  return P[slot][1], P[slot][2]
end

local function primeiraVaga()
  for i = 1, 5 do if Estado.s.formacao[i] == '' then return i end end
  return nil
end

local montar

local function colocar(id)
  local f = Estado.s.formacao
  local atual = nil
  for i = 1, 5 do if f[i] == id then atual = i end end
  local sel = fm.sel or primeiraVaga() or 1
  if atual == sel then return end
  if atual then f[atual], f[sel] = f[sel], f[atual] else f[sel] = id end
  K.Som('toque')
  fm.sel = primeiraVaga()
  Estado.salvar()
  montar()
  local x, y = slotPos(sel)
  K.Ring(C.efeito, x, y, '#7cf29a', 380, 0.4)
end

local function tocarSlot(i)
  local f = Estado.s.formacao
  if fm.sel == i and f[i] ~= '' then
    local n = 0
    for k = 1, 5 do if f[k] ~= '' then n = n + 1 end end
    if n <= 1 then G.toast('A equipe precisa de pelo menos um herói.'); return end
    f[i] = ''
    Estado.salvar()
  else
    fm.sel = i
  end
  montar()
end

local function auto()
  local donos = {}
  for id in pairs(Estado.s.herois) do donos[#donos + 1] = id end
  table.sort(donos, function(a, b) return Estado.poderHeroi(a) > Estado.poderHeroi(b) end)
  local top = {}
  for i = 1, math.min(5, #donos) do top[i] = donos[i] end
  -- frente: quem é da linha da frente (ou mais vida); trás: o resto
  table.sort(top, function(a, b)
    local fa, fb = D.Herois[a].linha == 'frente', D.Herois[b].linha == 'frente'
    if fa ~= fb then return fa end
    return Estado.atributos(a).hp > Estado.atributos(b).hp
  end)
  local f = { '', '', '', '', '' }
  for i, id in ipairs(top) do f[i] = id end
  Estado.s.formacao = f
  Estado.salvar()
  fm.sel = primeiraVaga()
  K.Som('nivel')
  montar()
end

montar = function()
  K.Clear(C.tela)
  local W = K.W()
  local f = Estado.s.formacao
  -- rótulos de linha
  local x1 = slotPos(1)
  local x3 = slotPos(3)
  U.txt(C.tela, 'TRÁS', 34, x3, 396, 300, 50, '#9fb3c8', 'C', true)
  U.txt(C.tela, 'FRENTE  >>', 34, x1, 300, 300, 50, '#ffd166', 'C', true)
  for i = 1, 5 do
    local x, y = slotPos(i)
    local id = f[i]
    local sel = fm.sel == i
    if sel then
      local fx = U.img(C.tela, 'skin:ouro', x, y, 262, 262, '#ffffff')
      K.Breath(fx, 0.03, 0.9)
    end
    local b = U.btn(C.tela, id ~= '' and 'card' or 'vidro', '', 10, x, y, 240, 240, function() tocarSlot(i) end)
    if id ~= '' then
      local def = D.Herois[id]
      K.SetColor(b, G.RAR[def.raridade])
      local dentro = U.img(b, 'skin:card', 0, 0, 228, 228, '#16305a')
      U.img(b, 'brilho', 0, 10, 260, 260, G.EL[def.elemento].cor .. '55')
      local a = U.img(b, G.arteRetrato(id), 0, 16, 212, 212)
      K.Breath(a, 0.02, 1.8 + i * 0.1)
      local faixa = U.img(b, 'skin:escuro', 0, 24, 224, 46, '#ffffff', 0.5, 0)
      U.txt(faixa, G.curto(def.nome) .. '  Nv ' .. Estado.s.herois[id].nivel, 22, 0, 0, 220, 44, '#ffffff', 'C', true)
      U.img(b, 'skin:circulo', -22, -22, 32, 32, G.EL[def.elemento].cor, 1, 1)
      if sel then U.txt(b, 'tocar de novo\npara tirar', 20, 0, -10, 220, 60, '#ffd166', 'C', true, 0.5, 1) end
    else
      U.txt(b, '+', 90, 0, 10, 200, 120, '#ffffff88', 'C', false)
      U.txt(b, 'Posição ' .. i, 24, 0, -70, 220, 40, '#cfe2ff', 'C', false)
    end
  end
  -- lista de heróis
  local px = W / 4 + 20
  local painel = U.painel(C.tela, px, 30, 820, 740, 'painel')
  U.txt(painel, 'Toque numa posição e depois num herói', 26, 0, -40, 780, 40, '#cfe2ff', 'C', false, 0.5, 1)
  local donos = {}
  for _, id in ipairs(require('UI.TelaTripulacao').ordenados()) do if Estado.s.herois[id] then donos[#donos + 1] = id end end
  local cw, ch, gap, cols = 230, 290, 20, 3
  local linhas = math.ceil(#donos / cols)
  local cont = K.Scroll(painel, 0, -30, 780, 620, 780, linhas * (ch + gap) + 20, true, 0.5, 0.5)
  for i, id in ipairs(donos) do
    local col, lin = (i - 1) % cols, (i - 1) // cols
    local x = 30 + cw / 2 + col * (cw + gap)
    local y = -(10 + ch / 2 + lin * (ch + gap))
    local c = G.carta(cont, id, x, y, cw, ch, function() colocar(id) end, 0, 1)
    for k = 1, 5 do
      if f[k] == id then
        local t = U.img(c, 'skin:verde', 0, 104, 170, 40, '#ffffff', 0.5, 0)
        U.txt(t, 'Na equipe', 22, 0, 1, 160, 38, '#ffffff', 'C', true)
      end
    end
  end
  -- rodapé: poder e sinergia
  local rod = U.img(C.tela, 'skin:escuro', 0, 70, W - 120, 120, '#ffffff', 0.5, 0)
  U.img(rod, 'ic_poder', 90, 0, 70, 70, '#ffffff', 0, 0.5)
  U.txt(rod, 'Poder da equipe  <color=#ffd166>' .. G.fmt(Estado.poderEquipe()) .. '</color>', 36, 420, 0, 620, 60, '#ffffff', 'L', true, 0, 0.5)
  local sin = Formula.sinergia(f)
  local st = sin and ('Sinergia <color=' .. G.EL[sin.elemento].cor .. '>' .. G.EL[sin.elemento].nome .. ' x' .. sin.n .. '</color> +' .. math.floor(sin.bonus * 100) .. '%') or 'Sem sinergia (3+ do mesmo elemento)'
  U.txt(rod, st, 30, 0, 0, 640, 60, '#ffffff', 'C', true)
  U.btn(rod, 'roxo', 'Auto', 34, -420, 0, 200, 90, auto, 1, 0.5)
  U.btn(rod, 'ouro', 'Pronto', 34, -160, 0, 240, 90, function()
    if fm.voltar then
      local n = fm.voltar
      G.ir('aventura')
      G.Telas.preparar(n)
    else
      G.ir('navio')
    end
  end, 1, 0.5)
  G.atualizarTopo()
end

function M.formacao.abrir(arg)
  G.topo(true, 'navio', 'Formação')
  fm.voltar = arg and arg.voltar or nil
  fm.sel = primeiraVaga()
  local W = K.W()
  local Cenario = require('UI.Cenario')
  fm.cen = Cenario.montar(C.fundo, 'farol', { horizonte = 700, chaoAlt = 520 })
  U.img(C.fundo, '', 0, 0, K.WTela() + 200, K.HTela() + 200, '#06122a99')
  montar()
end

function M.formacao.fechar() fm.cen = nil end

return M
