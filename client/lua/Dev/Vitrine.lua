-- Vitrine do esqueleto: filma o Pipo (boneco com física) em batalha, quadro a quadro, para revisar movimento.
-- Ativado com  -vitrine <pasta>  na linha de comando. Cada trecho salva capturas em intervalos fixos de tempo
-- de jogo; os golpes rápidos são filmados em câmera lenta (K.CameraLenta).
local K = CS.UIKit
local V = {}
local dir, t, n = '', 0, 0
local trechos, i, proxShot = {}, 1, 0

local function shot(nome)
  n = n + 1
  K.Shot(dir .. '/' .. string.format('%03d', n) .. '_' .. nome .. '.png')
end

-- trecho: ao começar roda 'ini' e liga a câmera lenta 'lento'; filma de 'de' até 'ate' (tempo de jogo) a cada 'passo'
local function trecho(nome, dur, lento, ini, de, ate, passo)
  trechos[#trechos + 1] = { nome = nome, dur = dur, lento = lento, ini = ini, de = de, ate = ate, passo = passo }
end

local function pipoNaBatalha(fase, nivel)
  local Est = G.Estado
  Est.s.herois.pipo = Est.s.herois.pipo or { nivel = 1, estrelas = 1, frag = 0 }
  Est.s.herois.pipo.nivel = nivel
  Est.s.formacao = { 'pipo', '', '', '', '' }
  Est.s.config.auto = false
  Est.s.config.vel = 1
  G.ir('batalha', fase)
end

local function especialDoPipo()
  local b = G.Batalha.batalha and G.Batalha.batalha()
  if not b then return end
  for _, u in ipairs(b:vivos('a')) do if u.id == 'pipo' then u.furia = 100; b:pedirEspecial(u.guid) end end
end

function V.iniciar(pasta)
  dir = pasta
  G.Estado.resetar()
  G.Estado.s.intro = false
  K.Log('vitrine: início em ' .. dir)
  -- 1) entrada correndo
  trecho('entrada', 1.5, 1, function() pipoNaBatalha(0, 40) end, 0.2, 1.5, 0.07)
  -- 2) frigideiradas em câmera lenta (o motor ataca a cada ~1,5 s)
  trecho('golpe', 3.2, 0.25, function() end, 0, 3.2, 0.03)
  -- 3) Abraço do Polvo: cut-in, tentáculos, erguer e bater
  trecho('especial', 2.9, 0.4, especialDoPipo, 0.75, 2.9, 0.035)
  -- 4) apanhando do chefe até cair (nível 1, sozinho)
  trecho('morte', 9, 1, function() pipoNaBatalha(9, 1) end, 2.0, 9, 0.12)
  -- 5) ficha do herói (respiração e molas paradas)
  trecho('ficha', 2.2, 1, function() G.ir('heroi', 'pipo') end, 0.8, 2.2, 0.45)
  trecho('fim', 0.5, 1, function()
    K.Log('vitrine: fim, ' .. n .. ' capturas')
    G.Estado.resetar()
    K.Quit()
  end, 1, 0, 1)
end

function V.update(dt)
  local tr = trechos[i]
  if not tr then return end
  if t == 0 and not tr.comecou then
    tr.comecou = true
    K.CameraLenta(tr.lento)
    local ok, err = pcall(tr.ini)
    if not ok then K.Log('vitrine: erro ' .. tostring(err)) end
    proxShot = tr.de
  end
  t = t + dt
  if t >= proxShot and t <= tr.ate then
    shot(tr.nome)
    proxShot = proxShot + tr.passo
  end
  if t >= tr.dur then i = i + 1; t = 0 end
end

return V
