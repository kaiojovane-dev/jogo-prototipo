-- Fórmulas de atributos, economia e fases (lidas das tabelas exportadas das planilhas).
local Formula = {}

local P, H, R, I, ILHAS, SK

function Formula.init(data)
  P, H, R, I, ILHAS, SK = data.Param, data.Herois, data.Raridade, data.Inimigos, data.Ilhas, data.Skills
end

local VANTAGEM = { fogo = 'vento', vento = 'mare', mare = 'fogo', luz = 'sombra', sombra = 'luz' }
Formula.VANTAGEM = VANTAGEM
Formula.FASES_POR_ILHA = 10

local function rarMult(rar)
  for _, r in ipairs(R) do if r.raridade == rar then return r.mult end end
  return 1
end

function Formula.atributosHeroi(id, nivel, estrelas)
  local h = H[id]
  local m = rarMult(h.raridade) * (1 + P.cresc_nivel * (nivel - 1)) * (1 + P.cresc_estrela * (estrelas - 1))
  return {
    hp = math.floor(h.hp * m + 0.5), atk = math.floor(h.atk * m + 0.5), def = math.floor(h.def * m + 0.5),
    vel = h.vel, crit = h.crit, crit_dmg = h.crit_dmg,
  }
end

function Formula.atributosInimigo(id, nivel, dif)
  local t = I[id]
  local m = (1 + P.cresc_inimigo * (nivel - 1)) * dif
  return {
    hp = math.floor(t.hp * m + 0.5), atk = math.floor(t.atk * m + 0.5), def = math.floor(t.def * m + 0.5),
    vel = t.vel, crit = t.crit, crit_dmg = t.crit_dmg,
  }
end

function Formula.poder(a)
  return math.floor(a.hp * 0.18 + a.atk * 2.2 + a.def * 1.6 + a.crit * 400 + 0.5)
end

-- Sinergia: 3+ heróis do mesmo elemento
function Formula.sinergia(ids)
  local cont, melhor = {}, nil
  for _, id in pairs(ids) do
    if id and id ~= '' then
      local e = H[id].elemento
      cont[e] = (cont[e] or 0) + 1
      if cont[e] >= 3 and (not melhor or cont[e] > cont[melhor]) then melhor = e end
    end
  end
  if not melhor then return nil end
  local n = cont[melhor]
  return { elemento = melhor, n = n, bonus = n >= 5 and 0.2 or (n >= 4 and 0.15 or 0.1) }
end

function Formula.custoNivel(n)
  return { ouro = P.custo_nivel_ouro_a + P.custo_nivel_ouro_b * n, xp = P.custo_nivel_xp_a + P.custo_nivel_xp_b * n }
end

function Formula.custoEstrela(e)
  return P.custo_estrela * e
end

function Formula.totalFases()
  return #ILHAS._ordem * Formula.FASES_POR_ILHA
end

-- Fase n (0-based): ilha, inimigos e recompensa, sempre igual para a mesma n.
function Formula.fase(n)
  local Random = require('Game.Random')
  local ilhaIdx = math.min(n // Formula.FASES_POR_ILHA, #ILHAS._ordem - 1)
  local num = n % Formula.FASES_POR_ILHA + 1
  local ilha = ILHAS[ILHAS._ordem[ilhaIdx + 1]]
  local chefe = (num == Formula.FASES_POR_ILHA)
  local nivel = n + 1
  local rng = Random.new(9173 + n * 31)
  local qtd = chefe and 3 or (num < 4 and 3 or (num < 8 and 4 or 5))
  local inimigos = {}
  for i = 1, qtd do
    local isChefe = chefe and i == 1
    inimigos[i] = {
      id = isChefe and ilha.chefe or rng:pick(ilha.inimigos),
      elemento = isChefe and ilha.chefe_elemento or rng:pick(ilha.elementos),
      nivel = nivel, chefe = isChefe,
    }
  end
  return {
    n = n, ilhaIdx = ilhaIdx, ilha = ilha, num = num, chefe = chefe, nivel = nivel,
    inimigos = inimigos, dif = P.dif_base + P.dif_por_fase * num,
    recompensa = {
      ouro = P.fase_ouro_a + P.fase_ouro_b * nivel,
      xp = P.fase_xp_a + P.fase_xp_b * nivel,
      gemas = chefe and P.chefe_gemas or P.fase_gemas,
    },
  }
end

function Formula.poderFase(n)
  local f, total = Formula.fase(n), 0
  for _, ini in ipairs(f.inimigos) do total = total + Formula.poder(Formula.atributosInimigo(ini.id, ini.nivel, f.dif)) end
  return total
end

function Formula.skill(id)
  return id and id ~= '' and SK[id] or nil
end

return Formula
