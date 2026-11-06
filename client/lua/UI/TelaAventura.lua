-- Mapa da campanha: ilhas em abas, rota de 10 fases por ilha e a tela de preparação antes da batalha.
local K, U, D, Estado, Formula = G.K, G.U, G.D, G.Estado, G.Formula
local Cenario = require('UI.Cenario')
local C = G.camadas
local M = {}

M.aventura = {}
local av = {}

local function ilhaLiberada(idx)
  return idx * Formula.FASES_POR_ILHA <= Estado.s.vencidas
end

-- preparação: inimigos, poder recomendado e recompensas
function M.preparar(n)
  local f = Formula.fase(n)
  local primeira = n >= Estado.s.vencidas
  local poderIni, poderEq = Formula.poderFase(n), Estado.poderEquipe()
  G.modal(f.ilha.nome .. '  ' .. (f.ilhaIdx + 1) .. '-' .. f.num, 1500, 820, function(p)
    U.txt(p, f.chefe and '<color=#ff8a7a>FASE DE CHEFE</color>' or 'Inimigos à frente', 34, 0, 300, 900, 50, '#ffffff', 'C', true)
    local qtd = #f.inimigos
    for i, ini in ipairs(f.inimigos) do
      local x = (i - (qtd + 1) / 2) * 250
      local c = U.painel(p, x, 120, 220, 270, ini.chefe and 'vermelho' or 'card')
      U.img(c, 'brilho', 0, 10, 260, 260, G.EL[ini.elemento].cor .. '55')
      local a = U.img(c, G.retratoInimigo(ini.id), 0, 16, 200, 200)
      K.SetScale(a, -1, 1)
      U.img(c, 'skin:circulo', -20, -22, 34, 34, G.EL[ini.elemento].cor, 1, 1)
      local fx = U.img(c, 'skin:escuro', 0, 26, 206, 50, '#ffffff', 0.5, 0)
      U.txt(fx, D.Inimigos[ini.id].nome, 20, 0, 0, 200, 46, '#ffffff', 'C', true)
      U.txt(c, 'Nv ' .. ini.nivel, 24, 16, -24, 100, 36, '#ffd166', 'L', true, 0, 1)
    end
    local cor = poderEq >= poderIni and '#7cf29a' or (poderEq >= poderIni * 0.8 and '#ffd166' or '#ff8a7a')
    local info = U.painel(p, 0, -140, 1300, 120, 'escuro')
    U.img(info, 'ic_poder', 80, 0, 70, 70, '#ffffff', 0, 0.5)
    U.txt(info, 'Seu poder: <color=' .. cor .. '>' .. G.fmt(poderEq) .. '</color>', 32, 330, 20, 440, 44, '#ffffff', 'L', true, 0, 0.5)
    U.txt(info, 'Recomendado: ' .. G.fmt(poderIni), 28, 330, -24, 440, 40, '#cfe2ff', 'L', true, 0, 0.5)
    local pr = { ouro = f.recompensa.ouro, xp = f.recompensa.xp, gemas = primeira and f.recompensa.gemas or 0 }
    U.txt(info, primeira and 'Recompensa' or 'Recompensa (repetição)', 24, -330, 30, 400, 34, '#9fb3c8', 'C', false, 1, 0.5)
    G.premioIcones(info, pr, -330, -16, 48, 1, 0.5)
    local dica = 'Vantagem de elemento: Fogo > Vento > Maré > Fogo   |   Luz e Sombra se anulam'
    U.txt(p, dica, 22, 0, -228, 1300, 34, '#9fb3c8', 'C', false)
  end, {
    { 'Formação', 'azul', function() G.ir('formacao', { voltar = n }) end },
    { 'Zarpar!', 'ouro', function() G.ir('batalha', n) end },
  })
end

