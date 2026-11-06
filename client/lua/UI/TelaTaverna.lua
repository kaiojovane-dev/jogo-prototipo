-- Taverna (recrutamento): banner, chances, garantia de SSR e animação de revelação das cartas.
local K, U, D, Estado, Formula = G.K, G.U, G.D, G.Estado, G.Formula
local C = G.camadas
local M = {}

M.taverna = {}
local tv = {}

-- sequenciador simples de passos com espera (animações encadeadas)
local fila = {}
local function passo(espera, fn) fila[#fila + 1] = { espera, fn } end

local function chances()
  local r = {}
  for _, x in ipairs(D.Raridade) do r[x.raridade] = x.chance end
  return r
end

local function pct(v)
  local s = string.format('%.1f', v * 100):gsub('%.0$', '')
  return s .. '%'
end

local function cartaRevelada(p, r, x, y, w, h)
  local def = D.Herois[r.id]
  local cor = G.RAR[r.rar]
  local c = U.img(p, 'skin:card', x, y, w, h, cor)
  U.img(c, 'skin:card', 0, 0, w - 12, h - 12, '#16305a')
  local brilho = U.img(c, 'brilho', 0, 20, w * 1.3, w * 1.3, cor .. '88')
  if r.rar == 'SSR' then K.Spin(brilho, 30) end
  local lado = math.min(w * 0.92, h * 0.74)
  U.img(c, G.arteRetrato(r.id), 0, 22, lado, lado)
  U.txt(c, r.rar, math.floor(w * 0.16), 0, -24, w, 44, cor, 'C', true, 0.5, 1)
  local faixa = U.img(c, 'skin:escuro', 0, 26, w - 18, 52, '#ffffff', 0.5, 0)
  U.txt(faixa, G.curto(def.nome), math.floor(w * 0.13), 0, 0, w - 20, 50, '#ffffff', 'C', true)
  if r.novo then
    local n = U.img(c, 'skin:vermelho', 0, -70, w * 0.6, 44, '#ffffff', 0.5, 1)
    U.txt(n, 'NOVO!', 26, 0, 1, w * 0.6, 42, '#ffffff', 'C', true)
    K.Breath(n, 0.06, 0.8)
  else
    U.txt(c, '+' .. r.frag .. ' fragmentos', 22, 0, 90, w, 36, '#c77dff', 'C', true, 0.5, 0)
  end
  return c
end

-- apresentação especial do SSR
local function cutinSSR(id)
  local W = K.W()
  local def = D.Herois[id]
  local box = U.img(C.efeito, '', 0, 0, K.WTela() + 400, K.HTela() + 400, '#000000dd')
  K.SetRaycast(box, true)
  local raio = U.img(box, 'brilho', -W * 0.15, 0, 1400, 1400, '#ffb70388')
  K.Spin(raio, 25)
  local faixa = U.img(box, '', 0, -20, W + 200, 300, G.EL[def.elemento].cor .. '55')
  K.SetRot(faixa, -6)
  local arte = U.img(box, G.arteHeroi(id), -W / 2 - 400, -20, 700, 960)
  K.MoveTo(arte, -W * 0.15, -20, 0.45, 3, nil)
  local nome = U.txt(box, def.nome, 84, W / 2 + 600, 80, 1000, 110, '#ffd166', 'C', true)
  K.MoveTo(nome, W * 0.22, 80, 0.45, 1, nil)
  local tit = U.txt(box, def.titulo, 40, W * 0.22, -10, 1000, 60, '#ffffff', 'C', true)
  K.SetAlpha(tit, 0); K.FadeTo(tit, 1, 0.6, nil)
  local fala = U.txt(box, '"' .. def.fala .. '"', 34, W * 0.22, -110, 900, 120, '#cfe2ff', 'C', true)
  K.SetAlpha(fala, 0); K.FadeTo(fala, 1, 0.9, nil)
  U.txt(box, 'SSR', 150, W * 0.22, 250, 600, 180, '#ffb703', 'C', true)
  K.Flash('#ffd166ee', 0.6)
  K.Som('ssr')
  K.Burst(box, -W * 0.15, 0, 60, '#ffd166', 900, 30, 1.4, 200)
  return box
end

local function revelar(res, qtd)
  local W = K.W()
  local melhor = 'R'
  for _, r in ipairs(res) do
    if r.rar == 'SSR' then melhor = 'SSR' elseif r.rar == 'SR' and melhor ~= 'SSR' then melhor = 'SR' end
  end
  local ov = U.img(C.modal, '', 0, 0, K.WTela() + 400, K.HTela() + 400, '#030812ee')
  local util = U.box(ov, 0, 0, K.W(), K.H())   -- área útil: os botões presos embaixo ficam na tela
  K.SetRaycast(ov, true)
  tv.ov = ov
  local bau = U.img(ov, 'ic_bau', 0, 0, 360, 360)
  local luz = U.img(ov, 'brilho', 0, 0, 800, 800, G.RAR[melhor] .. '00')
  K.Front(bau)
  K.Som('abrir')
  K.Shake(bau, 14, 1.0)
  K.Spin(luz, 40)
  passo(0.35, function() K.SetColor(luz, G.RAR[melhor] .. '66'); K.Shake(bau, 22, 0.7) end)
  passo(0.7, function()
    K.Flash(G.RAR[melhor] .. 'dd', 0.5)
    K.Burst(ov, 0, 0, 70, G.RAR[melhor], 1100, 34, 1.2, 300)
    K.Ring(ov, 0, 0, '#ffffff', 1200, 0.6)
    K.Kill(bau); K.Kill(luz)
  end)
  -- cartas
  local cw, ch = qtd == 1 and 380 or 250, qtd == 1 and 500 or 330
  for i, r in ipairs(res) do
    local x, y = 0, 20
    if qtd > 1 then
      local col, lin = (i - 1) % 5, (i - 1) // 5
      x, y = (col - 2) * (cw + 30), 190 - lin * (ch + 30)
    end
    if r.rar == 'SSR' then
      local box
      passo(0.25, function() box = cutinSSR(r.id) end)
      passo(2.4, function() if K.Alive(box) then K.FadeTo(box, 0, 0.25, function() K.Kill(box) end) end end)
    end
    passo(qtd == 1 and 0.2 or 0.12, function()
      local c = cartaRevelada(ov, r, x, y, cw, ch)
      K.SetScale(c, 0.05, 0.05)
      K.ScaleTo(c, 1, 0.3, 3, nil)
      K.Ring(ov, x, y, G.RAR[r.rar], cw * 2.2, 0.5)
      if r.rar ~= 'R' then K.Burst(ov, x, y, 24, G.RAR[r.rar], 600, 22, 0.8, 0) end
      K.Som(r.rar == 'R' and 'toque' or 'moeda')
    end)
  end
  passo(0.35, function()
    local rod = U.box(util, 0, 150, 900, 120, 0.5, 0)
    U.btn(rod, 'azul', 'OK', 40, -220, 0, 360, 104, function() K.Kill(ov); tv.ov = nil; M.taverna.atualizar() end)
    U.btn(rod, 'ouro', 'Recrutar ' .. qtd .. ' de novo', 34, 220, 0, 380, 104, function()
      K.Kill(ov); tv.ov = nil; M.recrutar(qtd)
    end)
    G.atualizarTopo()
  end)
end

function M.recrutar(qtd)
  if tv.ov then return end
  local res = Estado.recrutar(qtd)
  if not res then G.toast('Gemas insuficientes. Vença chefes, complete missões e entre todo dia.', '#ff8a7a'); return end
  G.atualizarTopo()
  revelar(res, qtd)
end

function M.taverna.atualizar()
  if not tv.garantia or not K.Alive(tv.garantia) then return end
  local s, P = Estado.s, D.Param
  local falta = P.gacha_garantia - s.gacha.semSSR
  K.SetText(tv.garantia, 'SSR garantido em <color=#ffb703>' .. falta .. '</color> recrutamentos')
  K.SetBar(tv.barra, s.gacha.semSSR / P.gacha_garantia)
  G.atualizarTopo()
end

function M.taverna.abrir()
  G.topo(true, 'navio', 'Taverna')
  local W = K.W()
  local Cenario = require('UI.Cenario')
  tv.cen = Cenario.montar(C.fundo, 'noite', { horizonte = 600, chao = false })
  U.img(C.fundo, '', 0, 0, K.WTela() + 200, K.HTela() + 200, '#1a0c05aa')
  for _, x in ipairs({ -W / 2 + 80, W / 2 - 80 }) do
    local l = U.img(C.fundo, 'brilho', x, 300, 520, 520, '#ffb04788')
    K.Breath(l, 0.08, 2.6)
  end
  local ch = chances()

  -- banner
  local bx = -W / 2 + W * 0.25
  local ban = U.painel(C.tela, bx, -10, 820, 800, 'painel')
  local cab = U.painel(ban, 0, -6, 600, 90, 'ouro', 0.5, 1)
  U.txt(cab, 'Lendas do Mar', 46, 0, 2, 580, 86, '#3b2300', 'C', false)
  local clip = K.Clip(ban, 0, 40, 780, 560, 0.5, 0.5)
  U.img(clip, 'brilho', 0, 0, 900, 900, '#ffb70355')
  local destaque = {}
  for _, id in ipairs(D.Herois._ordem) do if D.Herois[id].raridade == 'SSR' then destaque[#destaque + 1] = id end end
  for i, id in ipairs(destaque) do
    local x = (i - (#destaque + 1) / 2) * 230
    local a = U.img(clip, G.arteHeroi(id), x, -40, 420, 600)
    K.Breath(a, 0.02, 2 + i * 0.3)
    if i == 2 then K.Front(a) end
  end
  U.txt(ban, 'Heróis SSR em destaque: ' .. #destaque, 28, 0, 150, 760, 40, '#ffd166', 'C', true, 0.5, 0)
  U.txt(ban, 'SSR ' .. pct(ch.SSR) .. '   SR ' .. pct(ch.SR) .. '   R ' .. pct(ch.R), 30, 0, 100, 760, 40, '#ffffff', 'C', true, 0.5, 0)
  U.btn(ban, 'azul', 'Chances e heróis', 26, 0, 46, 320, 64, function() M.modalChances() end, 0.5, 0)

  -- baú e botões
  local cx = W * 0.22
  local raios = U.img(C.tela, 'brilho', cx, 110, 760, 760, '#ffd16677')
  K.Spin(raios, 14)
  local bau = U.img(C.tela, 'ic_bau', cx, 110, 360, 360)
  K.Bob(bau, 10, 2.6)
  tv.garantia = U.txt(C.tela, '', 32, cx, -150, 800, 50, '#ffffff', 'C', true)
  tv.barra = U.bar(C.tela, cx, -200, 560, 22, '#1b1a2e', '#ffb703')
  local b1 = U.btn(C.tela, 'azul', '', 10, cx - 220, -330, 400, 150, function() M.recrutar(1) end)
  U.txt(b1, 'Recrutar 1', 40, 0, 26, 380, 50, '#ffffff', 'C', true)
  U.img(b1, 'ic_gema', -50, -32, 48, 48)
  U.txt(b1, tostring(D.Param.gacha_custo1), 32, 30, -32, 120, 44, '#9bf6ff', 'L', true)
  local b10 = U.btn(C.tela, 'ouro', '', 10, cx + 220, -330, 400, 150, function() M.recrutar(10) end)
  U.txt(b10, 'Recrutar 10', 40, 0, 30, 380, 50, '#3b2300', 'C', false)
  U.img(b10, 'ic_gema', -50, -22, 48, 48)
  U.txt(b10, tostring(D.Param.gacha_custo10), 32, 30, -22, 120, 44, '#1f4b7a', 'L', false)
  U.txt(b10, '1 SR ou melhor garantido', 20, 0, -56, 380, 30, '#5a3800', 'C', false)
  K.Breath(b10, 0.025, 1.4)
  M.taverna.atualizar()
end

function M.modalChances()
  local ch = chances()
  G.modal('Chances de Recrutamento', 1300, 760, function(p)
    U.txt(p, 'A cada ' .. D.Param.gacha_garantia .. ' recrutamentos sem SSR, o próximo é SSR. Repetidos viram fragmentos para evoluir estrelas.', 26, 0, 250, 1180, 70, '#cfe2ff', 'C', false)
    local y = 140
    for _, rar in ipairs({ 'SSR', 'SR', 'R' }) do
      U.txt(p, rar .. '  ' .. pct(ch[rar]), 36, -500, y, 220, 50, G.RAR[rar], 'L', true)
      local x = -320
      for _, id in ipairs(D.Herois._ordem) do
        if D.Herois[id].raridade == rar then
          local c = U.painel(p, x, y, 130, 130, 'card')
          K.SetColor(c, G.RAR[rar])
          U.img(c, 'skin:card', 0, 0, 120, 120, '#16305a')
          local cl = K.Clip(c, 0, 0, 116, 116, 0.5, 0.5)
          U.img(cl, G.arteRetrato(id), 0, 0, 120, 120)
          U.txt(c, G.curto(D.Herois[id].nome), 22, 0, -58, 160, 30, '#ffffff', 'C', true)
          x = x + 160
        end
      end
      y = y - 170
    end
  end, { { 'Fechar', 'azul' } })
end

function M.taverna.update(dt)
  if tv.cen then require('UI.Cenario').atualizarClima(tv.cen, C.tela, dt) end
  if #fila > 0 then
    fila[1][1] = fila[1][1] - dt
    while #fila > 0 and fila[1][1] <= 0 do
      local f = table.remove(fila, 1)
      local ok, err = pcall(f[2])
      if not ok then K.Log('taverna: ' .. tostring(err)) end
      if #fila > 0 then fila[1][1] = fila[1][1] + math.min(0, f[1]) end
    end
  end
end

function M.taverna.fechar()
  tv.cen = nil
  fila = {}
  if tv.ov then K.Kill(tv.ov); tv.ov = nil end
end

return M
