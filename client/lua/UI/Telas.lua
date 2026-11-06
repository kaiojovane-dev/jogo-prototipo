-- Telas principais: título com introdução, navio (hub) e os painéis rápidos (login, missões, pilhagem, em breve, roteiro).
local K, U, D, Estado, Formula = G.K, G.U, G.D, G.Estado, G.Formula
local Cenario = require('UI.Cenario')
local C = G.camadas
local T = {}

-- ------------------------------------------------------------------ utilidades visuais compartilhadas
-- linha de recompensas com ícones
function G.premioIcones(p, pr, x, y, size, ax, ay)
  local itens = {}
  if (pr.ouro or 0) > 0 then itens[#itens + 1] = { 'ic_ouro', G.fmt(pr.ouro), '#ffd166' } end
  if (pr.xp or 0) > 0 then itens[#itens + 1] = { 'ic_xp', G.fmt(pr.xp), '#f4e2b8' } end
  if (pr.gemas or 0) > 0 then itens[#itens + 1] = { 'ic_gema', G.fmt(pr.gemas), '#9bf6ff' } end
  if pr.heroi and pr.heroi ~= '' then itens[#itens + 1] = { G.arteRetrato(pr.heroi), G.curto(D.Herois[pr.heroi].nome), '#ffb703' } end
  local larg = size * 3.3
  local box = U.box(p, x, y, #itens * larg, size, ax, ay)
  for i, it in ipairs(itens) do
    local cx = (i - 0.5) * larg
    U.img(box, it[1], cx - size * 0.95, 0, size, size, '#ffffff', 0, 0.5)
    U.txt(box, it[2], size * 0.62, cx + size * 0.55, 0, size * 2.2, size, it[3], 'L', true, 0, 0.5)
  end
  return box
end

-- recursos "voando" até a barra superior
local ALVO = { gemas = -270, xp = -550, ouro = -830 }
local ICONE = { gemas = 'ic_gema', xp = 'ic_xp', ouro = 'ic_ouro' }
function G.voar(pr, sx, sy)
  local W = K.W()
  local atraso = 0
  for _, tipo in ipairs({ 'ouro', 'xp', 'gemas' }) do
    if (pr[tipo] or 0) > 0 then
      for i = 1, 7 do
        local g = U.img(C.efeito, ICONE[tipo], sx + (math.random() - 0.5) * 120, sy + (math.random() - 0.5) * 80, 64, 64)
        K.SetScale(g, 0.2, 0.2)
        local espera = atraso + i * 0.045
        K.ScaleTo(g, 1, 0.18, 3, nil)
        K.After(espera + 0.2, function()
          if not K.Alive(g) then return end
          K.MoveTo(g, W / 2 + ALVO[tipo], 540 - 58, 0.5, 2, function()
            K.Kill(g)
            if i == 1 then K.Som('moeda') end
            G.atualizarTopo()
          end)
        end)
      end
      atraso = atraso + 0.15
    end
  end
  K.After(1.2, function() G.atualizarTopo() end)
end

-- ------------------------------------------------------------------ título
T.titulo = {}
local tit = {}

local function intro()
  local W = K.W()
  local i, alvo, mostrado, ac = 0, '', 0, 0
  local caixa = U.painel(C.modal, 0, -360, W - 240, 270, 'escuro')
  local retrato = U.img(C.modal, '', -W / 2 + 300, -100, 460, 640)
  local placa = U.painel(caixa, 560, 0, 340, 76, 'ouro', 0, 1)
  local nome = U.txt(placa, '', 36, 0, 2, 320, 70, '#3b2300', 'C', false)
  local fala = U.txt(caixa, '', 38, 140, -20, W - 860, 190, '#ffffff', 'TL', true, 0.5, 0.5)
  local dica = U.txt(caixa, 'toque para continuar', 24, -240, 30, 400, 40, '#9fb3c8', 'R', false, 1, 0)
  K.Breath(dica, 0.04, 1.4)
  local toque = U.btn(C.modal, '', '', 10, 0, 0, K.WTela() + 400, K.HTela() + 400, nil)
  local function prox()
    i = i + 1
    local l = G.INTRO[i]
    if not l then
      K.Kill(caixa); K.Kill(retrato); K.Kill(toque)
      Estado.s.intro = true; Estado.salvar()
      tit.dlg = nil
      G.ir('navio')
      return
    end
    K.SetSprite(retrato, G.arteHeroi(l[1]))
    K.SetPos(retrato, -W / 2 + 200, -100); K.MoveTo(retrato, -W / 2 + 300, -100, 0.25, 1, nil)
    K.SetText(nome, D.Herois[l[1]].nome)
    alvo, mostrado, ac = l[2], 0, 0
    K.SetText(fala, '')
    K.Som('abrir')
  end
  K.SetClick(toque, function()
    if mostrado < utf8.len(alvo) then mostrado = utf8.len(alvo); K.SetText(fala, alvo) else prox() end
  end)
  tit.dlg = function(dt)
    if mostrado < utf8.len(alvo) then
      ac = ac + dt * 45
      local n = math.min(utf8.len(alvo), math.floor(ac))
      if n > mostrado then
        mostrado = n
        K.SetText(fala, alvo:sub(1, (utf8.offset(alvo, n + 1) or (#alvo + 1)) - 1))
      end
    end
  end
  prox()
end

T.intro = intro

function T.titulo.abrir()
  G.topo(false)
  K.Ambiente('mar')
  local W = K.W()
  tit.cen = Cenario.montar(C.fundo, 'titulo', { horizonte = 600 })
  Cenario.entrada(tit.cen, 1.6)
  -- a tripulação na praia, de frente para o farol da Liga
  local elenco = { 'kalu', 'marina', 'pipo', 'lina', 'mirto' }
  for i, id in ipairs(elenco) do
    local x = -W / 2 + 230 + (i - 1) * 170
    local y = (i % 2 == 0) and -250 or -300
    local h, vivo = U.figura(C.fundo, id, x - 300, y, 300, 420)
    K.SetAlpha(h, 0)
    K.After(0.25 * i, function()
      if not K.Alive(h) then return end
      K.FadeTo(h, 1, 0.5, nil)
      if vivo then K.BonecoAnim(h, 'correr', 1) end
      K.MoveTo(h, x, y, 0.8, 1, function()
        if vivo then K.BonecoAnim(h, 'parado', 1) else K.Breath(h, 0.015, 2 + i * 0.2) end
      end)
    end)
  end

  local logo = U.box(C.tela, W * 0.22, 170, 900, 460)
  U.img(logo, 'brilho', 0, 30, 1000, 700, '#ffd16655')
  if K.Existe('logo_fimdomapa') then
    -- logo ilustrado (gerado): letreiro dourado com rosa dos ventos e a raia de luz
    local l = U.img(logo, 'logo_fimdomapa', 0, 40, 900, 500)
    K.Bob(l, 6, 4)
    U.txt(logo, 'onde o mar realiza desejos', 40, 0, -200, 900, 60, '#ffe8c2', 'C', true)
  else
    U.txt(logo, 'FIM', 190, 0, 120, 900, 200, '#ffd166', 'C', true)
    U.txt(logo, 'DO MAPA', 120, 0, -20, 900, 150, '#ffffff', 'C', true)
    U.txt(logo, 'onde o mar realiza desejos', 40, 0, -120, 900, 60, '#ffe8c2', 'C', true)
  end
  local beta = U.painel(logo, 300, -190, 220, 64, 'vermelho')
  U.txt(beta, 'BETA 0.1', 32, 0, 2, 210, 60, '#ffffff', 'C', true)
  K.SetRot(beta, -6)
  K.SetScale(logo, 0.2, 0.2); K.ScaleTo(logo, 1, 0.8, 3, nil)

  local toque = U.txt(C.tela, 'Toque para zarpar', 50, W * 0.24, -330, 900, 80, '#ffffff', 'C', true)
  K.Breath(toque, 0.05, 1.6)
  U.txt(C.tela, 'v0.1.0 beta  -  SnyX Studio', 24, 340, 30, 600, 40, '#ffffffaa', 'L', false, 0, 0)

  local botao = U.btn(C.tela, '', '', 10, 0, 0, K.WTela() + 400, K.HTela() + 400, function()
    K.Som('abrir')
    if not Estado.s.intro then
      K.Kill(toque)
      intro()
    else
      G.ir('navio')
    end
  end)
  K.SetSize(botao, K.WTela() + 400, K.HTela() + 400)
end

function T.titulo.update(dt)
  if tit.cen then Cenario.atualizarClima(tit.cen, C.tela, dt) end
  if tit.dlg then tit.dlg(dt) end
end

function T.titulo.fechar() tit.cen = nil; tit.dlg = nil; K.Clear(C.modal) end

-- ------------------------------------------------------------------ navio (hub)
T.navio = {}
local hub = {}

local function selo(p, n, x, y)
  local b = U.img(p, 'skin:circulo', x, y, 46, 46, '#e63946', 1, 1)
  U.txt(b, tostring(n), 28, 0, 1, 46, 46, '#ffffff', 'C', true)
  K.Breath(b, 0.08, 0.9)
  return b
end

local function botaoLateral(p, icone, nome, x, y, fn, ax, ay)
  local b = U.btn(p, 'vidro', '', 10, x, y, 140, 140, fn, ax, ay)
  U.img(b, icone, 0, 14, 92, 92)
  U.txt(b, nome, 26, 0, -52, 170, 40, '#ffffff', 'C', true)
  return b
end

local function atualizarHub()
  if not hub.bau or not K.Alive(hub.bau) then return end
  local r = Estado.idle()
  K.SetText(hub.bauTempo, r.cheio and '<color=#ff8a7a>CHEIO!</color>' or G.tempo(r.seg))
  K.SetText(hub.bauOuro, G.fmt(r.ouro))
  K.SetBar(hub.bauBarra, r.seg / (D.Param.idle_max_horas * 3600))
  -- selos
  for _, sl in ipairs(hub.selos or {}) do K.Kill(sl) end
  hub.selos = {}
  if Estado.s.login.pendente then hub.selos[#hub.selos + 1] = selo(hub.bLogin, '!', 10, 10) end
  local m = Estado.missoesProntas()
  if m > 0 then hub.selos[#hub.selos + 1] = selo(hub.bMissoes, m, 10, 10) end
  local pg = D.Param.pilhagem_gratis - Estado.s.pilhagem.usadas
  if pg > 0 then hub.selos[#hub.selos + 1] = selo(hub.bPilhagem, pg, 10, 10) end
end
G.atualizarHub = atualizarHub

local function proxFaseTxt()
  local n = math.min(Estado.s.vencidas, Formula.totalFases() - 1)
  local f = Formula.fase(n)
  return f.ilha.nome .. '  ' .. (f.ilhaIdx + 1) .. '-' .. f.num, f
end

function T.navio.abrir()
  G.topo(true)
  K.Ambiente('mar')
  local W = K.W()
  hub.cen = Cenario.montar(C.fundo, 'hub', { horizonte = 700, yMinBrilho = -150 })
  Cenario.entrada(hub.cen, 0.9)

  -- convés com amurada (o jogador está a bordo)
  -- caixa do convés: coordenadas a partir da base da tela (âncora embaixo)
  -- o convés já está pintado no cenário (bg_navio): a caixa só posiciona a tripulação sobre ele
  local conves = U.box(C.fundo, 0, 300, W + 160, 600, 0.5, 0)

  -- tripulação no convés
  local s = Estado.s
  local Lb, Rb = -W / 2 + 470, W / 2 - 520
  local passo = math.min(230, (Rb - Lb) / 5)
  local ids = {}
  for slot = 1, 5 do if s.formacao[slot] ~= '' then ids[#ids + 1] = s.formacao[slot] end end
  hub.tripulantes = {}
  local ordem = {}
  for i, id in ipairs(ids) do ordem[#ordem + 1] = { i = i, id = id, y = (i % 2 == 0) and 250 or 285 } end
  table.sort(ordem, function(a, b) return a.y > b.y end)
  for _, o in ipairs(ordem) do
    local x = Lb + passo * (o.i - 0.5)
    U.img(conves, 'skin:circulo', x, o.y - 6, 150, 34, '#00000055', 0.5, 0)
    local h, vivo = U.figura(conves, o.id, x, o.y + 150, 230, 300, 0.5, 0)
    o.y = o.y - 540
    if not vivo then K.Breath(h, 0.018, 2 + math.random() * 0.6) end
    K.SetClick(h, function() G.ir('heroi', o.id) end)
    hub.tripulantes[#hub.tripulantes + 1] = { g = h, id = o.id, x = x, y = o.y, vivo = vivo }
    K.SetAlpha(h, 0); K.FadeTo(h, 1, 0.5, nil)
  end
  hub.falaT = 3

  -- baú de recompensas (renda passiva)
  local bx = -W / 2 + 330
  hub.bau = U.img(C.tela, 'ic_bau', bx, -230, 200, 200)
  K.Bob(hub.bau, 5, 2.4)
  K.SetClick(hub.bau, function() T.modalBau() end)
  local balao = U.painel(C.tela, bx, -70, 300, 120, 'escuro')
  K.SetRaycast(balao, false)
  hub.bauTempo = U.txt(balao, '', 30, 0, 30, 280, 44, '#ffffff', 'C', true)
  U.img(balao, 'ic_ouro', -80, -14, 46, 46)
  hub.bauOuro = U.txt(balao, '', 32, 30, -14, 180, 44, '#ffd166', 'L', true)
  hub.bauBarra = U.bar(balao, 0, -46, 250, 14, '#1b1a2e', '#ffd166')

  -- coluna esquerda: eventos diários
  hub.bLogin = botaoLateral(C.tela, 'ic_calendario', 'Login', 110, -230, function() T.modalLogin() end, 0, 1)
  hub.bMissoes = botaoLateral(C.tela, 'ic_missao', 'Missões', 110, -400, function() T.modalMissoes() end, 0, 1)
  hub.bPilhagem = botaoLateral(C.tela, 'ic_raio', 'Pilhagem', 110, -570, function() T.modalPilhagem() end, 0, 1)

  -- aventura
  local txt = proxFaseTxt()
  local av = U.btn(C.tela, 'ouro', '', 10, -280, 270, 480, 200, function() G.ir('aventura') end, 1, 0)
  U.img(av, 'ic_mapa', -160, 6, 140, 140)
  U.txt(av, 'AVENTURA', 64, 60, 26, 320, 80, '#3b2300', 'C', false)
  U.txt(av, txt, 26, 60, -42, 330, 40, '#5a3800', 'C', false)
  K.Breath(av, 0.025, 1.8)
  local seta = U.img(C.tela, 'brilho', -280, 270, 640, 360, '#ffe28f66', 1, 0)
  K.Front(av)
  K.Breath(seta, 0.06, 1.8)

  -- barra inferior
  local itens = {
    { 'Tripulação', 'ic_tripulacao', function() G.ir('tripulacao') end },
    { 'Formação', 'ic_formacao', function() G.ir('formacao') end },
    { 'Taverna', 'ic_caneca', function() G.ir('taverna') end },
  }
  for _, e in ipairs(G.EM_BREVE) do itens[#itens + 1] = { e.nome, e.ic, function() T.modalEmBreve(e) end, bloqueado = e } end
  local n = #itens
  local esp = math.min(180, (W - 1200) / n + 60)
  local base = U.img(C.tela, 'skin:escuro', 0, 82, n * esp + 40, 164, '#ffffff', 0.5, 0)
  for i, it in ipairs(itens) do
    local x = (i - (n + 1) / 2) * esp
    local b = U.btn(base, it.bloqueado and 'escuro' or 'azul', '', 10, x, 0, esp - 16, 140, it[3])
    local ic = U.img(b, it[2], 0, 16, 84, 84)
    U.txt(b, it[1], 24, 0, -50, esp, 36, it.bloqueado and '#9fb3c8' or '#ffffff', 'C', true)
    if it.bloqueado then
      K.SetColor(ic, '#ffffff77')
      U.img(b, 'ic_cadeado', 30, 46, 44, 44)
      U.txt(b, 'v' .. it.bloqueado.v, 20, -30, 52, 70, 30, '#ffd166', 'C', true)
    end
  end
  atualizarHub()
  hub.t = 0
  if Estado.s.login.pendente then K.After(0.6, function() if G.telaAtual == 'navio' then T.modalLogin() end end) end
end

function T.navio.update(dt)
  if hub.cen then Cenario.atualizarClima(hub.cen, C.tela, dt) end
  hub.t = (hub.t or 0) + dt
  if hub.t >= 1 then hub.t = 0; atualizarHub() end
  -- falas aleatórias da tripulação
  hub.falaT = (hub.falaT or 5) - dt
  if hub.falaT <= 0 and hub.tripulantes and #hub.tripulantes > 0 then
    hub.falaT = 7 + math.random() * 5
    local t = hub.tripulantes[math.random(#hub.tripulantes)]
    if K.Alive(t.g) then
      local b = U.painel(C.tela, t.x, t.y + 300, 420, 110, 'pergaminho')
      K.SetRaycast(b, false)
      U.txt(b, D.Herois[t.id].fala, 24, 0, 0, 390, 100, '#3b2300', 'C', false)
      K.SetScale(b, 0.3, 0.3); K.ScaleTo(b, 1, 0.25, 3, nil)
      if t.vivo then K.BonecoAnim(t.g, 'vitoria', 1) end
      K.After(3.2, function() if K.Alive(b) then K.FadeTo(b, 0, 0.3, function() K.Kill(b) end) end end)
    end
  end
end

function T.navio.fechar() hub.cen = nil; hub.bau = nil; hub.tripulantes = nil end

-- ------------------------------------------------------------------ painéis do navio
function T.modalBau()
  local r = Estado.idle()
  local P = D.Param
  local hora = {
    ouro = math.floor((P.idle_ouro_a + P.idle_ouro_b * Estado.s.vencidas) * 60),
    xp = math.floor((P.idle_xp_a + P.idle_xp_b * Estado.s.vencidas) * 60),
  }
  G.modal('Baú do Navio', 1100, 640, function(p)
    local bau = U.img(p, 'ic_bau', -330, 30, 260, 260)
    K.Bob(bau, 6, 2.2)
    U.img(p, 'brilho', -330, 30, 420, 420, '#ffd16666')
    K.Front(bau)
    U.txt(p, 'A tripulação junta tesouros enquanto você descansa.', 30, 130, 160, 640, 80, '#cfe2ff', 'C', true)
    U.txt(p, 'Acumulado (' .. G.tempo(r.seg) .. ' de ' .. P.idle_max_horas .. 'h)', 32, 130, 80, 640, 50, '#ffffff', 'C', true)
    G.premioIcones(p, r, 130, 10, 64)
    U.txt(p, 'Por hora: ' .. G.fmt(hora.ouro) .. ' de ouro e ' .. G.fmt(hora.xp) .. ' de XP  (aumenta a cada fase vencida)', 24, 130, -70, 660, 70, '#9fb3c8', 'C', false)
  end, {
    { 'Pilhagem', 'roxo', function() T.modalPilhagem() end },
    { 'Coletar', 'verde', function()
      local g = Estado.coletarIdle()
      if (g.ouro + g.xp + g.gemas) <= 0 then G.toast('O baú ainda está vazio.'); return end
      K.Som('moeda')
      local bx, by = -K.W() / 2 + 330, -230
      K.Burst(C.efeito, bx, by, 26, '#ffd166', 520, 26, 0.9, 700)
      K.Ring(C.efeito, bx, by, '#fff3b0', 360, 0.5)
      G.voar(g, bx, by)
      atualizarHub()
    end },
  })
end

function T.modalPilhagem()
  local s, P = Estado.s, D.Param
  local gratis = P.pilhagem_gratis - s.pilhagem.usadas
  G.modal('Pilhagem Rápida', 1000, 560, function(p)
    U.img(p, 'ic_raio', 0, 110, 150, 150)
    U.txt(p, 'Receba agora ' .. P.pilhagem_horas .. ' horas de recompensas do navio.', 34, 0, 0, 860, 60, '#ffffff', 'C', true)
    local txt = gratis > 0 and ('Grátis hoje: <color=#7cf29a>' .. gratis .. '</color>') or ('Custo: <color=#9bf6ff>' .. P.pilhagem_custo .. ' gemas</color>')
    U.txt(p, txt, 32, 0, -60, 860, 50, '#ffffff', 'C', true)
  end, {
    { 'Fechar', 'azul' },
    { gratis > 0 and 'Pilhar grátis' or ('Pilhar (' .. P.pilhagem_custo .. ')'), 'roxo', function()
      local r = Estado.pilhagem()
      if not r then G.toast('Gemas insuficientes.', '#ff8a7a'); return end
      K.Som('moeda')
      K.Flash('#b388ff55', 0.3)
      G.voar(r, 0, 0)
      G.toast('Pilhagem: ' .. G.premioTxt(r))
      if G.atualizarHub then G.atualizarHub() end
    end },
  })
end

function T.modalLogin()
  local s = Estado.s
  local pend = s.login.pendente
  local prox = s.login.contagem % 7 + 1
  G.modal('Diário de Bordo', 1500, 660, function(p)
    U.txt(p, 'Entre todos os dias e ganhe recompensas. O 7º dia traz um novo tripulante!', 30, 0, 170, 1300, 50, '#cfe2ff', 'C', true)
    for i, d in ipairs(D.Login) do
      local x = (i - 4) * 190
      local feitos = pend and (prox - 1) or ((s.login.contagem - 1) % 7 + 1)
      if s.login.contagem == 0 then feitos = 0 end
      local pego = i <= feitos
      local hoje = pend and i == prox
      local c = U.painel(p, x, -10, 170, 250, hoje and 'ouro' or (i == 7 and 'roxo' or 'card'))
      U.txt(c, 'Dia ' .. i, 30, 0, 96, 160, 44, hoje and '#3b2300' or '#ffffff', 'C', not hoje)
      local ic = d.heroi ~= '' and G.arteRetrato(d.heroi) or (d.gemas > 0 and 'ic_gema' or (d.ouro > 0 and 'ic_ouro' or 'ic_xp'))
      local icg = U.img(c, ic, 0, 10, i == 7 and 130 or 96, i == 7 and 130 or 96)
      local v = d.heroi ~= '' and G.curto(D.Herois[d.heroi].nome) or G.fmt(d.gemas + d.ouro + d.xp)
      U.txt(c, v, 28, 0, -86, 160, 40, hoje and '#3b2300' or '#ffd166', 'C', not hoje)
      if pego then
        K.SetColor(icg, '#ffffff66')
        local ok = U.img(c, 'skin:circulo', 0, 10, 80, 80, '#2bb673')
        U.txt(ok, 'OK', 30, 0, 2, 80, 80, '#ffffff', 'C', true)
      end
      if hoje then K.Breath(c, 0.03, 1.2) end
    end
  end, {
    { pend and 'Pegar recompensa' or 'Volte amanhã', pend and 'verde' or 'azul', function()
      if not pend then return end
      local d = Estado.pegarLogin()
      if d then
        K.Som(d.heroi ~= '' and 'ssr' or 'moeda')
        G.voar(d, 0, 0)
        if d.heroi ~= '' then G.toast('Novo tripulante: ' .. D.Herois[d.heroi].nome .. '!', '#ffd166') end
        atualizarHub()
      end
    end },
  })
end

function T.modalMissoes()
  local m
  local function montar(p)
    local s = Estado.s
    U.txt(p, 'Renovam todo dia', 26, 0, 262, 600, 40, '#9fb3c8', 'C', false)
    for i, id in ipairs(D.Missoes._ordem) do
      local ms = D.Missoes[id]
      local prog = math.min(ms.meta, s.missoes.prog[id] or 0)
      local y = 288 - i * 88
      local linha = U.painel(p, 0, y, 1240, 82, 'escuro')
      U.img(linha, 'ic_missao', 50, 0, 56, 56, '#ffffff', 0, 0.5)
      U.txt(linha, ms.nome, 30, 330, 12, 480, 40, '#ffffff', 'L', true, 0, 0.5)
      local bar = U.bar(linha, 330, -20, 480, 16, '#1b1a2e', '#7cf29a', 0, 0.5)
      K.SetBar(bar, prog / ms.meta)
      U.txt(linha, prog .. '/' .. ms.meta, 24, 640, -18, 120, 30, '#cfe2ff', 'L', true, 0, 0.5)
      G.premioIcones(linha, ms, 880, 0, 44, 0, 0.5)
      if s.missoes.pegas[id] then
        U.txt(linha, 'Feito', 30, -100, 0, 160, 60, '#7cf29a', 'C', true, 1, 0.5)
      elseif prog >= ms.meta then
        local b = U.btn(linha, 'verde', 'Pegar', 30, -100, 0, 170, 64, function()
          if Estado.pegarMissao(id) then
            K.Som('moeda')
            G.voar(ms, 0, y)
            K.Clear(p); montar(p)
            atualizarHub()
          end
        end, 1, 0.5)
        K.Breath(b, 0.04, 1)
      else
        U.txt(linha, 'Em andamento', 22, -100, 0, 180, 60, '#9fb3c8', 'C', false, 1, 0.5)
      end
    end
  end
  m = G.modal('Missões Diárias', 1340, 760, function(p)
    local corpo = U.box(p, 0, 0, 1340, 760)
    montar(corpo)
  end, { { 'Fechar', 'azul' } })
end

function T.modalEmBreve(e)
  G.modal(e.nome, 1000, 600, function(p)
    local ic = U.img(p, e.ic, -300, 30, 220, 220)
    K.Bob(ic, 8, 2.4)
    U.img(p, 'ic_cadeado', -220, -50, 90, 90)
    U.txt(p, 'Chega na versão ' .. e.v, 40, 120, 120, 560, 60, '#ffd166', 'C', true)
    U.txt(p, e.desc, 32, 120, 10, 560, 160, '#ffffff', 'C', true)
  end, { { 'Ver roteiro', 'roxo', function() T.roteiro() end }, { 'Fechar', 'azul' } })
end

local ROTEIRO = {
  { '0.1', 'Beta (agora)', 'Enseada do Farol com 10 fases e o chefe da Maré Negra, 6 heróis com Marcas, taverna, formação, baú do navio, missões e login.' },
  { '0.2', 'Arena', 'Batalhas contra formações de outros jogadores e ranking por temporada.' },
  { '0.3', 'Equipamentos', 'Armas, casacos e relíquias com conjuntos, forja e aprimoramento.' },
  { '0.4', 'Novos mares', 'As ilhas em silhueta no mapa: novas fases, novos chefes da Liga do Farol e novos heróis.' },
  { '0.5', 'Guildas', 'Tripulações aliadas, chat e chefe semanal da guilda.' },
  { '0.6', 'Eventos', 'Eventos sazonais, banners especiais e passe de temporada.' },
  { '0.7', 'Torre do Farol', 'Modo infinito com andares e recompensas por marco.' },
  { '1.0', 'Lançamento', 'Conta online, servidor, loja e atualização de conteúdo sem passar pela loja de apps.' },
}

function T.roteiro()
  G.modal('Roteiro de Atualizações', 1500, 900, function(p)
    local cont = K.Scroll(p, 0, -10, 1400, 640, 1400, #ROTEIRO * 120 + 20, true, 0.5, 0.5)
    for i, r in ipairs(ROTEIRO) do
      local y = -70 - (i - 1) * 120
      local l = U.painel(cont, 700, y, 1360, 108, i == 1 and 'verde' or 'escuro', 0, 1)
      local tag = U.painel(l, 90, 0, 140, 76, i == 1 and 'ouro' or 'azul', 0, 0.5)
      U.txt(tag, 'v' .. r[1], 34, 0, 2, 130, 70, i == 1 and '#3b2300' or '#ffffff', 'C', i ~= 1)
      U.txt(l, r[2], 34, 380, 22, 360, 50, '#ffd166', 'L', true, 0, 0.5)
      U.txt(l, r[3], 24, 760, -20, 1060, 60, '#ffffff', 'L', true, 0, 0.5)
    end
  end, { { 'Fechar', 'azul' } })
end

-- ------------------------------------------------------------------ demais telas (arquivos próprios)
for _, nome in ipairs({ 'TelaAventura', 'TelaTripulacao', 'TelaFormacao', 'TelaTaverna' }) do
  local mod = require('UI.' .. nome)
  for k, v in pairs(mod) do T[k] = v end
end
G.Telas = T

return T
