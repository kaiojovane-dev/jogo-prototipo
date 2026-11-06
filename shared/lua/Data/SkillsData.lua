-- Gerado por tools/excel2lua.py a partir de Herois.xlsx (aba Skills). Não edite à mão.
local t = {
  ["u_lina"] = {id = "u_lina", nome = "Chuva de Espinhos", tipo = "dano", alvo = "aleatorio", n = 4, mult = 1.25, efeito = "queimar", efeito_chance = 1, efeito_dur = 3, efeito_pct = 0.25, buff_atk = 0, buff_dur = 0, desc = "4 disparos do peixe-leão em alvos aleatórios (125%) que deixam queimadura."},
  ["u_mirto"] = {id = "u_mirto", nome = "Casco Sereno", tipo = "cura", alvo = "aliados", n = 0, mult = 2.1, efeito = "", efeito_chance = 0, efeito_dur = 0, efeito_pct = 0, buff_atk = 0, buff_dur = 0, desc = "A tartaruga de luz cura toda a tripulação (210% do ATQ)."},
  ["u_bento"] = {id = "u_bento", nome = "Mordida do Tubarão", tipo = "dano", alvo = "frente", n = 0, mult = 1.9, efeito = "", efeito_chance = 0, efeito_dur = 0, efeito_pct = 0, buff_atk = 0, buff_dur = 0, desc = "O tubarão de luz avança sobre a linha da frente inimiga (190% do ATQ)."},
  ["u_marina"] = {id = "u_marina", nome = "Bote da Moreia", tipo = "dano", alvo = "tras", n = 0, mult = 1.6, efeito = "", efeito_chance = 0, efeito_dur = 0, efeito_pct = 0, buff_atk = 0, buff_dur = 0, desc = "A moreia de luz ataca a linha de trás inimiga (160% do ATQ)."},
  ["u_pipo"] = {id = "u_pipo", nome = "Abraço do Polvo", tipo = "dano", alvo = "unico", n = 0, mult = 1.5, efeito = "atordoar", efeito_chance = 1, efeito_dur = 2, efeito_pct = 0, buff_atk = 0, buff_dur = 0, desc = "Tentáculos de luz agarram o alvo (150% do ATQ) e o atordoam por 2 s. Cancela a Maré Negra."},
  ["u_barbasal"] = {id = "u_barbasal", nome = "Tempestade de Sal", tipo = "dano", alvo = "todos", n = 0, mult = 1.2, efeito = "", efeito_chance = 0, efeito_dur = 0, efeito_pct = 0, buff_atk = 0, buff_dur = 0, desc = "Golpe giratório em todos."},
  ["u_kalu"] = {id = "u_kalu", nome = "Asas da Raia", tipo = "escudo", alvo = "aliados", n = 0, mult = 2.4, efeito = "", efeito_chance = 0, efeito_dur = 0, efeito_pct = 0, buff_atk = 0, buff_dur = 0, desc = "A raia de luz abre as asas e protege toda a tripulação (escudo de 240% do ATQ)."},
}
t._ordem = {"u_lina", "u_mirto", "u_bento", "u_marina", "u_pipo", "u_barbasal", "u_kalu"}
return t
