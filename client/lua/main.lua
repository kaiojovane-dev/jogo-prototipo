-- Entrada do jogo em Lua: dados, estado, gerenciador de telas e componentes reutilizáveis.
local K = CS.UIKit

local D = {}
for _, n in ipairs({ 'Param', 'Herois', 'Skills', 'Inimigos', 'Ilhas', 'Raridade', 'Login', 'Missoes', 'Inicio' }) do
  D[n] = require('Data.' .. n .. 'Data')
end
local Formula = require('Game.Formula')
Formula.init(D)
local Estado = require('Mgrs.Estado')
Estado.init(D)

local G = { D = D, Formula = Formula, Estado = Estado, K = K }
_G.G = G

G.EL = {
  fogo = { nome = 'Fogo', cor = '#ff7043' }, vento = { nome = 'Vento', cor = '#5ccf8a' }, mare = { nome = 'Maré', cor = '#41a8f5' },
  luz = { nome = 'Luz', cor = '#ffd166' }, sombra = { nome = 'Sombra', cor = '#b388ff' },
}
G.RAR = { R = '#5fa8ff', SR = '#c77dff', SSR = '#ffb703' }
G.EM_BREVE = {
  { nome = 'Arena', v = '0.2', ic = 'ic_espadas', desc = 'Desafie formações de outros capitães e suba no ranking da temporada.' },
  { nome = 'Equipamentos', v = '0.3', ic = 'ic_casaco', desc = 'Armas, casacos e relíquias com conjuntos e forja.' },
  { nome = 'Guildas', v = '0.5', ic = 'ic_estandarte', desc = 'Alie-se a outras tripulações e enfrente o chefe semanal.' },
  { nome = 'Eventos', v = '0.6', ic = 'ic_lanterna', desc = 'Eventos sazonais, banners especiais e passe de temporada.' },
  { nome = 'Torre do Farol', v = '0.7', ic = 'ic_farol', desc = 'Andares infinitos com recompensas a cada marco.' },
}
G.INTRO = {
  { 'marina', 'Capitão! A Liga do Farol controla toda a luz e todas as rotas. Quem navega sem licença, navega no escuro.' },
  { 'mirto', 'Mas dizem que no Fim do Mapa o mar realiza o desejo de quem chega lá. E cada Marca que levamos na pele é uma luz que a Liga não licenciou.' },
  { 'pipo', 'Então bora! Primeira parada: a Enseada do Farol. Eu já arrumei o navio... mais ou menos.' },
}

-- ------------------------------------------------------------------ utilidades
function G.fmt(n)
  n = math.floor(n or 0)
  if n >= 1000000 then return (string.format('%.1fM', n / 1000000):gsub('%.0M', 'M')) end
  if n >= 10000 then return (string.format('%.1fK', n / 1000):gsub('%.0K', 'K')) end
  local s = tostring(n)
  local r = s:reverse():gsub('(%d%d%d)', '%1.'):reverse()
  return (r:gsub('^%.', ''))
end

function G.tempo(s)
  s = math.max(0, math.floor(s))
  local h, m, ss = s // 3600, (s % 3600) // 60, s % 60
  if h > 0 then return string.format('%dh %02dm', h, m) end
  return string.format('%dm %02ds', m, ss)
end

-- fileira de estrelas (ícone dourado = conquistada, apagado = falta)
function G.estrelasImg(p, n, max, x, y, size, ax, ay)
  local box = K.Box(p, x or 0, y or 0, (max or n) * size, size, ax or 0.5, ay or 0.5)
  for i = 1, (max or n) do
    local cor = i <= n and '#ffffff' or '#2a3550'
    K.Img(box, 'ic_estrela', (i - 0.5) * size, 0, size * 1.05, size * 1.05, cor, 0, 0.5)
  end
  return box
end

