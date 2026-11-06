-- Gerado por tools/excel2lua.py a partir de Inimigos.xlsx (aba Inimigos). Não edite à mão.
local t = {
  ["marujo"] = {id = "marujo", nome = "Sentinela da Liga", chefe = false, hp = 620, atk = 68, def = 34, vel = 0.9, crit = 0.05, crit_dmg = 1.5, ult = "", arte = "marujo"},
  ["atirador"] = {id = "atirador", nome = "Arcabuzeira da Liga", chefe = false, hp = 520, atk = 80, def = 28, vel = 0.85, crit = 0.08, crit_dmg = 1.5, ult = "", arte = "atirador"},
  ["pirata"] = {id = "pirata", nome = "Saqueador Rival", chefe = false, hp = 600, atk = 74, def = 30, vel = 1, crit = 0.1, crit_dmg = 1.5, ult = "", arte = "pirata"},
  ["barbasal"] = {id = "barbasal", nome = "Capitão Barba-Sal", chefe = true, hp = 3200, atk = 105, def = 50, vel = 0.9, crit = 0.15, crit_dmg = 1.6, ult = "u_barbasal", arte = "barbasal"},
}
t._ordem = {"marujo", "atirador", "pirata", "barbasal"}
return t
