-- Gerado por tools/excel2lua.py a partir de Economia.xlsx (aba Missoes). Não edite à mão.
local t = {
  ["vencer"] = {id = "vencer", nome = "Vença 3 batalhas", meta = 3, ouro = 0, gemas = 60, xp = 0},
  ["nivel"] = {id = "nivel", nome = "Suba o nível de heróis 3 vezes", meta = 3, ouro = 2000, gemas = 0, xp = 0},
  ["recrutar"] = {id = "recrutar", nome = "Recrute 1 herói na Taverna", meta = 1, ouro = 0, gemas = 50, xp = 0},
  ["coletar"] = {id = "coletar", nome = "Colete as recompensas do navio", meta = 1, ouro = 0, gemas = 0, xp = 800},
  ["especial"] = {id = "especial", nome = "Use 5 especiais em batalha", meta = 5, ouro = 0, gemas = 40, xp = 0},
}
t._ordem = {"vencer", "nivel", "recrutar", "coletar", "especial"}
return t
