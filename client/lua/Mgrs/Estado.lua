-- Estado do jogador, economia e save local (no futuro sincronizado com o servidor).
local Formula = require('Game.Formula')
local Estado = {}

local K = CS.UIKit
local CHAVE = 'fimdomapa_save_v1'  -- chave nova: saves do protótipo antigo (Maré de Lendas) não são carregados
local D, P

local function hoje()
  return os.date('%Y-%m-%d')
end

-- serialização simples de tabela Lua (strings, números, booleanos, tabelas)
local function ser(v, ind)
  local t = type(v)
  if t == 'number' then return tostring(v) end
  if t == 'boolean' then return v and 'true' or 'false' end
  if t == 'string' then return string.format('%q', v) end
  if t == 'table' then
    local p = {}
    for k, x in pairs(v) do
      local kk = type(k) == 'number' and ('[' .. k .. ']') or ('[' .. string.format('%q', k) .. ']')
      p[#p + 1] = kk .. '=' .. ser(x)
    end
    return '{' .. table.concat(p, ',') .. '}'
  end
  return 'nil'
end

local function novo()
  local s = {
    v = 1, nome = 'Capitão', ouro = P.inicio_ouro, gemas = P.inicio_gemas, xp = P.inicio_xp,
    herois = {}, formacao = { '', '', '', '', '' }, vencidas = 0, estrelasFase = {},
    idleDesde = K.Now(), pilhagem = { dia = hoje(), usadas = 0 },
    gacha = { semSSR = 0, total = 0 },
    login = { dia = '', contagem = 0, pendente = false },
    missoes = { dia = hoje(), prog = {}, pegas = {} },
    intro = false, config = { som = true, vel = 1, auto = false },  -- Auto desligado no começo: o jogador sente a decisão (Pilar 2)
  }
  for _, r in ipairs(D.Inicio) do
    s.herois[r.heroi] = { nivel = 1, estrelas = 1, frag = 0 }
    s.formacao[r.slot] = r.heroi
  end
  return s
end

function Estado.init(data)
  D, P = data, data.Param
  local txt = K.Load(CHAVE)
  local s = nil
  if txt and txt ~= '' then
    local f = load('return ' .. txt)
    if f then local ok, r = pcall(f); if ok and type(r) == 'table' and r.v == 1 then s = r end end
  end
  Estado.s = s or novo()
  Estado.virarDia()
  Estado.salvar()
end

function Estado.salvar()
  K.Save(CHAVE, ser(Estado.s))
end

function Estado.resetar()
  Estado.s = novo()
  Estado.virarDia()
  Estado.salvar()
end

function Estado.virarDia()
  local s, d = Estado.s, hoje()
  if s.login.dia ~= d then s.login.dia = d; s.login.pendente = true end
  if s.pilhagem.dia ~= d then s.pilhagem = { dia = d, usadas = 0 } end
  if s.missoes.dia ~= d then s.missoes = { dia = d, prog = {}, pegas = {} } end
end

function Estado.dar(p)
  local s = Estado.s
  s.ouro = s.ouro + (p.ouro or 0); s.gemas = s.gemas + (p.gemas or 0); s.xp = s.xp + (p.xp or 0)
end

function Estado.missao(id, n)
  local m = Estado.s.missoes.prog
  m[id] = (m[id] or 0) + (n or 1)
end

function Estado.missoesProntas()
  local n, s = 0, Estado.s
  for _, m in ipairs(D.Missoes) do
    if not s.missoes.pegas[m.id] and (s.missoes.prog[m.id] or 0) >= m.meta then n = n + 1 end
  end
  return n
end

function Estado.pegarMissao(id)
  local s = Estado.s
  for _, m in ipairs(D.Missoes) do
    if m.id == id and not s.missoes.pegas[id] and (s.missoes.prog[id] or 0) >= m.meta then
      s.missoes.pegas[id] = true
      Estado.dar(m); Estado.salvar()
      return true
    end
  end
  return false
end

function Estado.pegarLogin()
  local s = Estado.s
  if not s.login.pendente then return nil end
  local idx = s.login.contagem % 7 + 1
  local p = D.Login[idx]
  s.login.contagem = s.login.contagem + 1
  s.login.pendente = false
  Estado.dar(p)
  if p.heroi ~= '' then Estado.ganharHeroi(p.heroi) end
  Estado.salvar()
  return p, idx
end

-- heróis
function Estado.atributos(id)
  local h = Estado.s.herois[id]
  return Formula.atributosHeroi(id, h and h.nivel or 1, h and h.estrelas or 1)
end

function Estado.poderHeroi(id)
  if not Estado.s.herois[id] then return 0 end
  return Formula.poder(Estado.atributos(id))
end

function Estado.poderEquipe()
  local total, ids = 0, {}
  for _, id in ipairs(Estado.s.formacao) do
    if id ~= '' then total = total + Estado.poderHeroi(id); ids[#ids + 1] = id end
  end
  local sin = Formula.sinergia(ids)
  return math.floor(total * (sin and (1 + sin.bonus) or 1))
end

function Estado.subirNivel(id)
  local h, s = Estado.s.herois[id], Estado.s
  if not h or h.nivel >= P.nivel_max then return 'max' end
  local c = Formula.custoNivel(h.nivel)
  if s.ouro < c.ouro or s.xp < c.xp then return 'falta' end
  s.ouro, s.xp, h.nivel = s.ouro - c.ouro, s.xp - c.xp, h.nivel + 1
  Estado.missao('nivel'); Estado.salvar()
  return 'ok'
end

function Estado.evoluir(id)
  local h = Estado.s.herois[id]
  if not h or h.estrelas >= P.estrela_max then return 'max' end
  local c = Formula.custoEstrela(h.estrelas)
  if h.frag < c then return 'falta' end
  h.frag, h.estrelas = h.frag - c, h.estrelas + 1
  Estado.salvar()
  return 'ok'
end

local function fragDe(rar)
  for _, r in ipairs(D.Raridade) do if r.raridade == rar then return r.frag end end
  return 10
end

function Estado.ganharHeroi(id)
  local s = Estado.s
  if not s.herois[id] then s.herois[id] = { nivel = 1, estrelas = 1, frag = 0 }; return true, 0 end
  local f = fragDe(D.Herois[id].raridade)
  s.herois[id].frag = s.herois[id].frag + f
  return false, f
end

-- taverna com garantia
function Estado.recrutar(qtd)
  local s = Estado.s
  local custo = qtd == 10 and P.gacha_custo10 or P.gacha_custo1 * qtd
  if s.gemas < custo then return nil end
  s.gemas = s.gemas - custo
  local chances = {}
  for _, r in ipairs(D.Raridade) do chances[r.raridade] = r.chance end
  local res, temMelhor = {}, false
  for i = 1, qtd do
    s.gacha.total, s.gacha.semSSR = s.gacha.total + 1, s.gacha.semSSR + 1
    local r, rar = math.random(), 'R'
    if s.gacha.semSSR >= P.gacha_garantia or r < chances.SSR then rar = 'SSR'
    elseif r < chances.SSR + chances.SR then rar = 'SR' end
    if qtd == 10 and i == 10 and not temMelhor and rar == 'R' then rar = 'SR' end
    if rar ~= 'R' then temMelhor = true end
    if rar == 'SSR' then s.gacha.semSSR = 0 end
    local pool = {}
    for _, hid in ipairs(D.Herois._ordem) do if D.Herois[hid].raridade == rar then pool[#pool + 1] = hid end end
    local id = pool[math.random(#pool)]
    local novo, frag = Estado.ganharHeroi(id)
    res[#res + 1] = { id = id, rar = rar, novo = novo, frag = frag }
  end
  Estado.missao('recrutar', qtd)
  Estado.salvar()
  return res
end

-- recompensa do navio (idle)
function Estado.idle()
  local s = Estado.s
  local seg = math.min(K.Now() - s.idleDesde, P.idle_max_horas * 3600)
  local min = seg / 60
  return {
    seg = seg, cheio = seg >= P.idle_max_horas * 3600,
    ouro = math.floor((P.idle_ouro_a + P.idle_ouro_b * s.vencidas) * min),
    xp = math.floor((P.idle_xp_a + P.idle_xp_b * s.vencidas) * min),
    gemas = math.floor(P.idle_gemas * min),
  }
end

function Estado.coletarIdle()
  local r = Estado.idle()
  Estado.dar(r)
  Estado.s.idleDesde = K.Now()
  Estado.missao('coletar'); Estado.salvar()
  return r
end

function Estado.pilhagem()
  local s = Estado.s
  local gratis = s.pilhagem.usadas < P.pilhagem_gratis
  if not gratis and s.gemas < P.pilhagem_custo then return nil end
  if not gratis then s.gemas = s.gemas - P.pilhagem_custo end
  s.pilhagem.usadas = s.pilhagem.usadas + 1
  local min = P.pilhagem_horas * 60
  local r = {
    ouro = math.floor((P.idle_ouro_a + P.idle_ouro_b * s.vencidas) * min),
    xp = math.floor((P.idle_xp_a + P.idle_xp_b * s.vencidas) * min),
    gemas = math.floor(P.idle_gemas * min),
  }
  Estado.dar(r); Estado.salvar()
  return r
end

-- equipe montada para a batalha
function Estado.equipe()
  local e = {}
  for slot, id in ipairs(Estado.s.formacao) do
    if id ~= '' then
      local h = Estado.s.herois[id]
      e[#e + 1] = { slot = slot, id = id, nivel = h.nivel, estrelas = h.estrelas }
    end
  end
  return e
end

function Estado.registrarVitoria(faseN, estrelas, recompensa)
  local s = Estado.s
  Estado.dar(recompensa)
  s.vencidas = math.max(s.vencidas, faseN + 1)
  s.estrelasFase[faseN + 1] = math.max(s.estrelasFase[faseN + 1] or 0, estrelas)
  Estado.missao('vencer')
  Estado.salvar()
end

return Estado
