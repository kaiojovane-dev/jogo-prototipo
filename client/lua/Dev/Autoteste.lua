-- Modo de teste automático: percorre todas as telas e salva capturas. Ativado com  -autotest <pasta>  na linha de comando.
-- Também serve para gerar imagens de divulgação de cada versão.
local K = CS.UIKit
local A = {}
local passos, atual, espera, dir = {}, 0, 0, ''
local capturas = 0

local function shot(nome)
  capturas = capturas + 1
  K.Shot(dir .. '/' .. string.format('%02d', capturas) .. '_' .. nome .. '.png')
  K.Log('autoteste: captura ' .. nome)
end
A.shot = shot

local function add(t, fn) passos[#passos + 1] = { t = t, fn = fn } end
local function ate(cond, max, fn) passos[#passos + 1] = { cond = cond, max = max or 120, fn = fn } end

function A.iniciar(pasta)
  dir = pasta
  local Est, T = G.Estado, G.Telas
  Est.resetar()
  Est.s.intro = false
  K.Log('autoteste: início em ' .. dir)
  add(3.0, function() shot('titulo') end)
  add(0.1, function() T.intro() end)
  add(2.8, function() shot('introducao') end)
  add(0.1, function() G.ir('navio') end)
  add(2.0, function() shot('login_diario') end)
  add(0.1, function() Game_Back() end)
  add(2.5, function() shot('navio') end)
  add(0.1, function() T.modalMissoes() end)
  add(1.0, function() shot('missoes') end)
  add(0.1, function() Game_Back(); T.modalBau() end)
  add(1.0, function() shot('bau') end)
  add(0.1, function() G.ir('taverna') end)
  add(2.0, function() shot('taverna') end)
  add(0.1, function() T.recrutar(10) end)
  add(1.8, function() shot('recrutar_bau') end)
  add(3.2, function() shot('recrutar_revelacao') end)
  add(4.5, function() shot('recrutar_cartas') end)
  add(0.1, function() G.ir('tripulacao') end)
  add(2.0, function() shot('tripulacao') end)
  add(0.1, function() G.ir('heroi', G.lider()) end)
  add(1.6, function() shot('ficha_heroi') end)
  add(0.1, function() G.ir('formacao') end)
  add(1.6, function() shot('formacao') end)
  add(0.1, function() G.ir('aventura') end)
  add(2.0, function() shot('mapa') end)
  add(0.1, function() T.preparar(0) end)
  add(1.0, function() shot('preparacao') end)
  add(0.1, function() G.ir('batalha', 0) end)
  add(0.9, function() shot('batalha_abertura') end)
  add(2.4, function() shot('batalha_combate') end)
  ate(function() return A.cutin end, 40, function() end)
  add(0.3, function() shot('batalha_especial') end)
  ate(function() return G.Batalha.terminou() end, 120, nil)
  add(1.6, function() shot('vitoria') end)
  -- tripulação mais forte para as telas de chefe e das outras ilhas
  add(0.1, function()
    for _, id in ipairs(G.D.Herois._ordem) do
      Est.ganharHeroi(id)
      Est.s.herois[id].nivel = 8  -- forte o bastante para a captura, fraco o bastante para o chefe chegar à carga
    end
    Est.s.formacao = { 'pipo', 'kalu', 'marina', 'lina', 'mirto' }
    Est.s.vencidas = 9
    G.ir('batalha', 9)
  end)
  add(2.6, function() shot('chefe_entrada') end)
  -- Maré Negra: captura o telégrafo e, com o Pipo pronto, o cancelamento
  ate(function() return G.Batalha.emCarga() end, 30, function() end)
  add(0.6, function() shot('mare_negra_carga') end)
  add(0.1, function()
    local b = G.Batalha.batalha and G.Batalha.batalha()
    if b then for _, u in ipairs(b:vivos('a')) do if u.id == 'pipo' then u.furia = 100; b:pedirEspecial(u.guid) end end end
  end)
  add(1.4, function() shot('mare_negra_interrompida') end)
  add(0.1, function() G.ir('aventura') end)
  add(2.0, function() shot('mapa_completo') end)
  add(0.1, function() G.ir('tripulacao') end)
  add(2.0, function() shot('tripulacao_completa') end)
  add(0.1, function() T.roteiro() end)
  add(1.0, function() shot('roteiro') end)
  add(0.5, function()
    K.Log('autoteste: fim, ' .. capturas .. ' capturas')
    Est.resetar()
    K.Quit()
  end)
end

function A.update(dt)
  if atual > #passos then return end
  if atual == 0 then atual = 1; espera = 0 end
  local p = passos[atual]
  espera = espera + dt
  if p.cond then
    if p.cond() or espera >= p.max then
      if p.fn then p.fn() end
      atual, espera = atual + 1, 0
    end
  elseif espera >= p.t then
    local ok, err = pcall(p.fn)
    if not ok then K.Log('autoteste: erro ' .. tostring(err)) end
    atual, espera = atual + 1, 0
  end
end

return A
