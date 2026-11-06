-- Tripulação: grade de heróis e ficha completa (atributos, nível, estrelas, especial).
local K, U, D, Estado, Formula = G.K, G.U, G.D, G.Estado, G.Formula
local C = G.camadas
local M = {}

local function fundoEscuro()
  local W = K.W()
  local Cenario = require('UI.Cenario')
  local cen = Cenario.montar(C.fundo, 'noite', { horizonte = 620, chao = false })
  U.img(C.fundo, '', 0, 0, K.WTela() + 200, K.HTela() + 200, '#06122acc')
  return cen
end

local function ordenados()
  local lista = {}
  for _, id in ipairs(D.Herois._ordem) do lista[#lista + 1] = id end
  table.sort(lista, function(a, b)
    local ha, hb = Estado.s.herois[a], Estado.s.herois[b]
    if (ha ~= nil) ~= (hb ~= nil) then return ha ~= nil end
    local pa, pb = Estado.poderHeroi(a), Estado.poderHeroi(b)
    if pa ~= pb then return pa > pb end
    return a < b
  end)
  return lista
end
M.ordenados = ordenados

-- ------------------------------------------------------------------ grade
M.tripulacao = {}
local tr = {}

function M.tripulacao.abrir()
  G.topo(true, true, 'Tripulação')
  tr.cen = fundoEscuro()
  local W = K.W()
  local lista = ordenados()
  local donos = 0
  for _ in pairs(Estado.s.herois) do donos = donos + 1 end
  U.txt(C.tela, 'Heróis: ' .. donos .. '/' .. #lista, 32, -280, -160, 400, 50, '#cfe2ff', 'R', true, 1, 1)
  local cw, ch, gap = 250, 330, 22
  local cols = 5
  local larg = cols * cw + (cols - 1) * gap
  for i, id in ipairs(lista) do
    local col, lin = (i - 1) % cols, (i - 1) // cols
    local x = -larg / 2 + cw / 2 + col * (cw + gap)
    local y = 180 - lin * (ch + gap) - 40
    local c = G.carta(C.tela, id, x, y, cw, ch, function()
      if not Estado.s.herois[id] then G.toast('Recrute ' .. D.Herois[id].nome .. ' na Taverna.'); return end
      G.ir('heroi', id)
    end)
    K.SetScale(c, 0.6, 0.6)
    K.After(0.03 * i, function() K.ScaleTo(c, 1, 0.3, 3, nil) end)
    local sin = Estado.s.herois[id]
    if sin then
      local podeNivel = Formula.custoNivel(sin.nivel)
      if Estado.s.ouro >= podeNivel.ouro and Estado.s.xp >= podeNivel.xp and sin.nivel < D.Param.nivel_max then
        local seta = U.img(c, 'skin:circulo', -18, -60, 40, 40, '#2bb673', 1, 1)
        U.txt(seta, '+', 34, 0, 2, 40, 40, '#ffffff', 'C', true)
        K.Bob(seta, 4, 0.9)
      end
    end
  end
  local sin = Formula.sinergia(Estado.s.formacao)
  local txt = 'Sinergia: 3+ heróis do mesmo elemento na formação dão bônus de vida e ataque.'
  if sin then txt = 'Sinergia ativa: <color=' .. G.EL[sin.elemento].cor .. '>' .. G.EL[sin.elemento].nome .. ' x' .. sin.n .. '</color>  (+' .. math.floor(sin.bonus * 100) .. '% vida e ataque)' end
  U.txt(C.tela, txt, 28, 0, 50, 1600, 50, '#ffffff', 'C', true, 0.5, 0)
end

function M.tripulacao.update(dt)
  if tr.cen then require('UI.Cenario').atualizarClima(tr.cen, C.tela, dt) end
end
function M.tripulacao.fechar() tr.cen = nil end

-- ------------------------------------------------------------------ ficha do herói
M.heroi = {}
local hf = {}

local function linhaAtributo(p, y, ic, nome, v, cor)
  U.txt(p, nome, 30, 180, y, 260, 44, '#9fb3c8', 'L', false, 0, 0.5)
  U.txt(p, v, 34, -190, y, 300, 44, cor or '#ffffff', 'R', true, 1, 0.5)
end

local function montarFicha(id)
  K.Clear(C.tela)
  local W = K.W()
  local def = D.Herois[id]
  local st = Estado.s.herois[id]
  local a = Estado.atributos(id)
  local el = G.EL[def.elemento]
  hf.id = id

  -- palco do herói
  local cx = -W / 2 + W * 0.27
  local aura = U.img(C.tela, 'brilho', cx, 10, 900, 900, el.cor .. '77')
  K.Spin(aura, 8)
  local aura2 = U.img(C.tela, 'brilho', cx, 10, 640, 640, G.RAR[def.raridade] .. '66')
  K.Breath(aura2, 0.06, 2.4)
  U.img(C.tela, 'skin:circulo', cx, -330, 420, 80, '#00000066')
  local arte, vivo = U.figura(C.tela, id, cx, 60, 560, 780)
  if not vivo then K.Breath(arte, 0.018, 2.2) end
  -- boneco com esqueleto: tocar faz o herói golpear (e mostrar a física da arma, do cabelo e do lenço)
  local toques = 0
  K.SetClick(arte, function()
    G.toast('"' .. def.fala .. '"')
    if vivo then toques = toques + 1; K.BonecoAnim(arte, toques % 2 == 1 and 'golpe' or 'vitoria', 1) end
  end)
  hf.arte = arte
  hf.cx = cx
  K.SetAlpha(arte, 0); K.FadeTo(arte, 1, 0.25, nil)
  K.SetPos(arte, cx - 60, -60); K.MoveTo(arte, cx, -60, 0.3, 1, nil)

  -- nome e títulos
  local tag = U.painel(C.tela, cx, 330, 640, 130, 'escuro')
  K.SetRaycast(tag, false)
  U.txt(tag, def.nome, 50, 0, 26, 620, 60, '#ffffff', 'C', true)
  U.txt(tag, def.titulo, 28, 0, -30, 620, 40, '#ffd166', 'C', true)
  local rar = U.painel(C.tela, cx - 260, 410, 120, 64, def.raridade == 'SSR' and 'ouro' or (def.raridade == 'SR' and 'roxo' or 'azul'))
  U.txt(rar, def.raridade, 34, 0, 2, 110, 60, def.raridade == 'SSR' and '#3b2300' or '#ffffff', 'C', def.raridade ~= 'SSR')
  G.estrelasImg(C.tela, st.estrelas, 5, cx, -400, 54)

  -- setas para trocar de herói
  local donos = {}
  for _, h in ipairs(M.ordenados()) do if Estado.s.herois[h] then donos[#donos + 1] = h end end
  local pos = 1
  for i, h in ipairs(donos) do if h == id then pos = i end end
  if #donos > 1 then
    U.btn(C.tela, 'azul', '<', 60, cx - 400, -40, 100, 140, function() montarFicha(donos[(pos - 2) % #donos + 1]) end)
    U.btn(C.tela, 'azul', '>', 60, cx + 400, -40, 100, 140, function() montarFicha(donos[pos % #donos + 1]) end)
  end

  -- painel de atributos
  local px = W * 0.22
  local p = U.painel(C.tela, px, 0, 820, 780, 'painel')
  local cab = U.painel(p, 0, -6, 560, 84, 'ouro', 0.5, 1)
  U.txt(cab, 'Nível ' .. st.nivel .. ' / ' .. D.Param.nivel_max, 40, 0, 2, 540, 80, '#3b2300', 'C', false)
  local info = U.box(p, 0, 220, 760, 160)
  U.img(info, 'skin:circulo', 60, 40, 46, 46, el.cor, 0, 0.5)
  U.txt(info, el.nome .. '  -  ' .. def.classe .. '  -  ' .. (def.linha == 'frente' and 'linha da frente' or 'linha de trás'), 30, 425, 40, 640, 44, '#ffffff', 'L', true, 0, 0.5)
  U.img(info, 'ic_poder', 60, -20, 56, 56, '#ffffff', 0, 0.5)
  U.txt(info, 'Poder ' .. G.fmt(Formula.poder(a)), 40, 425, -20, 640, 50, '#ffd166', 'L', true, 0, 0.5)
  local at = U.img(p, 'skin:escuro', 0, 60, 740, 220, '#ffffff')
  linhaAtributo(at, 75, 'ic_poder', 'Vida', G.fmt(a.hp), '#7cf29a')
  linhaAtributo(at, 25, 'ic_espadas', 'Ataque', G.fmt(a.atk), '#ff9f7a')
  linhaAtributo(at, -25, 'ic_poder', 'Defesa', G.fmt(a.def), '#9bd1ff')
  linhaAtributo(at, -75, 'ic_raio', 'Crítico', math.floor(a.crit * 100) .. '%  x' .. a.crit_dmg, '#ffd166')
  -- especial
  local sk = Formula.skill(def.ult)
  local esp = U.img(p, 'skin:vidro', 0, -130, 740, 140, '#ffffff')
  U.img(esp, 'ic_raio', 60, 0, 80, 80, '#ffffff', 0, 0.5)
  U.txt(esp, 'Especial: ' .. sk.nome, 30, 440, 34, 640, 40, '#ffd166', 'L', true, 0, 0.5)
  U.txt(esp, sk.desc, 24, 440, -20, 640, 80, '#ffffff', 'L', false, 0, 0.5)

  -- subir nível
  local custo = Formula.custoNivel(st.nivel)
  local maxN = st.nivel >= D.Param.nivel_max
  local okOuro, okXp = Estado.s.ouro >= custo.ouro, Estado.s.xp >= custo.xp
  local bn = U.btn(p, (okOuro and okXp and not maxN) and 'verde' or 'escuro', '', 10, -190, 100, 360, 130, function() M.subir(id) end, 0.5, 0)
  U.txt(bn, maxN and 'Nível máximo' or 'Subir nível', 34, 0, 26, 340, 44, '#ffffff', 'C', true)
  if not maxN then
    U.img(bn, 'ic_ouro', -150, -26, 40, 40)
    U.txt(bn, G.fmt(custo.ouro), 26, -60, -26, 130, 36, okOuro and '#ffffff' or '#ff8a7a', 'L', true)
    U.img(bn, 'ic_xp', 20, -26, 40, 40)
    U.txt(bn, G.fmt(custo.xp), 26, 110, -26, 130, 36, okXp and '#ffffff' or '#ff8a7a', 'L', true)
  end
  -- evoluir
  local ce = Formula.custoEstrela(st.estrelas)
  local maxE = st.estrelas >= D.Param.estrela_max
  local okE = st.frag >= ce
  local be = U.btn(p, (okE and not maxE) and 'roxo' or 'escuro', '', 10, 190, 100, 360, 130, function() M.evoluir(id) end, 0.5, 0)
  U.txt(be, maxE and 'Estrelas no máximo' or 'Evoluir estrela', 32, 0, 26, 340, 44, '#ffffff', 'C', true)
  local fb = U.bar(be, 0, -26, 280, 24, '#1b1a2e', '#c77dff')
  K.SetBar(fb, maxE and 1 or st.frag / ce)
  U.txt(be, maxE and '-' or (st.frag .. '/' .. ce .. ' fragmentos'), 20, 0, -26, 280, 30, '#ffffff', 'C', true)
  if okOuro and okXp and not maxN then K.Breath(bn, 0.03, 1) end
  if okE and not maxE then K.Breath(be, 0.03, 1) end
  hf.painel = p
end

function M.subir(id)
  local r = Estado.subirNivel(id)
  if r == 'max' then G.toast('Este herói já está no nível máximo.'); return end
  if r == 'falta' then G.toast('Ouro ou XP insuficiente. Colete o baú do navio ou vença fases.', '#ff8a7a'); return end
  K.Som('nivel')
  local W = K.W()
  K.Burst(C.efeito, hf.cx, -100, 30, '#7cf29a', 560, 26, 0.9, -200)
  K.Ring(C.efeito, hf.cx, -60, '#7cf29a', 700, 0.6)
  K.Float(C.efeito, 'NÍVEL ' .. Estado.s.herois[id].nivel .. '!', 70, hf.cx, 200, '#7cf29a')
  G.atualizarTopo()
  montarFicha(id)
end

function M.evoluir(id)
  local r = Estado.evoluir(id)
  if r == 'max' then G.toast('Estrelas no máximo.'); return end
  if r == 'falta' then G.toast('Faltam fragmentos. Recrute cópias deste herói na Taverna.', '#ff8a7a'); return end
  K.Som('ssr')
  K.Flash('#c77dffaa', 0.5)
  K.Burst(C.efeito, hf.cx, -60, 50, '#ffd166', 700, 30, 1.1, 0)
  K.Ring(C.efeito, hf.cx, -60, '#c77dff', 900, 0.7)
  K.Float(C.efeito, 'EVOLUIU!', 80, hf.cx, 220, '#ffd166')
  montarFicha(id)
end

function M.heroi.abrir(id)
  G.topo(true, 'tripulacao', 'Ficha do Herói')
  hf.cen = fundoEscuro()
  montarFicha(id)
end
function M.heroi.update(dt)
  if hf.cen then require('UI.Cenario').atualizarClima(hf.cen, C.tela, dt) end
end
function M.heroi.fechar() hf.cen = nil end

return M
