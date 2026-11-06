-- Visão da batalha lateral (paisagem). O motor Game.Battle decide tudo; aqui só transformamos eventos em animação.
local K, U, D, Estado, Formula = G.K, G.U, G.D, G.Estado, G.Formula
local Battle = require('Game.Battle')
local Cenario = require('UI.Cenario')
local C = G.camadas
local B = {}
local st = {}

-- posição dos pés (a partir do centro da tela) do lado aliado; o lado inimigo espelha o x
local POS = {
  { -320, -130 }, { -270, -315 },
  { -640, -70 }, { -700, -235 }, { -610, -400 },
}

local function escalaPorProfundidade(fy) return 1 + ((-fy) - 100) / 290 * 0.16 end

local function nomeDe(v) return v.lado == 'a' and D.Herois[v.id].nome or D.Inimigos[v.id].nome end
local function arteDe(v) return v.lado == 'a' and G.arteHeroi(v.id) or G.arteInimigo(v.id) end
local function distante(v)
  if v.lado == 'a' then return D.Herois[v.id].linha == 'tras' end
  return v.id == 'atirador'
end

-- ------------------------------------------------------------------ montagem das unidades
local function criarView(e)
  local p = POS[e.slot] or POS[1]
  local fx, fy = p[1], p[2]
  if e.lado == 'i' then fx = -fx end
  local s = escalaPorProfundidade(fy)
  if e.chefe then s = s * 1.38; fx = fx * 1.2 end
  local w, h = 250 * s, 340 * s
  local v = {
    guid = e.guid, lado = e.lado, slot = e.slot, id = e.id, elemento = e.elemento, chefe = e.chefe,
    hp = e.hp, max = e.max, fx = fx, fy = fy, s = s, bx = fx, by = fy + h / 2, w = w, h = h,
  }
  v.cx, v.cy = v.bx, v.by
  return v
end

local function montarView(v)
  local g = U.box(st.palco, v.bx, v.by, v.w, v.h)
  v.g = g
  U.img(g, 'skin:circulo', 0, -v.h / 2 + 4, 160 * v.s, 36 * v.s, '#00000066')
  v.aura = U.img(g, 'brilho', 0, 0, v.w * 1.2, v.w * 1.2, '#ff5d5d00')
  local arte
  if v.lado == 'a' then arte, v.boneco = U.figura(g, v.id, 0, 0, v.w, v.h) end
  if not v.boneco then
    -- arte parada: respira com escala; o boneco com esqueleto respira pelos ossos
    if not arte then arte = U.img(g, arteDe(v), 0, 0, v.w, v.h) end
    if v.lado == 'i' then K.SetScale(arte, -1, 1) end
    K.Breath(arte, 0.02, 1.6 + math.random() * 0.6)
  end
  v.arte = arte
  local topo = v.h / 2 + 20
  local cor = v.lado == 'a' and '#7cf29a' or '#ff5d5d'
  v.hpBar = U.bar(g, 0, topo + 14, 150, 18, '#1b1a2e', cor)
  v.escBar = U.bar(g, 0, topo + 30, 150, 8, '#00000000', '#9bd1ff')
  K.SetBar(v.escBar, 0)
  v.furBar = U.bar(g, 0, topo, 150, 9, '#1b1a2e', '#ffd166')
  K.SetBar(v.furBar, 0)
  U.img(g, 'skin:circulo', -92, topo + 14, 26, 26, G.EL[v.elemento].cor)
  U.txt(g, tostring(st.nivelDe[v.guid] or ''), 20, 92, topo + 14, 60, 30, '#ffffff', 'L', true, 0.5, 0.5)
  if v.chefe then U.txt(g, 'CHEFE', 30, 0, topo + 56, 200, 40, '#ff8a7a', 'C', true) end
  v.tonto = U.img(g, 'ic_estrela', 0, topo + 60, 52, 52, '#ffe28f')
  K.Spin(v.tonto, 220)
  K.SetActive(v.tonto, false)
end

local function pedir(v)
  local u = st.batalha:unidade(v.guid)
  if not u or not u.vivo then return end
  if u.furia < 100 then G.toast('Fúria ainda não está cheia.'); return end
  st.batalha:pedirEspecial(v.guid)
end