function G.premioTxt(p)
  local r = {}
  if (p.ouro or 0) > 0 then r[#r + 1] = '<color=#ffd166>Ouro ' .. G.fmt(p.ouro) .. '</color>' end
  if (p.xp or 0) > 0 then r[#r + 1] = '<color=#f4e2b8>XP ' .. G.fmt(p.xp) .. '</color>' end
  if (p.gemas or 0) > 0 then r[#r + 1] = '<color=#9bf6ff>Gemas ' .. G.fmt(p.gemas) .. '</color>' end
  if p.heroi and p.heroi ~= '' then r[#r + 1] = '<color=#ffb703>' .. D.Herois[p.heroi].nome .. '</color>' end
  return table.concat(r, '   ')
end

function G.arteHeroi(id) return 'heroi_' .. id end
-- retrato (rosto) para cartas, avatares e falas; gerado a partir da arte de corpo inteiro
function G.arteRetrato(id) return 'retrato_' .. id end
-- nome curto para cartas: 'Dr. Mirto Salgado' vira 'Dr. Mirto', 'Lina Faísca' vira 'Lina'
function G.curto(nome)
  local a, b = nome:match('^(%S+)%s+(%S+)')
  if a and a:sub(-1) == '.' then return a .. ' ' .. b end
  return nome:match('^(%S+)') or nome
end
function G.lider()
  for _, id in ipairs(Estado.s.formacao) do if id ~= '' then return id end end
  return 'pipo'
end
function G.arteInimigo(id) return 'inimigo_' .. D.Inimigos[id].arte end
function G.retratoInimigo(id) return 'retrato_' .. D.Inimigos[id].arte end

-- ------------------------------------------------------------------ atalhos de UI
local U = {}
G.U = U
function U.img(p, sp, x, y, w, h, cor, ax, ay) return K.Img(p, sp or '', x or 0, y or 0, w, h, cor or '#ffffff', ax or 0.5, ay or 0.5) end
function U.txt(p, s, size, x, y, w, h, cor, al, ol, ax, ay) return K.Txt(p, s, math.floor(size), x or 0, y or 0, w, h, cor or '#ffffff', al or 'C', ol ~= false, ax or 0.5, ay or 0.5) end
function U.btn(p, skin, label, size, x, y, w, h, fn, ax, ay) return K.Btn(p, skin, label or '', math.floor(size or 40), x or 0, y or 0, w, h, fn, ax or 0.5, ay or 0.5) end
function U.box(p, x, y, w, h, ax, ay) return K.Box(p, x or 0, y or 0, w, h, ax or 0.5, ay or 0.5) end
function U.bar(p, x, y, w, h, back, front, ax, ay) return K.Bar(p, x or 0, y or 0, w, h, back or '#1b1a2e', front or '#7cf29a', ax or 0.5, ay or 0.5) end
-- figura do herói: boneco com esqueleto e física quando a arte tem rig (Resources/Rigs), senão a imagem.
-- Devolve o objeto e se ele é um boneco vivo (que aceita K.BonecoAnim).
function U.figura(p, id, x, y, w, h, ax, ay)
  local arte = G.arteHeroi(id)
  if K.TemRig(arte) then return K.Boneco(p, arte, x or 0, y or 0, w, h, ax or 0.5, ay or 0.5), true end
  return U.img(p, arte, x, y, w, h, '#ffffff', ax, ay), false
end
function U.painel(p, x, y, w, h, skin, ax, ay)
  local g = K.Img(p, 'skin:' .. (skin or 'painel'), x or 0, y or 0, w, h, '#ffffff', ax or 0.5, ay or 0.5)
  K.SetRaycast(g, true)
  return g
end

local camadas = {}
for _, n in ipairs({ 'fundo', 'tela', 'topo', 'modal', 'efeito', 'toast' }) do camadas[n] = K.Layer(n) end
G.camadas = camadas

-- avisos rápidos
function G.toast(msg, cor)
  local t = U.painel(camadas.toast, 0, -170, 980, 84, 'escuro', 0.5, 1)
  U.txt(t, msg, 34, 0, 0, 940, 80, cor or '#ffffff', 'C', true)
  K.SetAlpha(t, 0)
  K.FadeTo(t, 1, 0.2, nil)
  K.MoveTo(t, 0, -150, 0.25, 1, nil)
  K.After(1.9, function() if K.Alive(t) then K.FadeTo(t, 0, 0.3, function() K.Kill(t) end) end end)
end

-- modal genérico: titulo, montar(conteudo, painel) e lista de botões {txt, skin, fn}
local modais = {}
function G.modal(titulo, larg, alt, montar, botoes)
  local fundo = U.img(camadas.modal, '', 0, 0, K.WTela() + 400, K.HTela() + 400, '#000000cc')
  K.SetRaycast(fundo, true)
  local p = U.painel(fundo, 0, 10, larg, alt, 'painel')
  K.SetScale(p, 0.7, 0.7); K.ScaleTo(p, 1, 0.25, 3, nil)
  if titulo and titulo ~= '' then
    local faixa = U.painel(p, 0, -6, math.min(larg - 120, 760), 92, 'ouro', 0.5, 1)
    U.txt(faixa, titulo, 46, 0, 2, larg - 160, 90, '#3b2300', 'C', false)
  end
  local m = { fundo = fundo, painel = p }
  function m.fechar() if K.Alive(fundo) then K.Kill(fundo) end; for i, x in ipairs(modais) do if x == m then table.remove(modais, i) break end end end
  if montar then montar(p, m) end
  if botoes and #botoes > 0 then
    local n, bw = #botoes, math.min(360, (larg - 80) / #botoes - 24)
    for i, b in ipairs(botoes) do
      local x = (i - (n + 1) / 2) * (bw + 24)
      U.btn(p, b[2] or 'azul', b[1], 42, x, 70, bw, 104, function()
        if not b.manter then m.fechar() end
        if b[3] then b[3]() end
      end, 0.5, 0)
    end
  end
  modais[#modais + 1] = m
  K.Som('abrir')
  return m
end

-- carta de herói reutilizável (lista, formação, taverna)
function G.carta(p, id, x, y, w, h, fn, ax, ay)
  local def = D.Herois[id]
  local st = Estado.s.herois[id]
  local c = U.painel(p, x, y, w, h, 'card', ax, ay)
  K.SetColor(c, G.RAR[def.raridade])
  local f = U.img(c, 'skin:card', 0, 0, w - 10, h - 10, '#ffffff')
  K.SetColor(f, '#16305a')
  U.img(c, 'brilho', 0, 20, w * 1.1, w * 1.1, G.RAR[def.raridade] .. '55')
  local lado = math.min(w * 0.94, h * 0.74)
  local arte = U.img(c, G.arteRetrato(id), 0, 20, lado, lado)
  U.txt(c, def.raridade, 30, 62, -28, 96, 40, G.RAR[def.raridade], 'L', true, 0, 1)
  local el = U.img(c, 'skin:circulo', -22, -26, 34, 34, G.EL[def.elemento].cor, 1, 1)
  local faixa = U.img(c, 'skin:escuro', 0, 30, w - 14, 58, '#ffffff', 0.5, 0)
  U.txt(faixa, G.curto(def.nome), 28, 0, 8, w - 20, 34, '#ffffff', 'C', true)
  if st then
    U.txt(faixa, 'Nv ' .. st.nivel, 22, 12 + (w - 20) * 0.22, -14, (w - 20) * 0.44, 30, '#cfe2ff', 'L', true, 0, 0.5)
    local tam = math.min(20, (w - 20) * 0.5 / 5)
    G.estrelasImg(faixa, st.estrelas, 5, -12 - tam * 2.5, -14, tam, 1, 0.5)
  else
    U.txt(faixa, 'Não recrutado', 20, 0, -16, w - 20, 30, '#9fb3c8', 'C', true)
    K.SetGray(c, true)
  end
  if fn then K.SetClick(c, fn) end
  return c, arte
end

-- barra superior com recursos
local topo = {}
function G.topo(mostrar, voltar, titulo)
  K.Clear(camadas.topo)
  if not mostrar then return end
  local s = Estado.s
  -- a faixa vai de borda a borda (passa atrás do notch); os botões ficam na área útil
  U.img(camadas.topo, 'skin:escuro', 0, -58, K.WTela() + 400, 116, '#ffffff', 0.5, 1)
  local bar = U.box(camadas.topo, 0, -58, K.W() + 40, 116, 0.5, 1)
  if voltar then
    U.btn(bar, 'azul', 'Voltar', 36, 160, -58, 240, 82, function() G.ir(type(voltar) == 'string' and voltar or 'navio') end, 0, 1)
    if titulo then U.txt(bar, titulo, 48, 640, -58, 600, 80, '#ffd166', 'L', true, 0, 1) end
  else
    local av = U.painel(bar, 80, -58, 92, 92, 'ouro', 0, 1)
    local clip = K.Clip(av, 0, 0, 80, 80, 0.5, 0.5)
    U.img(clip, G.arteRetrato(G.lider()), 0, 0, 86, 86)
    U.txt(bar, s.nome, 36, 330, -36, 360, 44, '#ffffff', 'L', true, 0, 1)
    topo.poder = U.txt(bar, '', 30, 330, -80, 360, 40, '#ffd166', 'L', true, 0, 1)
  end
  local x = -150
  topo.rec = {}
  for _, r in ipairs({ { 'ic_gema', 'gemas' }, { 'ic_xp', 'xp' }, { 'ic_ouro', 'ouro' } }) do
    local pill = U.img(bar, 'skin:vidro', x - 120, -58, 250, 70, '#ffffff', 1, 1)
    U.img(pill, r[1], -98, 0, 64, 64)
    topo.rec[r[2]] = U.txt(pill, '', 34, 20, 0, 180, 60, '#ffffff', 'C', true)
    x = x - 280
  end
  U.btn(bar, 'vidro', '', 30, -60, -58, 90, 90, function() G.config() end, 1, 1)
  U.img(bar, 'ic_engrenagem', -60, -58, 66, 66, '#ffffff', 1, 1)
  G.atualizarTopo()
end

function G.atualizarTopo()
  if not topo.rec or not K.Alive(topo.rec.ouro) then return end
  local s = Estado.s
  K.SetText(topo.rec.ouro, G.fmt(s.ouro))
  K.SetText(topo.rec.xp, G.fmt(s.xp))
  K.SetText(topo.rec.gemas, G.fmt(s.gemas))
  if topo.poder and K.Alive(topo.poder) then K.SetText(topo.poder, 'Poder ' .. G.fmt(Estado.poderEquipe())) end
end

-- ------------------------------------------------------------------ gerenciador de telas
local Telas = require('UI.Telas')
local Batalha = require('UI.Batalha')
G.Telas, G.Batalha = Telas, Batalha
local atual = nil

function G.ir(nome, arg)
  if atual and atual.fechar then atual.fechar() end
  K.Clear(camadas.fundo); K.Clear(camadas.tela)
  for i = #modais, 1, -1 do modais[i].fechar() end
  atual = (nome == 'batalha') and Batalha or Telas[nome]
  G.telaAtual = nome
  atual.abrir(arg)
end

function G.config()
  local s = Estado.s
  G.modal('Configurações', 900, 560, function(p)
    local lbl = U.txt(p, '', 40, 0, 60, 700, 70, '#ffffff', 'C', true)
    local function rot() K.SetText(lbl, 'Sons: ' .. (s.config.som and '<color=#7cf29a>LIGADOS</color>' or '<color=#ff8a7a>DESLIGADOS</color>')) end
    rot()
    U.btn(p, 'azul', 'Alternar sons', 36, 0, -40, 420, 90, function() s.config.som = not s.config.som; K.SomLigado(s.config.som); Estado.salvar(); rot() end)
    U.txt(p, 'Fim do Mapa - versão 0.1 Beta', 28, 0, 210, 800, 40, '#9fb3c8', 'C', false, 0.5, 0)
  end, {
    { 'Roteiro', 'roxo', function() Telas.roteiro() end },
    { 'Recomeçar', 'vermelho', function()
      G.modal('Recomeçar?', 900, 460, function(p) U.txt(p, 'Todo o progresso deste aparelho será apagado.', 36, 0, 30, 780, 140, '#ffffff', 'C', true) end,
        { { 'Cancelar', 'azul' }, { 'Apagar', 'vermelho', function() Estado.resetar(); G.ir('titulo') end } })
    end },
    { 'Fechar', 'ouro' },
  })
end

-- ------------------------------------------------------------------ ganchos chamados pelo C#
function Game_Start()
  K.SomLigado(Estado.s.config.som)
  G.ir('titulo')
  local pasta = K.Arg('-autotest')
  if pasta ~= '' then
    G.autoteste = require('Dev.Autoteste')
    G.autoteste.iniciar(pasta == '1' and '.' or pasta)
  end
  local vit = K.Arg('-vitrine')
  if vit ~= '' then
    G.vitrine = require('Dev.Vitrine')
    G.vitrine.iniciar(vit == '1' and '.' or vit)
  end
end

function Game_Update(dt)
  if atual and atual.update then atual.update(dt) end
  if G.autoteste then G.autoteste.update(dt) end
  if G.vitrine then G.vitrine.update(dt) end
end

function Game_Back()
  if #modais > 0 then modais[#modais].fechar(); return end
  if G.telaAtual == 'batalha' then Batalha.pausar(); return end
  if G.telaAtual ~= 'navio' and G.telaAtual ~= 'titulo' then G.ir('navio'); return end
end

function Game_Pause(p)
  if p then Estado.salvar() else Estado.virarDia() end
end