local function montarRota(idx)
  K.Clear(av.rota)
  local W = K.W()
  local s = Estado.s
  local ilhaId = D.Ilhas._ordem[idx + 1]
  local ilha = D.Ilhas[ilhaId]
  K.SetText(av.nome, ilha.nome)
  K.SetText(av.desc, ilha.desc)
  local pts = {}
  local x0, x1 = -W / 2 + 230, W / 2 - 230
  for i = 1, Formula.FASES_POR_ILHA do
    local t = (i - 1) / (Formula.FASES_POR_ILHA - 1)
    pts[i] = { x = x0 + (x1 - x0) * t, y = -90 + 150 * math.sin(i * 1.15 + idx) }
  end
  -- rastro pontilhado entre as fases
  for i = 1, #pts - 1 do
    local a, b = pts[i], pts[i + 1]
    local dx, dy = b.x - a.x, b.y - a.y
    local dist = math.sqrt(dx * dx + dy * dy)
    local n = math.floor(dist / 34)
    local n0 = idx * Formula.FASES_POR_ILHA + i - 1
    for k = 1, n - 1 do
      local cor = n0 < s.vencidas and '#ffd166dd' or '#ffffff55'
      U.img(av.rota, 'skin:circulo', a.x + dx * k / n, a.y + dy * k / n, 13, 13, cor)
    end
  end
  for i, pt in ipairs(pts) do
    local n = idx * Formula.FASES_POR_ILHA + i - 1
    local chefe = i == Formula.FASES_POR_ILHA
    local feita, atual = n < s.vencidas, n == s.vencidas
    local tam = chefe and 170 or 116
    local skin = feita and 'ouro' or (atual and 'verde' or 'escuro')
    local no = U.btn(av.rota, '', '', 10, pt.x, pt.y, tam, tam, function()
      if n > s.vencidas then G.toast('Vença a fase anterior primeiro.'); return end
      M.preparar(n)
    end)
    local disco = U.img(no, 'skin:circulo', 0, 0, tam, tam, '#0b2442')
    U.img(no, 'skin:' .. skin, 0, 0, tam - 12, tam - 12, '#ffffff')
    if chefe then
      local f = Formula.fase(n)
      local clip = K.Clip(no, 0, 0, tam - 26, tam - 26, 0.5, 0.5)
      local a = U.img(clip, G.retratoInimigo(f.inimigos[1].id), 0, 0, tam, tam)
      K.SetScale(a, -1, 1)
      if n > s.vencidas then K.SetGray(no, true) end
      U.txt(no, 'CHEFE', 28, 0, -tam / 2 - 6, 200, 40, '#ff8a7a', 'C', true)
    else
      U.txt(no, (idx + 1) .. '-' .. i, 38, 0, 2, tam, tam, feita and '#3b2300' or '#ffffff', 'C', not feita)
    end
    if n > s.vencidas then U.img(no, 'ic_cadeado', tam / 2 - 18, -tam / 2 + 18, 46, 46) end
    if feita then G.estrelasImg(no, s.estrelasFase[n + 1] or 0, 3, 0, tam / 2 + 6, 34) end
    if atual then
      K.Breath(disco, 0.06, 1.1)
      K.Ring(av.rota, pt.x, pt.y, '#7cf29a', 260, 0.9)
      av.atualPt = pt
      av.atualI = i
    end
  end
  -- o navio da tripulação: veleja da fase anterior até a atual e fica balançando sobre ela
  local i = av.atualI
  if i and pts[i] then
    av.atualI = nil
    local pt, tam = pts[i], (i == Formula.FASES_POR_ILHA) and 170 or 116
    local alvoX, alvoY = pt.x - 10, pt.y + tam / 2 + 92
    local de = pts[i - 1]
    local navio = U.img(av.rota, 'navio_mapa', de and de.x - 10 or alvoX, de and de.y + 150 or alvoY, 186, 192)
    local function ancorar()
      if not K.Alive(navio) then return end
      K.Bob(navio, 8, 1.8)
      K.Sway(navio, 4, 2.6)
      K.Particulas(av.rota, 'fx_respingo', alvoX, alvoY - 70, 5, '#d9f4ffcc', 220, 90, 120, 40, 0.6, 700, -9999, false)
    end
    if de then K.MoveTo(navio, alvoX, alvoY, 0.9, 4, ancorar) else ancorar() end
  end
  for i, b in ipairs(av.abas) do
    K.SetSprite(b, 'skin:' .. (i - 1 == idx and 'ouro' or (ilhaLiberada(i - 1) and 'azul' or 'escuro')))
  end
end

local function trocarIlha(idx)
  if not ilhaLiberada(idx) then G.toast('Derrote o chefe da ilha anterior para liberar.'); return end
  av.idx = idx
  K.Clear(C.fundo)
  av.cen = Cenario.montar(C.fundo, 'mapa', { horizonte = 760, chao = false, yMinBrilho = -520 })
  Cenario.entrada(av.cen, 0.8)
  montarRota(idx)
end

function M.aventura.abrir()
  G.topo(true, true, 'Aventura')
  local W = K.W()
  local s = Estado.s
  av.abas = {}
  for i, id in ipairs(D.Ilhas._ordem) do
    local ilha = D.Ilhas[id]
    local x = (i - 2) * 420
    local b = U.btn(C.tela, 'azul', '', 10, x, -180, 400, 90, function() trocarIlha(i - 1) end, 0.5, 1)
    U.txt(b, ilha.nome, 28, 0, 2, 380, 80, '#ffffff', 'C', true)
    if not ilhaLiberada(i - 1) then U.img(b, 'ic_cadeado', 170, 30, 50, 50) end
    av.abas[i] = b
  end
  local info = U.painel(C.tela, 0, -300, 1300, 110, 'escuro', 0.5, 1)
  K.SetRaycast(info, false)
  av.nome = U.txt(info, '', 40, 0, 22, 1240, 50, '#ffd166', 'C', true)
  av.desc = U.txt(info, '', 26, 0, -24, 1240, 44, '#ffffff', 'C', true)
  av.rota = U.box(C.tela, 0, -60, W, 700)
  local total = Formula.totalFases()
  local idx = math.min(s.vencidas, total - 1) // Formula.FASES_POR_ILHA
  if s.vencidas >= total then
    U.txt(C.tela, 'Você libertou a Enseada do Farol! O próximo mar chega na próxima atualização.', 30, 0, 60, 1400, 50, '#7cf29a', 'C', true, 0.5, 0)
  end
  trocarIlha(idx)
end

function M.aventura.update(dt)
  if av.cen then Cenario.atualizarClima(av.cen, C.tela, dt) end
end

function M.aventura.fechar() av.cen = nil end

return M