local function montarCartas()
  local al = {}
  for _, v in ipairs(st.views) do if v.lado == 'a' then al[#al + 1] = v end end
  table.sort(al, function(a, b) return a.slot < b.slot end)
  local n = #al
  local hud = U.box(C.tela, 0, 100, n * 172, 190, 0.5, 0)
  for i, v in ipairs(al) do
    local x = (i - (n + 1) / 2) * 172
    local c = U.btn(hud, '', '', 10, x, 0, 158, 178, function() pedir(v) end)
    v.cGlow = U.img(c, 'brilho', 0, 0, 280, 280, '#ffd166cc')
    K.Breath(v.cGlow, 0.08, 0.7)
    K.SetActive(v.cGlow, false)
    local fr = U.img(c, 'skin:card', 0, 0, 158, 178, G.RAR[D.Herois[v.id].raridade])
    U.img(fr, 'skin:card', 0, 0, 148, 168, '#16305a')
    local clip = K.Clip(fr, 0, 12, 142, 122, 0.5, 0.5)
    U.img(clip, G.arteRetrato(v.id), 0, -8, 150, 150)
    v.cFur = U.bar(fr, 0, -62, 132, 16, '#1b1a2e', '#ffd166')
    v.cHp = U.bar(fr, 0, -79, 132, 10, '#1b1a2e', '#7cf29a')
    K.SetBar(v.cFur, 0)
    v.cTxt = U.txt(fr, '', 24, 0, 58, 156, 32, '#ffd166', 'C', true)
    v.carta = c
  end
end

-- ------------------------------------------------------------------ efeitos
local function tremer(forca, dur)
  if st.tempo < (st.tremeAte or 0) then return end
  st.tremeAte = st.tempo + dur
  K.Shake(st.palco, forca, dur)
end

local function piscar(v, cor)
  if not K.Alive(v.arte) then return end
  K.SetColor(v.arte, cor)
  K.After(0.09, function() if K.Alive(v.arte) and not v.morto then K.SetColor(v.arte, '#ffffff') end end)
end

-- ------------------------------------------------------------------ física de apresentação
-- Só visual: o motor determinístico já decidiu tudo. Aqui o golpe ganha corpo, peso e impacto.
local function fx(n) return K.Existe(n) and n or 'brilho' end

local function poeira(v, dir)
  K.Particulas(st.fx, fx('fx_fumaca'), v.cx - dir * 30, v.fy + 20, 4, '#d9c6a5aa', 220, dir > 0 and 160 or 20, 50, 70, 0.55, -80, -9999, false)
end

-- volta ao lugar depois de um avanço ou de um empurrão
local function voltar(v, dur)
  if v.morto or not K.Alive(v.g) then return end
  K.Cancelar(v.g); K.Parar(v.g)
  K.MoveTo(v.g, v.bx, v.by, dur or 0.22, 1, nil)
  K.SetRot(v.arte, 0)
end

-- empurrão físico: o alvo é arremessado para trás, quica no chão e volta ao lugar
local function empurrar(a, dir, forca)
  if a.morto or not K.Alive(a.g) then return end
  K.Cancelar(a.g); K.Parar(a.g)
  K.Lancar(a.g, dir * 360 * forca, 120 + 160 * forca, 2600, a.by, 0.25, 3.5, 0, 0, false, function() voltar(a, 0.25) end)
  if a.boneco then
    -- o esqueleto reage: tronco e cabeça jogados para trás, o resto balança pela inércia do empurrão
    K.BonecoAnim(a.arte, 'dano', 1)
    K.BonecoImpulso(a.arte, 'cabeca', 260 * forca)
    K.BonecoImpulso(a.arte, 'peito', 120 * forca)
    return
  end
  K.SetRot(a.arte, -dir * 6 * forca)
  K.After(0.25, function() if K.Alive(a.arte) and not a.morto then K.RotTo(a.arte, 0, 0.2, 1) end end)
end

-- anima o ataque e devolve em quantos segundos ele chega ao alvo (o dano aparece no impacto)
local function golpear(v, alvo)
  local dir = v.lado == 'a' and 1 or -1
  local vel = st.vel
  local cor = G.EL[v.elemento].cor
  if distante(v) then
    -- tiro: recuo, clarão na boca da arma e projétil em arco com rastro
    local x0, y0 = v.cx + dir * v.w * 0.35, v.cy + v.h * 0.12
    local x1, y1 = alvo.cx - dir * alvo.w * 0.15, alvo.cy + alvo.h * 0.05
    local tempo = 0.24 / vel
    K.Cancelar(v.g)
    K.MoveTo(v.g, v.bx - dir * 22, v.by, 0.05 / vel, 1, function() K.MoveTo(v.g, v.bx, v.by, 0.18 / vel, 1, nil) end)
    K.Particulas(st.fx, fx('fx_faisca'), x0, y0, 5, cor, 320, dir > 0 and 0 or 180, 40, 34, 0.3, 0, -9999, true)
    K.Projetil(st.fx, 'particula', x0, y0, x1, y1, tempo, 30, 26, 26, cor, true, true, cor, nil)
    return tempo
  end
  -- corpo a corpo: corre inclinado até o alvo, golpeia e volta
  local ida = 0.13 / vel
  local px = alvo.bx - dir * (alvo.w * 0.42 + v.w * (v.boneco and 0.08 or 0.18))
  local py = alvo.fy + v.h * 0.5
  K.Cancelar(v.g); K.Parar(v.g)
  -- boneco: investida, frigideira erguida e a pancada no instante da chegada (a pose "pancada" da animação)
  if v.boneco then
    K.BonecoAnim(v.arte, 'golpe', vel)
    -- o arco da frigideira fica no ar por um instante (do cabo até a borda)
    K.BonecoRastro(v.arte, 'frigideira', 0.55, 1.5, st.fx, '#fff1c4cc', 0.34 / vel)
  else
    K.SetRot(v.arte, -dir * 9)
  end
  poeira(v, dir)
  K.MoveTo(v.g, px, py, ida, 2, function()
    if not v.boneco then K.SetRot(v.arte, dir * 6) end
    K.After((v.boneco and 0.2 or 0.16) / vel, function() voltar(v, 0.22 / vel) end)
  end)
  return ida
end

-- corte de luz e clarão de impacto no alvo
local function corte(a, cor, grande)
  local s = grande and 360 or 250
  local g = U.img(st.fx, fx('fx_corte'), a.cx, a.cy + a.h * 0.05, s, s, cor or '#ffffff')
  K.Aditivo(g)
  K.SetRot(g, math.random(-50, 50))
  K.SetScale(g, 0.4, 0.4)
  K.ScaleTo(g, grande and 1.4 or 1.1, 0.16, 1, nil)
  K.FadeTo(g, 0, 0.24, function() K.Kill(g) end)
  local imp = U.img(st.fx, fx('fx_impacto'), a.cx, a.cy, s * 0.8, s * 0.8, '#ffffff')
  K.Aditivo(imp)
  K.SetScale(imp, 0.3, 0.3)
  K.ScaleTo(imp, 1.2, 0.12, 1, nil)
  K.FadeTo(imp, 0, 0.2, function() K.Kill(imp) end)
end

-- criatura de luz que cresce no lugar e some (polvo, tartaruga, escudo)
local function brilhoEm(sp, x, y, w, h, cor, dur, escala)
  local g = U.img(st.fx, fx(sp), x, y, w, h, cor or '#ffffff')
  K.Aditivo(g)
  K.SetScale(g, 0.2, 0.2)
  K.ScaleTo(g, escala or 1, dur * 0.4, 3, nil)
  K.After(dur * 0.6, function() if K.Alive(g) then K.FadeTo(g, 0, dur * 0.4, function() K.Kill(g) end) end end)
  return g
end

-- Abraço do Polvo: quatro tentáculos de luz com física de corda saem da Marca no
-- antebraço, chicoteiam até o alvo, se enrolam, apertam, erguem e batem com ele no chão. O dano (e o
-- atordoamento) aparece no instante da batida: devolve esse tempo.
local CFG_TENTACULOS = {
  -- altura no alvo (fração de h), voltas da espiral, espessura, fase
  { -0.10, 1.05, 58, 0.0 }, { 0.05, 1.25, 50, 1.7 }, { 0.20, 1.0, 44, 3.2 }, { 0.32, 0.85, 36, 4.6 },
}
local BATIDA = 0.84

local function abracoDoPolvo(v, alvos, depois)
  local dir = v.lado == 'a' and 1 or -1
  local a = alvos[1]
  if not a then return 0.15 end
  local tents = {}
  depois(0, function()
    -- o espírito do polvo acende sobre o braço da Marca (pequeno: o Pipo continua visível)
    local ox, oy = v.cx + dir * v.w * 0.25, v.cy
    if v.boneco then
      K.BonecoAnim(v.arte, 'especial', 1)
      ox, oy = K.BonecoPonto(v.arte, 'anteB', 0.4, st.fx)
    end
    local esp = brilhoEm('fx_polvo', ox + dir * 40, oy + 10, 240, 200, '#ffffffaa', 1.0, 1.0)
    K.Sway(esp, 8, 0.4)
    K.Particulas(st.fx, fx('fx_faisca'), ox, oy, 12, '#d35cff', 460, dir > 0 and 0 or 180, 120, 26, 0.5, 0, -9999, true)
    K.Som('especial')
  end)
  for i, c in ipairs(CFG_TENTACULOS) do
    depois(0.1 + 0.035 * (i - 1), function()
      -- com esqueleto, a raiz acompanha o antebraço; sem ele, sai da frente do herói
      local t = K.Tentaculo(st.fx, v.cx + dir * v.w * 0.25, v.cy, c[3], '#f4e0ff', '#c46bffcc')
      if v.boneco then K.TentPreso(t, v.arte, 'anteB', 0.25 + 0.09 * i) end
      K.TentAlcancar(t, a.g, -dir * a.w * 0.12, a.h * c[1], 0.2, (i % 2 == 0 and 1 or -1) * 110)
      tents[i] = t
    end)
  end
  -- enrola e aperta: o alvo é espremido e solta faíscas
  depois(0.32, function()
    for i, t in ipairs(tents) do
      local c = CFG_TENTACULOS[i]
      K.TentEnrolar(t, a.g, a.h * c[1], a.w * 0.34, 20 + 4 * i, a.h * 0.1, c[2], c[4])
    end
    K.Punch(a.arte, -0.1, 0.22)
    K.Pausa(0.05)
    K.Particulas(st.fx, fx('fx_faisca'), a.cx, a.cy, 14, '#e39bff', 560, 90, 320, 30, 0.6, 1400, a.fy, true)
    K.Som('golpe')
  end)
  depois(0.42, function() for _, t in ipairs(tents) do K.TentApertar(t, 0.72, 0.18) end end)
  -- ergue o alvo no ar...
  depois(0.55, function()
    if a.morto or not K.Alive(a.g) then return end
    K.Cancelar(a.g); K.Parar(a.g)
    K.MoveTo(a.g, a.bx - dir * 60, a.by + 200, 0.2, 1, nil)
    K.RotTo(a.arte, dir * 12, 0.2, 1)
  end)
  -- ...e bate com ele no chão; o dano e o atordoamento (na fila do motor) saem no instante da batida
  local function liberar() st.hold = math.min(st.hold, 0.01) end
  depois(BATIDA - 0.08, function()
    if a.morto or not K.Alive(a.g) then liberar(); return end
    K.MoveTo(a.g, a.bx, a.by, 0.08, 2, function()
      liberar()
      K.SetRot(a.arte, 0)
      tremer(28, 0.4)
      K.Pausa(0.08)
      K.Flash('#d35cff44', 0.2)
      K.Ring(st.fx, a.cx, a.fy + 30, '#e8b0ff', 560, 0.45)
      K.Particulas(st.fx, fx('fx_fumaca'), a.cx, a.fy + 20, 9, '#d9c6a5bb', 560, 90, 170, 120, 0.8, 500, -9999, false)
      K.Particulas(st.fx, fx('fx_faisca'), a.cx, a.fy + 30, 12, '#fff0a0', 760, 90, 140, 26, 0.6, 1800, a.fy, true)
      K.Som('critico')
      K.Vibrate()
    end)
  end)
  depois(BATIDA + 0.06, function() for _, t in ipairs(tents) do K.TentSoltar(t, 0.3) end end)
  -- a fila espera a batida (liberar); o limite só vale se algo travar a coreografia
  return BATIDA + 0.6
end

-- A Marca de cada herói vira um efeito com física. Começa depois do cut-in ('atraso') e devolve
-- quanto tempo a criatura leva para chegar: o dano do especial (na fila) espera por ela.
local function efeitoEspecial(v, sk, alvos, atraso)
  local id = sk.id or ''
  local dir = v.lado == 'a' and 1 or -1
  local W = K.W()
  local function depois(t, fn) K.After(atraso + t, function() if st.batalha and K.Alive(st.fx) then fn() end end) end
  if id == 'u_pipo' then
    return abracoDoPolvo(v, alvos, depois)
  elseif id == 'u_marina' then
    -- a moreia nada em arco até a linha de trás e estoura em respingos
    for i, a in ipairs(alvos) do
      depois(0.08 * (i - 1), function()
        K.Projetil(st.fx, fx('fx_moreia'), v.cx, v.cy + 40, a.cx, a.cy, 0.42, 160, 420, 350, '#ffffff', false, true, '#3cf0b0', function()
          K.Particulas(st.fx, fx('fx_respingo'), a.cx, a.cy, 8, '#bdf4ff', 520, 90, 160, 70, 0.8, 1600, a.fy, true)
        end)
      end)
    end
    return 0.5
  elseif id == 'u_lina' then
    -- o peixe-leão abre os espinhos sobre a Lina e dispara faíscas que caem queimando
    depois(0, function() brilhoEm('fx_peixeleao', v.cx + dir * 40, v.cy + v.h * 0.55, 360, 300, '#ffffff', 0.8, 1.0) end)
    for i, a in ipairs(alvos) do
      depois(0.1 + 0.07 * (i - 1), function()
        K.Projetil(st.fx, fx('fx_faisca'), v.cx + dir * 40, v.cy + v.h * 0.55, a.cx, a.cy, 0.3, 120, 90, 90, '#fff07a', false, true, '#e6ee3a', function()
          K.Particulas(st.fx, 'particula', a.cx, a.cy, 6, '#ff9f43', 380, 90, 200, 18, 0.6, 1400, a.fy, true)
        end)
      end)
    end
    return 0.55
  elseif id == 'u_bento' then
    -- o tubarão atravessa a linha da frente inimiga e levanta água
    local y, n = 0, 0
    for _, a in ipairs(alvos) do y = y + a.cy; n = n + 1 end
    y = n > 0 and y / n or v.cy
    depois(0, function()
      K.Projetil(st.fx, fx('fx_tubarao'), -W / 2 - 300, y, W / 2 + 400, y, 0.6, 0, 620, 520, '#ffffff', false, true, '#5560ff', nil)
      tremer(20, 0.4)
    end)
    for _, a in ipairs(alvos) do
      depois(0.6 * (a.cx + W / 2 + 300) / (W + 700), function()
        K.Particulas(st.fx, fx('fx_respingo'), a.cx, a.cy, 10, '#bdf4ff', 640, 90, 200, 80, 0.8, 1700, a.fy, true)
      end)
    end
    return 0.45
  elseif id == 'u_mirto' then
    -- a tartaruga sobe sobre a tripulação e a luz de cura sobe de cada um (gravidade invertida)
    depois(0, function()
      local g = brilhoEm('fx_tartaruga', -W * 0.22, 160, 520, 520, '#ffffff', 1.1, 1.0)
      K.MoveTo(g, -W * 0.22, 260, 1.0, 1, nil)
      for _, a in ipairs(alvos) do
        brilhoEm('fx_cura', a.cx, a.cy + 40, 240, 320, '#ffffff', 0.9, 1.0)
        K.Particulas(st.fx, fx('fx_faisca'), a.cx, a.fy + 20, 8, '#7cf29a', 260, 90, 70, 26, 0.9, -500, -9999, true)
      end
    end)
    return 0.3
  elseif id == 'u_kalu' then
    -- a raia abre as asas sobre o time e deixa um escudo em cada um
    depois(0, function()
      K.Projetil(st.fx, fx('fx_raia'), -W / 2 - 300, 260, W * 0.05, 120, 0.55, 80, 640, 540, '#ffffff', false, true, '#9b6bff', nil)
    end)
    for _, a in ipairs(alvos) do depois(0.45, function() brilhoEm('fx_escudo', a.cx, a.cy, 300, 300, '#ffffff', 1.0, 1.0) end) end
    return 0.55
  elseif id == 'u_barbasal' then
    -- Tempestade de Sal: cristais caem sobre a tripulação e explodem no chão
    for _, a in ipairs(alvos) do
      depois(0, function() K.Particulas(st.fx, fx('fx_faisca'), a.cx, a.cy + 420, 10, '#e6f4ff', 260, -90, 50, 40, 0.6, 2200, a.fy, true) end)
      depois(0.3, function() brilhoEm('fx_impacto', a.cx, a.cy, 260, 260, '#bfe9ff', 0.4, 1.1) end)
    end
    depois(0.3, function() tremer(22, 0.4) end)
    return 0.35
  end
  for _, a in ipairs(alvos) do depois(0, function() K.Ring(st.fx, a.cx, a.cy, G.EL[v.elemento].cor, 420, 0.4) end) end
  return 0.15
end

local function cutin(v, sk)
  local W = K.W()
  local aliado = v.lado == 'a'
  local cor = G.EL[v.elemento].cor
  local lado = aliado and -1 or 1
  local box = U.box(C.efeito, 0, 70, W + 300, 360)
  K.SetRot(box, aliado and 4 or -4)
  U.img(box, '', 0, 0, W + 500, 300, '#000000d0')
  local listra = U.img(box, '', 0, 0, W + 500, 300, cor .. '55')
  K.SetScale(listra, 1, 0.05); K.ScaleTo(listra, 1, 0.16, 1, nil)
  U.img(box, '', 0, 146, W + 500, 8, cor)
  U.img(box, '', 0, -146, W + 500, 8, cor)
  U.img(box, 'brilho', lado * W * 0.22, 0, 760, 760, cor .. 'aa')
  local arte = U.img(box, arteDe(v), lado * (W / 2 + 400), -60, 540, 740)
  if not aliado then K.SetScale(arte, -1, 1) end
  K.MoveTo(arte, lado * W * 0.22, -10, 0.2, 1, nil)
  local nome = U.txt(box, sk.nome, 72, -lado * (W / 2 + 600), 34, 1100, 100, '#ffffff', 'C', true)
  K.MoveTo(nome, -lado * W * 0.1, 34, 0.2, 1, nil)
  local quem = U.txt(box, nomeDe(v), 34, -lado * W * 0.1, -48, 1100, 50, cor, 'C', true)
  K.SetAlpha(quem, 0); K.FadeTo(quem, 1, 0.3, nil)
  K.Som('especial')
  K.Flash(cor .. '55', 0.3)
  K.Ring(st.fx, v.cx, v.cy, cor, 520, 0.5)
  local d = 0.85 / st.vel
  K.After(d, function() if K.Alive(box) then K.FadeTo(box, 0, 0.12, function() K.Kill(box) end) end end)
  st.hold = d + 0.05
end

-- ------------------------------------------------------------------ eventos do motor
local tratar = {}

function tratar.ataque(e)
  local v, a = st.porGuid[e.de], st.porGuid[e.alvo]
  if v and a then st.chegada[e.de] = { t = golpear(v, a), alvo = e.alvo } end
  st.fxGrande = nil
end

-- onda da Maré Negra: varre do chefe até atrás da tripulação
local function ondaMare(chefe)
  local W = K.W()
  local x0 = chefe and chefe.cx or W / 2
  K.Projetil(st.fx, fx('fx_mare'), x0, -110, -W / 2 - 520, -160, 0.7, 40, 900, 720, '#ffffff', false, false, '#e0307a', nil)
  K.Particulas(st.fx, fx('fx_respingo'), x0 - 200, -200, 10, '#e0307a', 700, 160, 60, 90, 0.9, 1500, -440, false)
end

local function mostrarDano(e)
  local a, de = st.porGuid[e.alvo], st.porGuid[e.de]
  if not a then return end
  a.hp = e.hp
  K.SetBar(a.hpBar, a.hp / a.max)
  if a.cHp then K.SetBar(a.cHp, a.hp / a.max) end
  if de and de.lado == 'a' then st.danoPor[de.guid] = (st.danoPor[de.guid] or 0) + e.v + e.abs end
  local grande = st.fxGrande ~= nil
  local cor, tam, txt = '#ffffff', 48, G.fmt(e.v)
  if a.lado == 'a' then cor = '#ff6b6b'; tam = 44 end
  if e.rel == 1 then cor = a.lado == 'a' and '#ff4d4d' or '#ffb347'; tam = tam + 6 end
  if e.rel == -1 then cor = '#b8c7dc'; tam = tam - 6 end
  if e.crit then cor = '#ffd166'; tam = tam + 18; txt = txt .. '!' end
  if e.mare then cor = '#ff4d9d'; tam = 58 end
  if grande then tam = tam + 10 end
  if e.v > 0 then K.Float(st.fx, txt, tam, a.cx + math.random(-40, 40), a.cy + a.h * 0.5 + 40, cor) end
  if e.abs > 0 then K.Float(st.fx, 'Escudo -' .. G.fmt(e.abs), 26, a.cx, a.cy + a.h * 0.5 + 90, '#9bd1ff') end
  -- empurrão para longe de quem bateu: mais forte no crítico, no especial e na Maré Negra
  local dirA = a.lado == 'a' and -1 or 1
  empurrar(a, dirA, e.mare and 2.2 or (grande and 1.6 or (e.crit and 1.2 or 0.6)))
  if e.crit or grande or e.mare then K.Pausa(0.05) end
  -- frigideirada do Pipo: anel de choque e estrelinhas de desenho animado
  if de and de.boneco and not grande and not e.mare then
    K.Ring(st.fx, a.cx, a.cy + a.h * 0.12, '#fff2c0', 320, 0.25)
    K.Particulas(st.fx, fx('ic_estrela'), a.cx, a.cy + a.h * 0.3, 3, '#ffe28f', 420, 90, 140, 38, 0.6, 1300, a.fy, false)
    tremer(6, 0.1)
  end
  piscar(a, '#ff8080')
  local ec = de and G.EL[de.elemento].cor or '#ffffff'
  if e.mare then ec = '#ff4d9d' end
  corte(a, ec, grande or e.crit)
  K.Particulas(st.fx, fx('fx_faisca'), a.cx, a.cy, grande and 14 or 6, ec, grande and 700 or 420, dirA > 0 and 30 or 150, 120, 30, 0.5, 1400, a.fy, true)
  if grande then
    tremer(18, 0.25)
    K.Ring(st.fx, a.cx, a.cy, ec, 420, 0.4)
  elseif e.crit then
    tremer(9, 0.15)
  end
  if st.tempo - (st.ultimoSom or 0) > 0.05 then
    st.ultimoSom = st.tempo
    K.Som(e.crit and 'critico' or 'golpe')
  end
  K.SetBar(a.escBar, (e.escudo or 0) / a.max)
end

-- o dano aparece quando o golpe chega (corrida ou projétil); a onda da Maré Negra chega antes do dano dela
function tratar.dano(e)
  local c = e.de and st.chegada[e.de]
  local atraso = 0
  if c and c.alvo == e.alvo then st.chegada[e.de] = nil; atraso = c.t end
  if e.mare then
    if (st.ondaAte or 0) < st.tempo then st.ondaAte = st.tempo + 0.6; ondaMare(st.porGuid[e.de]) end
    atraso = 0.35
  end
  if atraso > 0 then
    st.alvoAte[e.alvo] = math.max(st.alvoAte[e.alvo] or 0, st.tempo + atraso)
    K.After(atraso, function() if st.batalha and K.Alive(st.fx) then mostrarDano(e) end end)
  else
    mostrarDano(e)
  end
end

function tratar.esquiva(e)
  local function mostrar()
    local a = st.porGuid[e.alvo]
    if not a or a.morto then return end
    K.Float(st.fx, 'Esquivou', 32, a.cx, a.cy + a.h * 0.5 + 40, '#cfe2ff')
    local dir = a.lado == 'a' and -1 or 1
    K.Cancelar(a.g); K.Parar(a.g)
    K.Lancar(a.g, dir * 420, 380, 2800, a.by, 0, 2, 0, 0, false, function() voltar(a, 0.2) end)
  end
  local atraso = 0
  for k, c in pairs(st.chegada) do if c.alvo == e.alvo then atraso = math.max(atraso, c.t); st.chegada[k] = nil end end
  if atraso > 0 then K.After(atraso, function() if st.batalha and K.Alive(st.fx) then mostrar() end end) else mostrar() end
end

-- queda com física: arremessado para trás girando, quica no chão e some
local function morrer(e)
  local a = st.porGuid[e.guid]
  if not a or a.morto then return end
  a.morto = true
  local dir = a.lado == 'a' and -1 or 1
  K.SetColor(a.arte, '#8a8a9a')
  K.StopLoop(a.arte)
  -- boneco: músculos soltos, o corpo cai mole pelo próprio peso enquanto voa
  if a.boneco then K.BonecoFlacido(a.arte, 0.08); K.BonecoAnim(a.arte, 'morto', 1) end
  K.Cancelar(a.g); K.Parar(a.g)
  K.Lancar(a.g, dir * 520, 820, 2600, a.by - 40, 0.35, 1.2, dir * 420, 1.8, false, nil)
  K.Particulas(st.fx, fx('fx_fumaca'), a.cx, a.fy + 30, 6, '#d0d0e0aa', 260, 90, 160, 90, 0.8, -60, -9999, false)
  if a.chefe then K.Flash('#ffffffaa', 0.4); tremer(26, 0.5); K.Pausa(0.12) end
  if a.carta then K.SetGray(a.carta, true); K.SetActive(a.cGlow, false); K.SetText(a.cTxt, '<color=#ff8a7a>Caiu</color>') end
end

function tratar.morte(e)
  local ate = st.alvoAte[e.guid]
  if ate and ate > st.tempo then
    K.After(ate - st.tempo + 0.05, function() if st.batalha and K.Alive(st.fx) then morrer(e) end end)
  else
    morrer(e)
  end
end

function tratar.especial(e)
  local v = st.porGuid[e.de]
  if not v then return end
  local u = st.batalha:unidade(e.de)
  local sk = u and u.ult or { nome = 'Especial', id = '' }
  local dir = v.lado == 'a' and 1 or -1
  st.chegada[e.de] = nil
  K.Cancelar(v.g); K.Parar(v.g)
  K.MoveTo(v.g, v.bx + dir * 120, v.by, 0.12, 1, function() K.MoveTo(v.g, v.bx, v.by, 0.3, 1, nil) end)
  st.fxGrande = v.guid
  cutin(v, sk)
  -- a criatura da Marca entra depois do cut-in; o dano do especial espera ela chegar
  local alvos = {}
  for _, g in ipairs(e.alvos or {}) do local a = st.porGuid[g]; if a then alvos[#alvos + 1] = a end end
  st.hold = st.hold + efeitoEspecial(v, sk, alvos, st.hold)
  if G.autoteste and v.lado == 'a' then G.autoteste.cutin = true end
end

function tratar.efeito(e)
  local a = st.porGuid[e.alvo]
  if not a then return end
  if e.efeito == 'atordoar' then
    K.Float(st.fx, 'Atordoado!', 30, a.cx, a.cy + a.h * 0.5, '#ffe28f')
  elseif e.efeito == 'queimar' then
    K.Float(st.fx, 'Queimando!', 30, a.cx, a.cy + a.h * 0.5, '#ff9f43')
  elseif e.efeito == 'buff' then
    K.Float(st.fx, 'ATQ+', 34, a.cx, a.cy + a.h * 0.4, '#ff7b5c')
    K.Ring(st.fx, a.cx, a.cy, '#ff7b5c', 300, 0.45)
  end
end

function tratar.cura(e)
  local a = st.porGuid[e.alvo]
  if not a then return end
  a.hp = e.hp
  K.SetBar(a.hpBar, a.hp / a.max)
  if a.cHp then K.SetBar(a.cHp, a.hp / a.max) end
  K.Float(st.fx, '+' .. G.fmt(e.v), 46, a.cx, a.cy + a.h * 0.5 + 40, '#7cf29a')
  K.Burst(st.fx, a.cx, a.cy - a.h * 0.3, 12, '#7cf29a', 260, 20, 0.9, -400)
  piscar(a, '#b8ffcc')
  if st.tempo - (st.ultimoSom or 0) > 0.05 then st.ultimoSom = st.tempo; K.Som('cura') end
end

function tratar.escudo(e)
  local a = st.porGuid[e.alvo]
  if not a then return end
  K.SetBar(a.escBar, e.escudo / a.max)
  K.Ring(st.fx, a.cx, a.cy, '#9bd1ff', 340, 0.5)
  K.Float(st.fx, 'Escudo', 30, a.cx, a.cy + a.h * 0.4, '#9bd1ff')
end

function tratar.queimadura(e)
  local a = st.porGuid[e.alvo]
  if not a then return end
  a.hp = e.hp
  K.SetBar(a.hpBar, a.hp / a.max)
  if a.cHp then K.SetBar(a.cHp, a.hp / a.max) end
  K.Float(st.fx, G.fmt(e.v), 34, a.cx, a.cy + a.h * 0.2, '#ff9f43')
  K.Burst(st.fx, a.cx, a.cy - a.h * 0.2, 8, '#ff9f43', 200, 22, 0.7, -300)
end

-- ------------------------------------------------------------------ Maré Negra (telégrafo do chefe)
local function limparCarga()
  local c = st.carga
  if not c then return end
  st.carga = nil
  if K.Alive(c.box) then K.FadeTo(c.box, 0, 0.2, function() K.Kill(c.box) end) end
  if K.Alive(c.veu) then K.FadeTo(c.veu, 0, 0.3, function() K.Kill(c.veu) end) end
  local v = c.view
  if v and not v.morto and K.Alive(v.aura) then K.StopLoop(v.aura); K.SetColor(v.aura, '#ff5d5d00') end
end

function tratar.carga(e)
  local v = st.porGuid[e.guid]
  if not v or v.morto then return end
  limparCarga()
  local W = K.W()
  local c = { view = v, dur = e.dur or 2 }
  -- véu escuro no palco: só o chefe e a Marca que pode pará-lo chamam a atenção
  c.veu = U.img(st.fx, '', 0, 0, K.WTela() + 400, K.HTela() + 400, '#1a0618')
  K.SetRaycast(c.veu, false)
  K.SetAlpha(c.veu, 0); K.FadeTo(c.veu, 0.38, 0.25, nil)
  -- acima do chefe, mas nunca por trás do painel do topo (o chefe é alto)
  c.box = U.box(st.fx, v.cx, math.min(v.by + v.h * 0.5 + 175, 340), 440, 100)
  U.img(c.box, 'skin:escuro', 0, 0, 440, 100, '#ffffffee')
  U.txt(c.box, 'MARÉ NEGRA', 40, 0, 22, 420, 50, '#ff8fbf', 'C', true)
  c.bar = U.bar(c.box, 0, -22, 390, 26, '#1b1a2e', '#ff4d9d')
  K.SetBar(c.bar, 0)
  K.Breath(c.box, 0.04, 0.45)
  K.SetColor(v.aura, '#e0307acc'); K.Breath(v.aura, 0.16, 0.4)
  K.Float(st.fx, 'O chefe carrega a MARÉ NEGRA!', 50, -260, 260, '#ff8fbf')
  if not st.batalha.autoJogador then K.Float(st.fx, 'Atordoe com o Pipo!', 36, -260, 190, '#ffd166') end
  K.Som('abrir')
  st.carga = c
end

function tratar.carga_interrompida(e)
  limparCarga()
  local v = st.porGuid[e.guid]
  if not v then return end
  K.Float(st.fx, 'INTERROMPIDA!', 76, v.cx, math.min(v.by + v.h * 0.5 + 70, 260), '#ffd166')
  K.Ring(st.fx, v.cx, v.cy, '#ffd166', 600, 0.5)
  K.Burst(st.fx, v.cx, v.cy, 28, '#ffd166', 660, 26, 0.7, 300)
  K.Flash('#ffd16644', 0.25)
  K.Som('ssr')
  tremer(14, 0.2)
end

function tratar.mare_negra(e)
  limparCarga()
  if (st.ondaAte or 0) < st.tempo then st.ondaAte = st.tempo + 0.6; ondaMare(st.porGuid[e.guid]) end
  K.Float(st.fx, 'MARÉ NEGRA!', 100, 0, 140, '#ff4d9d')
  -- o impacto acontece quando a onda chega na tripulação
  K.After(0.35, function()
    if not st.batalha then return end
    K.Flash('#e0307a99', 0.55)
    tremer(34, 0.55)
    K.Pausa(0.08)
    K.Som('critico')
    K.Vibrate()
  end)
end

function tratar.fim(e)
  st.resultado = e
  st.hold = 1.0
  -- quem ficou de pé comemora (bonecos com esqueleto)
  if e.venceu then
    for _, v in ipairs(st.views) do
      if v.boneco and not v.morto and K.Alive(v.arte) then K.BonecoAnim(v.arte, 'vitoria', 1) end
    end
  end
end

local function processar()
  while #st.fila > 0 and st.hold <= 0 do
    local e = table.remove(st.fila, 1)
    local f = tratar[e.tipo]
    if f then
      local ok, err = pcall(f, e)
      if not ok then K.Log('evento ' .. e.tipo .. ': ' .. tostring(err)) end
    end
  end
  if #st.fila == 0 then st.fxGrande = nil end
end

-- ------------------------------------------------------------------ HUD superior
local function atualizarBotoes()
  K.SetText(st.bAuto, st.batalha.autoJogador and 'Auto: ON' or 'Auto: OFF')
  K.SetSprite(st.bAuto, 'skin:' .. (st.batalha.autoJogador and 'verde' or 'escuro'))
  K.SetText(st.bVel, 'x' .. st.vel)
end

local function montarHud()
  K.Clear(C.topo)
  local W = K.W()
  local f = st.fase
  local placa = U.painel(C.topo, 0, -60, 640, 96, 'escuro', 0.5, 1)
  K.SetRaycast(placa, false)
  U.txt(placa, f.ilha.nome .. '  ' .. (f.ilhaIdx + 1) .. '-' .. f.num, 30, 0, 18, 620, 40, '#ffd166', 'C', true)
  st.relogio = U.txt(placa, '', 30, 0, -20, 620, 40, '#ffffff', 'C', true)
  st.bAuto = U.btn(C.topo, 'verde', 'Auto', 30, -470, -60, 220, 86, function()
    st.batalha.autoJogador = not st.batalha.autoJogador
    Estado.s.config.auto = st.batalha.autoJogador
    atualizarBotoes()
  end, 1, 1)
  st.bVel = U.btn(C.topo, 'azul', 'x1', 34, -270, -60, 150, 86, function()
    st.vel = st.vel == 1 and 2 or 1
    Estado.s.config.vel = st.vel
    atualizarBotoes()
  end, 1, 1)
  U.btn(C.topo, 'vermelho', 'II', 36, -110, -60, 120, 86, function() B.pausar() end, 1, 1)
  local sin = st.batalha.sinergia
  if sin then
    local sp = U.painel(C.topo, 230, -150, 400, 64, 'escuro', 0, 1)
    K.SetRaycast(sp, false)
    U.txt(sp, 'Sinergia ' .. G.EL[sin.elemento].nome .. ' x' .. sin.n .. ' (+' .. math.floor(sin.bonus * 100) .. '%)', 26, 0, 0, 390, 60, G.EL[sin.elemento].cor, 'C', true)
  end
  U.img(C.topo, 'ic_poder', 70, -60, 70, 70, '#ffffff', 0, 1)
  U.txt(C.topo, G.fmt(Estado.poderEquipe()), 34, 230, -60, 200, 50, '#ffd166', 'L', true, 0, 1)
  atualizarBotoes()
end

-- ------------------------------------------------------------------ abertura
function B.abrir(faseN)
  st = { fila = {}, views = {}, porGuid = {}, danoPor = {}, nivelDe = {}, hold = 0, acc = 0, tempo = 0, chegada = {}, alvoAte = {} }
  st.faseN = faseN
  st.vel = Estado.s.config.vel or 1
  local seed = math.floor(K.Now() % 2147483647)
  st.batalha = Battle.new(D, faseN, Estado.equipe(), seed)
  st.batalha.autoJogador = Estado.s.config.auto ~= false
  st.fase = st.batalha.fase
  local W = K.W()
  local tema = D.Ilhas._ordem[st.fase.ilhaIdx + 1]
  st.cen = Cenario.montar(C.fundo, tema, { horizonte = 690, yMinBrilho = -80 })
  Cenario.entrada(st.cen, 1.2)
  K.Ambiente('mar')
  st.palco = U.box(C.tela, 0, 0, W, 1080)
  -- unidades em ordem de profundidade
  local criar = {}
  for _, e in ipairs(st.batalha:consumirEventos()) do
    if e.tipo == 'criar' then criar[#criar + 1] = e; st.nivelDe[e.guid] = 'Nv' .. e.nivel end
  end
  for _, e in ipairs(criar) do
    local v = criarView(e)
    st.views[#st.views + 1] = v
    st.porGuid[v.guid] = v
  end
  local ordem = {}
  for _, v in ipairs(st.views) do ordem[#ordem + 1] = v end
  table.sort(ordem, function(a, b) if a.fy ~= b.fy then return a.fy > b.fy end return a.guid < b.guid end)
  for _, v in ipairs(ordem) do montarView(v) end
  st.fx = U.box(st.palco, 0, 0, W, 1080)
  -- entrada: aliados correm da esquerda, inimigos da direita, chefe cai do céu
  for i, v in ipairs(st.views) do
    local dx = v.lado == 'a' and -700 or 700
    if v.chefe then
      K.SetPos(v.g, v.bx, v.by + 900)
      K.After(0.9, function()
        K.MoveTo(v.g, v.bx, v.by, 0.35, 2, function()
          tremer(30, 0.45); K.Flash('#ffffff88', 0.25); K.Som('critico')
          K.Burst(st.fx, v.bx, v.fy, 30, '#d9c6a5', 700, 30, 0.8, 900)
        end)
      end)
    else
      K.SetPos(v.g, v.bx + dx, v.by)
      if v.boneco then
        -- entra correndo e para na guarda
        K.BonecoAnim(v.arte, 'correr', 1)
        K.MoveTo(v.g, v.bx, v.by, 0.6 + v.slot * 0.06, 1, function() K.BonecoAnim(v.arte, 'parado', 1) end)
      else
        K.MoveTo(v.g, v.bx, v.by, 0.6 + v.slot * 0.06, 1, nil)
      end
    end
  end
  montarCartas()
  montarHud()
  -- faixa de abertura
  local f = st.fase
  local ban = U.box(C.efeito, 0, 80, W + 200, 260)
  U.img(ban, '', 0, 0, W + 400, 200, '#000000aa')
  U.txt(ban, f.chefe and 'CHEFE: ' .. D.Inimigos[f.inimigos[1].id].nome or (f.ilha.nome), 50, 0, 40, W, 70, f.chefe and '#ff8a7a' or '#ffd166', 'C', true)
  U.txt(ban, 'FASE ' .. (f.ilhaIdx + 1) .. '-' .. f.num, 90, 0, -36, W, 110, '#ffffff', 'C', true)
  K.SetScale(ban, 1, 0.1); K.ScaleTo(ban, 1, 0.25, 3, nil)
  K.After(1.3, function() if K.Alive(ban) then K.FadeTo(ban, 0, 0.3, function() K.Kill(ban) end) end end)
  K.After(1.45, function()
    if st.palco and K.Alive(st.palco) then
      K.Float(st.fx, 'LUTEM!', 110, 0, 40, '#ffd166')
      K.Som('especial')
    end
  end)
  st.hold = f.chefe and 1.9 or 1.6
end

-- ------------------------------------------------------------------ quadro a quadro
local function sincronizar()
  local b = st.batalha
  for _, v in ipairs(st.views) do
    local u = b:unidade(v.guid)
    if u and not v.morto then
      if u.furia ~= v.lf then v.lf = u.furia; K.SetBar(v.furBar, u.furia / 100); if v.cFur then K.SetBar(v.cFur, u.furia / 100) end end
      local tonto = u.atord > 0
      if tonto ~= v.tontoOn then v.tontoOn = tonto; K.SetActive(v.tonto, tonto) end
      if u.buff > 0 and not v.buffOn then v.buffOn = true; K.SetColor(v.aura, '#ff5d5d88'); K.Breath(v.aura, 0.1, 0.6)
      elseif u.buff <= 0 and v.buffOn then v.buffOn = false; K.SetColor(v.aura, '#ff5d5d00') end
      if u.queim > 0 then
        v.fogoT = (v.fogoT or 0) - 1
        if v.fogoT <= 0 then v.fogoT = 6; K.Burst(st.fx, v.cx, v.cy - v.h * 0.25, 2, '#ff7a1a', 120, 20, 0.6, -350) end
      end
      if v.cFur then
        local pronto = u.furia >= 100 and u.ult ~= nil and u.atord <= 0
        -- durante a carga, a carta que atordoa vira o alerta: é a decisão que importa (Pilar 2)
        local alerta = pronto and u.ult.efeito == 'atordoar' and b.mec.fase == 'carga'
        if pronto ~= v.prontoOn or alerta ~= v.alertaOn then
          v.prontoOn, v.alertaOn = pronto, alerta
          K.SetActive(v.cGlow, pronto)
          K.SetColor(v.cGlow, alerta and '#ff4d9dee' or '#ffd166cc')
          if alerta then K.Breath(v.cGlow, 0.18, 0.35) else K.Breath(v.cGlow, 0.08, 0.7) end
          K.SetText(v.cTxt, alerta and '<color=#ff8fbf>ATORDOE!</color>' or (pronto and (b.autoJogador and 'ESPECIAL' or 'TOQUE!') or ''))
        end
      end
    end
  end
  if st.carga then
    local fase, idade = b:faseChefe()
    if fase == 'carga' then K.SetBar(st.carga.bar, idade / st.carga.dur) else limparCarga() end
  end
  local resta = math.max(0, b.P.limite_tempo - b.t)
  local seg = math.floor(resta)
  if seg == st.ultSeg then return end
  st.ultSeg = seg
  K.SetText(st.relogio, string.format('%d:%02d', math.floor(resta / 60), math.floor(resta % 60)))
end

function B.update(dt)
  if not st.batalha then return end
  st.tempo = st.tempo + dt
  if st.cen then Cenario.atualizarClima(st.cen, C.tela, dt) end
  if st.pausado then
    if not (st.pausaModal and K.Alive(st.pausaModal.fundo)) then st.pausado = false else return end
  end
  if st.hold > 0 then
    st.hold = st.hold - dt
    if st.hold > 0 then return end
  end
  processar()
  if st.hold > 0 then return end
  if st.resultado then
    if not st.mostrou then st.mostrou = true; B.resultado(st.batalha.fim) end
    return
  end
  st.acc = st.acc + dt * st.vel
  local n = 0
  while st.acc >= 0.05 and n < 8 do
    st.acc = st.acc - 0.05
    n = n + 1
    st.batalha:passo()
    for _, e in ipairs(st.batalha:consumirEventos()) do st.fila[#st.fila + 1] = e end
    processar()
    if st.hold > 0 or st.resultado then break end
  end
  sincronizar()
end

function B.pausar()
  if st.resultado or st.pausado or not st.batalha then return end
  st.pausado = true
  st.pausaModal = G.modal('Pausa', 900, 520, function(p)
    U.txt(p, 'A maré espera por você, capitão.', 36, 0, 40, 800, 60, '#ffffff', 'C', true)
    U.txt(p, 'Desistir conta como derrota, sem perder nada.', 26, 0, -30, 800, 50, '#9fb3c8', 'C', false)
  end, {
    { 'Desistir', 'vermelho', function() st.pausado = false; G.ir('aventura') end },
    { 'Continuar', 'verde', function() st.pausado = false end },
  })
end

-- ------------------------------------------------------------------ resultado
function B.resultado(fim)
  local W = K.W()
  local n = st.faseN
  local primeira = n >= Estado.s.vencidas
  local f = st.fase
  local premio = { ouro = 0, xp = 0, gemas = 0 }
  local ilhaAntes = math.min(Estado.s.vencidas, Formula.totalFases() - 1) // Formula.FASES_POR_ILHA
  if fim.venceu then
    premio = { ouro = f.recompensa.ouro, xp = f.recompensa.xp, gemas = primeira and f.recompensa.gemas or 0 }
    Estado.registrarVitoria(n, fim.estrelas, premio)
  end
  if fim.especiais > 0 then Estado.missao('especial', fim.especiais); Estado.salvar() end
  G.atualizarTopo()

  local ov = U.img(C.modal, '', 0, 0, K.WTela() + 400, K.HTela() + 400, '#030812dd')
  -- o véu passa das bordas; o que se prende embaixo (botões) usa a área útil
  local util = U.box(ov, 0, 0, K.W(), K.H())
  K.SetRaycast(ov, true)
  K.SetAlpha(ov, 0); K.FadeTo(ov, 1, 0.3, nil)
  local cor = fim.venceu and '#ffd166' or '#ff6b6b'
  local luz = U.img(ov, 'brilho', 0, 260, 1300, 700, cor .. '66')
  K.Spin(luz, fim.venceu and 10 or 0)
  local titulo = U.txt(ov, fim.venceu and 'VITÓRIA!' or 'DERROTA', 150, 0, 300, 1400, 180, cor, 'C', true)
  K.SetScale(titulo, 0.2, 0.2); K.ScaleTo(titulo, 1, 0.45, 3, nil)
  if fim.venceu then
    K.Som('vitoria')
    K.Flash('#ffd16666', 0.5)
    for i = 1, 3 do
      local x = (i - 2) * 150
      U.img(ov, 'ic_estrela', x, 150 + (i == 2 and 20 or 0), 130, 130, '#2a3550')
      if i <= fim.estrelas then
        K.After(0.35 + i * 0.25, function()
          if not K.Alive(ov) then return end
          local e = U.img(ov, 'ic_estrela', x, 150 + (i == 2 and 20 or 0), 130, 130)
          K.SetScale(e, 2.2, 2.2); K.ScaleTo(e, 1, 0.25, 3, nil)
          K.Burst(ov, x, 150, 18, '#ffd166', 500, 22, 0.7, 400)
          K.Som('moeda')
        end)
      end
    end
    local pr = U.painel(ov, 0, 0, 760, 110, 'escuro')
    U.txt(pr, primeira and 'Recompensas' or 'Recompensas (repetição)', 24, 0, 40, 600, 30, '#9fb3c8', 'C', false)
    G.premioIcones(pr, premio, 0, -10, 56)
    -- destaque da batalha
    local mvp, mv = nil, -1
    for g, d in pairs(st.danoPor) do if d > mv then mvp, mv = g, d end end
    if mvp then
      local v = st.porGuid[mvp]
      local m = U.painel(ov, 0, -150, 620, 130, 'card')
      local cl = K.Clip(m, -230, 0, 120, 110, 0.5, 0.5)
      U.img(cl, G.arteRetrato(v.id), 0, 0, 120, 120)
      U.txt(m, 'Destaque: ' .. D.Herois[v.id].nome, 30, 60, 22, 460, 40, '#ffd166', 'C', true)
      U.txt(m, 'Dano causado: ' .. G.fmt(mv), 26, 60, -24, 460, 36, '#ffffff', 'C', true)
    end
    local ilhaDepois = math.min(Estado.s.vencidas, Formula.totalFases() - 1) // Formula.FASES_POR_ILHA
    if primeira and ilhaDepois > ilhaAntes then
      local nova = D.Ilhas[D.Ilhas._ordem[ilhaDepois + 1]]
      K.After(1.4, function() G.toast('Nova ilha liberada: ' .. nova.nome .. '!', '#7cf29a') end)
    elseif primeira and n + 1 >= Formula.totalFases() then
      K.After(1.4, function() G.toast('Enseada do Farol libertada! O próximo mar chega na próxima atualização.', '#7cf29a') end)
    end
    local bar = U.box(util, 0, 150, 1200, 120, 0.5, 0)
    U.btn(bar, 'azul', 'Navio', 38, -380, 0, 300, 104, function() G.ir('navio') end)
    U.btn(bar, 'roxo', 'Mapa', 38, 0, 0, 300, 104, function() G.ir('aventura') end)
    if n + 1 < Formula.totalFases() then
      local b = U.btn(bar, 'ouro', 'Próxima fase', 36, 380, 0, 340, 104, function() G.ir('batalha', n + 1) end)
      K.Breath(b, 0.03, 1)
    end
  else
    K.Som('derrota')
    U.txt(ov, 'A tripulação precisa ficar mais forte. Tente:', 34, 0, 140, 1200, 50, '#ffffff', 'C', true)
    local dicas = {
      { 'Subir nível', 'ic_tripulacao', 'tripulacao', 'Gaste ouro e XP nos heróis' },
      { 'Recrutar', 'ic_caneca', 'taverna', 'Novos heróis e fragmentos' },
      { 'Formação', 'ic_formacao', 'formacao', 'Use sinergia e vantagem' },
    }
    for i, d in ipairs(dicas) do
      local x = (i - 2) * 330
      local b = U.btn(ov, 'vidro', '', 10, x, -40, 300, 230, function() G.ir(d[3]) end)
      U.img(b, d[2], 0, 40, 110, 110)
      U.txt(b, d[1], 32, 0, -40, 290, 44, '#ffd166', 'C', true)
      U.txt(b, d[4], 20, 0, -80, 280, 30, '#cfe2ff', 'C', false)
    end
    local bar = U.box(util, 0, 150, 900, 120, 0.5, 0)
    U.btn(bar, 'azul', 'Navio', 38, -200, 0, 320, 104, function() G.ir('navio') end)
    U.btn(bar, 'ouro', 'Tentar de novo', 34, 200, 0, 360, 104, function() G.ir('batalha', n) end)
  end
end

function B.terminou() return st.mostrou == true end

-- tela mudou de tamanho no meio da luta: refaz o cenário para cobrir a tela nova (unidades e HUD se ajustam sozinhos)
function B.redimensionar()
  if not st.batalha or not st.fase then return end
  K.Clear(C.fundo)
  st.cen = Cenario.montar(C.fundo, D.Ilhas._ordem[st.fase.ilhaIdx + 1], { horizonte = 690, yMinBrilho = -80 })
end
-- o chefe está carregando a Maré Negra agora (usado pelo modo de teste automático)
function B.emCarga() return st.carga ~= nil end
function B.batalha() return st.batalha end

function B.fechar()
  st.batalha = nil
  st.cen = nil
  K.Clear(C.modal)
  K.Clear(C.efeito)
  G.topo(false)
end

return B
