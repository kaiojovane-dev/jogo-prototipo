-- Cenários pintados (ilustração inteira gerada) cobrindo a tela toda, com véu opcional e partículas de clima.
local K = CS.UIKit
local C = {}

C.TEMAS = {
  farol = { unico = 'bg_batalha', clima = 'brisa', luz = '#bfe9ff' },
  hub = { unico = 'bg_navio', clima = 'vagalume', luz = '#ffd6a5' },
  -- telas de menu (taverna, tripulação): o convés à noite, escurecido para o conteúdo aparecer
  noite = { unico = 'bg_navio', veu = '#070818b8', clima = 'vagalume', luz = '#e0e1dd' },
  titulo = { unico = 'bg_batalha', clima = 'brisa', luz = '#bfe9ff' },
  -- carta náutica do mar escuro: a ilha vencida acesa, as próximas em silhueta (Pilar 3)
  mapa = { unico = 'bg_mapa', clima = 'vagalume', luz = '#ffd6a5' },
}

-- ilustração cobrindo a tela inteira sem distorcer (corta as sobras em cima/embaixo ou nos lados)
function C.ceu(p, sp)
  local W, H = K.WTela() + 120, K.HTela() + 60
  local s = math.max(W / 1920, H / 1080, 1.08)
  return K.Img(p, sp, 0, 0, 1920 * s, 1080 * s, '#ffffff', 0.5, 0.5)
end

-- monta o cenário do tema; opts: horizonte (y do brilho na água), yMinBrilho
function C.montar(p, tema, opts)
  opts = opts or {}
  local t = C.TEMAS[tema] or C.TEMAS.farol
  local r = { tema = t }
  r.ceu = C.ceu(p, t.unico)
  if t.veu then r.veu = K.Img(p, '', 0, 0, K.WTela() + 200, K.HTela() + 200, t.veu, 0.5, 0.5) end
  r.agua = K.Box(p, 0, 0, K.WTela(), K.HTela(), 0.5, 0.5)
  r.yMin = opts.yMinBrilho or -540
  r.horizonte = opts.horizonte or 640
  r.clima = t.clima
  return r
end

-- entrada: a ilustração começa um pouco mais "perto" e assenta
function C.entrada(r, dur)
  K.SetScale(r.ceu, 1.06, 1.06)
  K.ScaleTo(r.ceu, 1, dur or 1.1, 1, nil)
end

-- partículas de clima, chamadas a cada quadro com dt
function C.atualizarClima(r, frente, dt)
  r.acc = (r.acc or 0) + dt
  local W = K.W()
  local passo = 0.22
  while r.acc >= passo do
    r.acc = r.acc - passo
    if r.clima == 'vagalume' then
      local x, y = (math.random() - 0.5) * W, (math.random() - 0.5) * 700
      local g = K.Img(frente, 'particula', x, y, 14, 14, '#ffe08a', 0.5, 0.5)
      K.SetAlpha(g, 0)
      K.FadeTo(g, 1, 1.2, function() K.FadeTo(g, 0, 1.4, function() K.Kill(g) end) end)
      K.MoveTo(g, x + (math.random() - 0.5) * 140, y + 60, 2.6, 4, nil)
    else
      -- brisa: brilho do sol na água
      local x = (math.random() - 0.5) * W
      local y = r.yMin + math.random() * (r.horizonte - 600 - r.yMin)
      K.Ring(r.agua, x, y, '#ffffffaa', 30 + math.random() * 40, 0.9)
    end
  end
end

return C
