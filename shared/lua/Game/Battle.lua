-- Motor de batalha determinístico (passo fixo). Roda igual no cliente (para animar) e no servidor (para validar).
-- Produz eventos: {t, tipo, ...} que o cliente transforma em animação.
local Random = require('Game.Random')
local Formula = require('Game.Formula')

local Battle = {}
Battle.__index = Battle

local PASSO = 0.05

-- equipe: lista de {slot=1..5, id, nivel, estrelas}; seed: inteiro
function Battle.new(data, faseN, equipe, seed)
  local P = data.Param
  local self = setmetatable({}, Battle)
  self.P, self.data = P, data
  self.fase = Formula.fase(faseN)
  self.rng = Random.new(seed)
  self.seed = seed
  self.t = 0
  self.fim = nil
  self.eventos = {}
  self.unidades = {}
  self.guid = 0
  self.autoJogador = true
  self.especiaisJogador = 0

  local ids = {}
  for _, m in ipairs(equipe) do ids[#ids + 1] = m.id end
  self.sinergia = Formula.sinergia(ids)

  for _, m in ipairs(equipe) do
    local h = data.Herois[m.id]
    local a = Formula.atributosHeroi(m.id, m.nivel, m.estrelas)
    if self.sinergia and h.elemento == self.sinergia.elemento then
      a.hp = math.floor(a.hp * (1 + self.sinergia.bonus) + 0.5)
      a.atk = math.floor(a.atk * (1 + self.sinergia.bonus) + 0.5)
    end
    self:criar('a', m.slot, m.id, h.elemento, a, h.ataque_alvo, h.ataque_mult, Formula.skill(h.ult), m.nivel, false)
  end
  local qtd = #self.fase.inimigos
  for k, ini in ipairs(self.fase.inimigos) do
    local a = Formula.atributosInimigo(ini.id, ini.nivel, self.fase.dif)
    local slot = (qtd == 3 and k == 3) and 4 or k
    local u = self:criar('i', slot, ini.id, ini.elemento, a, 'frente', 1, Formula.skill(data.Inimigos[ini.id].ult), ini.nivel, ini.chefe)
    if ini.chefe then self.chefeU = u end
  end
  -- Maré Negra: o chefe telegrafa uma carga; atordoá-lo durante a carga cancela o golpe (valores em Param, vindos do T0)
  self.mec = { fase = 'normal', inicioFase = 0, fim = 0, proximo = P.mare_inicio or 7, interrompidas = 0, mares = 0 }
  return self
end

-- Ciclo do chefe: normal -> carga (dura mare_carga s) -> cancelada (se atordoado) ou Maré Negra.
-- Durante a carga o chefe não ataca nem usa especial. Roda no começo de cada passo, antes dos pedidos do jogador.
function Battle:mecanica()
  local b, m, P = self.chefeU, self.mec, self.P
  if not b or not b.vivo then
    m.fase = 'normal'
    return
  end
  local t = self.t
  if m.fase == 'normal' then
    if t >= m.proximo then
      m.proximo = t + (P.mare_periodo or 10)
      m.fase, m.inicioFase, m.fim = 'carga', t, t + (P.mare_carga or 2)
      self:evento('carga', { guid = b.guid, dur = P.mare_carga or 2 })
    end
  elseif m.fase == 'carga' then
    if b.atord > 0 then
      m.fase = 'normal'
      m.interrompidas = m.interrompidas + 1
      self:evento('carga_interrompida', { guid = b.guid, reacao = t - m.inicioFase })
    elseif t >= m.fim then
      m.fase = 'normal'
      m.mares = m.mares + 1
      local total = 0
      for _, a in ipairs(self:vivos('a')) do
        local v = math.floor(a.max * (P.mare_pct or 0.45) + 0.5)
        local abs = math.min(a.escudo, v)
        a.escudo = a.escudo - abs
        a.hp = a.hp - (v - abs)
        total = total + v - abs
        self:evento('dano', { de = b.guid, alvo = a.guid, v = v - abs, abs = abs, crit = false, rel = 0, hp = math.max(0, a.hp), escudo = a.escudo, mare = true })
        if a.hp <= 0 then a.hp = 0; a.vivo = false; self:evento('morte', { guid = a.guid }) end
      end
      self:evento('mare_negra', { guid = b.guid, total = total })
    end
  end
end

-- fase do chefe e há quanto tempo ela começou (para a interface e para políticas de teste)
function Battle:faseChefe()
  local m = self.mec
  return m.fase, self.t - (m.inicioFase or self.t)
end

function Battle:evento(tipo, dados)
  dados.t = self.t
  dados.tipo = tipo
  self.eventos[#self.eventos + 1] = dados
end

function Battle:criar(lado, slot, id, elemento, st, alvo, mult, ult, nivel, chefe)
  self.guid = self.guid + 1
  local u = {
    guid = self.guid, lado = lado, slot = slot, id = id, elemento = elemento, st = st,
    ataqueAlvo = alvo, ataqueMult = mult, ult = ult, nivel = nivel, chefe = chefe,
    hp = st.hp, max = st.hp, furia = (lado == 'i') and self.P.furia_inimigo_inicial or 0, escudo = 0,
    cd = 0.3 + self.rng:next() * 0.8, intervalo = self.P.intervalo_base / st.vel,
    atord = 0, queim = 0, queimDps = 0, queimAcum = 0, buff = 0, buffT = 0, vivo = true,
  }
  self.unidades[#self.unidades + 1] = u
  self:evento('criar', { guid = u.guid, lado = lado, slot = slot, id = id, elemento = elemento, hp = u.hp, max = u.max, nivel = nivel, chefe = chefe })
  return u
end

function Battle:unidade(guid)
  for _, u in ipairs(self.unidades) do if u.guid == guid then return u end end
end

function Battle:vivos(lado)
  local r = {}
  for _, u in ipairs(self.unidades) do if u.vivo and u.lado == lado then r[#r + 1] = u end end
  return r
end

local function oponente(l) return l == 'a' and 'i' or 'a' end

function Battle:alvos(u, modo, n, emArea)
  local ini = self:vivos(oponente(u.lado))
  if #ini == 0 then return {} end
  local frente, tras = {}, {}
  for _, x in ipairs(ini) do if x.slot <= 2 then frente[#frente + 1] = x else tras[#tras + 1] = x end end
  if modo == 'todos' then return ini end
  if modo == 'menorVida' then
    table.sort(ini, function(a, b) if a.hp / a.max == b.hp / b.max then return a.guid < b.guid end return a.hp / a.max < b.hp / b.max end)
    return { ini[1] }
  end
  if modo == 'tras' then return #tras > 0 and tras or frente end
  if modo == 'aleatorio' then
    local r = {}
    for i = 1, (n and n > 0) and n or 3 do r[i] = self.rng:pick(ini) end
    return r
  end
  if modo == 'frente' and emArea then return #frente > 0 and frente or tras end
  return { #frente > 0 and self.rng:pick(frente) or self.rng:pick(tras) }
end

function Battle:calc(at, df, mult)
  local P = self.P
  if self.rng:next() < P.esquiva_base then return { esquiva = true, v = 0 } end
  local base = at.st.atk * (1 + at.buff) * mult
  local d = base * P.dano_a * P.dano_b / (P.dano_c + P.dano_d * df.st.def / base)
  local crit = self.rng:next() < at.st.crit
  if crit then d = d * at.st.crit_dmg end
  local rel = 0
  if Formula.VANTAGEM[at.elemento] == df.elemento then d = d * P.vantagem; rel = 1
  elseif Formula.VANTAGEM[df.elemento] == at.elemento then d = d * P.desvantagem; rel = -1 end
  d = d * (1 - P.variacao + self.rng:next() * 2 * P.variacao)
  return { v = math.max(1, math.floor(d + 0.5)), crit = crit, rel = rel }
end

function Battle:ferir(at, df, r, viaUlt)
  if not df.vivo then return end
  if r.esquiva then self:evento('esquiva', { alvo = df.guid }); return end
  local v, absorvido = r.v, 0
  if df.escudo > 0 then absorvido = math.min(df.escudo, v); df.escudo = df.escudo - absorvido; v = v - absorvido end
  df.hp = df.hp - v
  if not viaUlt then df.furia = math.min(100, df.furia + self.P.furia_dano) end
  self:evento('dano', { de = at.guid, alvo = df.guid, v = v, abs = absorvido, crit = r.crit, rel = r.rel, hp = math.max(0, df.hp), escudo = df.escudo })
  if df.hp <= 0 then df.hp = 0; df.vivo = false; self:evento('morte', { guid = df.guid }) end
end

function Battle:atacar(u)
  local alvo = self:alvos(u, u.ataqueAlvo)[1]
  if not alvo then return end
  self:evento('ataque', { de = u.guid, alvo = alvo.guid })
  self:ferir(u, alvo, self:calc(u, alvo, u.ataqueMult), false)
  u.furia = math.min(100, u.furia + self.P.furia_ataque)
end

function Battle:especial(u)
  local ult = u.ult
  if not u.vivo or u.furia < 100 or not ult or u.atord > 0 then return false end
  u.furia = 0
  if u.lado == 'a' then self.especiaisJogador = self.especiaisJogador + 1 end
  local alvosIds = {}
  if ult.tipo == 'dano' then
    local alvos = self:alvos(u, ult.alvo, ult.n, true)
    -- enquanto o chefe carrega, especiais de alvo único dos heróis miram o chefe (vale para auto e manual)
    local b, fase = self.chefeU, self.mec.fase
    if u.lado == 'a' and b and b.vivo and fase ~= 'normal' and ult.alvo ~= 'todos' and ult.alvo ~= 'aleatorio' then
      alvos = { b }
    end
    for _, a in ipairs(alvos) do alvosIds[#alvosIds + 1] = a.guid end
    self:evento('especial', { de = u.guid, skill = ult.id, alvos = alvosIds, fase = fase })
    for _, a in ipairs(alvos) do
      self:ferir(u, a, self:calc(u, a, ult.mult), true)
      if a.vivo and ult.efeito ~= '' and self.rng:next() < ult.efeito_chance then
        if ult.efeito == 'atordoar' then
          a.atord = math.max(a.atord, ult.efeito_dur)
          self:evento('efeito', { alvo = a.guid, efeito = 'atordoar', dur = ult.efeito_dur })
        elseif ult.efeito == 'queimar' then
          a.queim = ult.efeito_dur
          a.queimDps = math.floor(u.st.atk * ult.efeito_pct + 0.5)
          self:evento('efeito', { alvo = a.guid, efeito = 'queimar', dur = ult.efeito_dur })
        end
      end
    end
  else
    for _, a in ipairs(self:vivos(u.lado)) do alvosIds[#alvosIds + 1] = a.guid end
    self:evento('especial', { de = u.guid, skill = ult.id, alvos = alvosIds })
    for _, a in ipairs(self:vivos(u.lado)) do
      if ult.tipo == 'cura' then
        local c = math.floor(u.st.atk * ult.mult + 0.5)
        a.hp = math.min(a.max, a.hp + c)
        self:evento('cura', { alvo = a.guid, v = c, hp = a.hp })
      elseif ult.tipo == 'escudo' then
        a.escudo = a.escudo + math.floor(u.st.atk * ult.mult + 0.5)
        self:evento('escudo', { alvo = a.guid, escudo = a.escudo })
      elseif ult.tipo == 'buff' then
        a.buff, a.buffT = ult.buff_atk, ult.buff_dur
        self:evento('efeito', { alvo = a.guid, efeito = 'buff', dur = ult.buff_dur })
      end
    end
  end
  return true
end

-- Pedido do jogador (toque na carta). Guardado com o tempo para replay/validação no servidor.
function Battle:pedirEspecial(guid)
  self.pedidos = self.pedidos or {}
  self.pedidos[#self.pedidos + 1] = guid
end

function Battle:passo()
  local dt = PASSO
  self.t = self.t + dt
  self:mecanica()
  if self.pedidos then
    for _, g in ipairs(self.pedidos) do
      local u = self:unidade(g)
      if u and u.lado == 'a' and self:especial(u) then
        self.registro = self.registro or {}
        self.registro[#self.registro + 1] = { t = self.t, guid = g }
      end
    end
    self.pedidos = nil
  end
  for _, u in ipairs(self.unidades) do
    if u.vivo then
      if u.buffT > 0 then u.buffT = u.buffT - dt; if u.buffT <= 0 then u.buff = 0 end end
      local morreu = false
      if u.queim > 0 then
        u.queim = u.queim - dt
        u.queimAcum = u.queimAcum + dt
        if u.queimAcum >= 1 then
          u.queimAcum = u.queimAcum - 1
          u.hp = u.hp - u.queimDps
          self:evento('queimadura', { alvo = u.guid, v = u.queimDps, hp = math.max(0, u.hp) })
          if u.hp <= 0 then u.hp = 0; u.vivo = false; morreu = true; self:evento('morte', { guid = u.guid }) end
        end
      end
      if not morreu then
        if u.atord > 0 then
          u.atord = u.atord - dt
        elseif u == self.chefeU and self.mec.fase == 'carga' then
          -- carregando a Maré Negra: o chefe não ataca nem usa especial
        elseif u.furia >= 100 and u.ult and (u.lado == 'i' or self.autoJogador) then
          self:especial(u)
        else
          u.cd = u.cd - dt
          if u.cd <= 0 then self:atacar(u); u.cd = u.cd + u.intervalo end
        end
      end
    end
  end
  local va, vi = #self:vivos('a'), #self:vivos('i')
  if vi == 0 then self:terminar(true)
  elseif va == 0 or self.t >= self.P.limite_tempo then self:terminar(false) end
end

function Battle:terminar(venceu)
  if self.fim then return end
  local mortos = 0
  for _, u in ipairs(self.unidades) do if u.lado == 'a' and not u.vivo then mortos = mortos + 1 end end
  local estrelas = venceu and (mortos == 0 and 3 or (mortos <= 2 and 2 or 1)) or 0
  self.fim = { venceu = venceu, estrelas = estrelas, tempo = self.t, especiais = self.especiaisJogador }
  self:evento('fim', { venceu = venceu, estrelas = estrelas })
end

-- Retira eventos já produzidos (o cliente consome a cada quadro).
function Battle:consumirEventos()
  local e = self.eventos
  self.eventos = {}
  return e
end

-- Simulação completa sem interface (servidor / teste).
function Battle:simular()
  while not self.fim do self:passo() end
  return self.fim
end

return Battle
