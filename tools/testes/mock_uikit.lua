-- Simulador do UIKit (C#) para testar o Lua do cliente fora do Unity.
-- Confere tipo e quantidade de argumentos como o xLua faz (quantidade errada = erro), nomes de sprites e cores.
local M = { nos = {}, erros = {}, avisos = {}, relogio = 1700000000, w = 1920, salvo = {}, sons = {} }
local SPRITES = {}   -- preenchido pelo driver
local SKINS = { ouro = 1, azul = 1, vermelho = 1, verde = 1, roxo = 1, painel = 1, escuro = 1, pergaminho = 1, vidro = 1, card = 1, barra = 1, circulo = 1 }
M.SPRITES, M.SKINS = SPRITES, SKINS

local seq = 0
local tempo = 0
local timers = {}
local camadas = {}

local function falha(msg)
  error('[UIKit] ' .. msg, 3)
end

local function no(pai, tipo, extra)
  seq = seq + 1
  local n = { id = seq, tipo = tipo, pai = pai, filhos = {}, vivo = true, ativo = true }
  if extra then for k, v in pairs(extra) do n[k] = v end end
  if pai then pai.filhos[#pai.filhos + 1] = n end
  M.nos[#M.nos + 1] = n
  return n
end

local function corOk(c) return c == '' or (type(c) == 'string' and (c:match('^#%x%x%x%x%x%x$') or c:match('^#%x%x%x%x%x%x%x%x$'))) end
local function spriteOk(s)
  if s == '' then return true end
  local skin = s:match('^skin:(.+)$')
  if skin then return SKINS[skin] ~= nil end
  return SPRITES[s] ~= nil
end

-- assinatura: o objeto, n número, i inteiro, s texto, b booleano, f função
local function checar(nome, sig, ...)
  local n = select('#', ...)
  if n ~= #sig then falha(nome .. ': esperava ' .. #sig .. ' argumentos, recebeu ' .. n) end
  local args = { ... }
  for i = 1, #sig do
    local c, v = sig:sub(i, i), args[i]
    local t = type(v)
    if c == 'o' then
      if v ~= nil and (t ~= 'table' or not v.tipo) then falha(nome .. ': arg ' .. i .. ' não é objeto (' .. t .. ')') end
    elseif c == 'n' then
      if t ~= 'number' or v ~= v then falha(nome .. ': arg ' .. i .. ' não é número (' .. tostring(v) .. ')') end
    elseif c == 'i' then
      if math.type(v) ~= 'integer' then falha(nome .. ': arg ' .. i .. ' não é inteiro (' .. tostring(v) .. ')') end
    elseif c == 's' then
      if v ~= nil and t ~= 'string' then falha(nome .. ': arg ' .. i .. ' não é texto (' .. t .. ')') end
    elseif c == 'b' then
      if t ~= 'boolean' then falha(nome .. ': arg ' .. i .. ' não é booleano (' .. tostring(v) .. ')') end
    elseif c == 'f' then
      if v ~= nil and t ~= 'function' then falha(nome .. ': arg ' .. i .. ' não é função (' .. t .. ')') end
    end
  end
end

local function matar(n)
  if not n or not n.vivo then return end
  n.vivo = false
  for _, f in ipairs(n.filhos) do matar(f) end
end

local function agendar(alvo, dur, fn)
  if fn == nil and alvo == nil then return end
  timers[#timers + 1] = { t = tempo + math.max(0.0001, dur), alvo = alvo, fn = fn }
end

local K = {}
local function def(nome, sig, corpo)
  K[nome] = function(...)
    checar(nome, sig, ...)
    if corpo then return corpo(...) end
  end
end

def('Init', 'o')
-- W/H = área útil (dentro da área segura); WTela/HTela = tela inteira (modo Expand: nunca menor que 1920 x 1080)
def('W', '', function() return M.w - (M.notch or 0) end)
def('H', '', function() return M.h or 1080.0 end)
def('WTela', '', function() return M.w end)
def('HTela', '', function() return M.h or 1080.0 end)
def('Layer', 's', function(nm)
  if not camadas[nm] or not camadas[nm].vivo then camadas[nm] = no(nil, 'layer', { nome = nm }) end
  return camadas[nm]
end)
def('Clip', 'onnnnnn', function(p) return no(p, 'clip') end)
def('Stretch', 'o')
def('Box', 'onnnnnn', function(p) return no(p, 'box') end)
def('Fill', 'ossn', function(p, sp, cor)
  if not spriteOk(sp) then falha('sprite inexistente: ' .. sp) end
  if not corOk(cor) then falha('cor inválida: ' .. tostring(cor)) end
  return no(p, 'img', { sprite = sp })
end)
def('Img', 'osnnnnsnn', function(p, sp, x, y, w, h, cor)
  if not spriteOk(sp) then falha('sprite inexistente: ' .. sp) end
  if not corOk(cor) then falha('cor inválida: ' .. tostring(cor)) end
  return no(p, 'img', { sprite = sp })
end)
def('Txt', 'osinnnnssbnn', function(p, s, size, x, y, w, h, cor)
  if not corOk(cor) then falha('cor inválida: ' .. tostring(cor)) end
  return no(p, 'txt', { texto = s })
end)
def('Btn', 'ossinnnnfnn', function(p, skin, label, size, x, y, w, h, fn)
  if skin ~= '' and not SKINS[skin] then falha('skin inexistente: ' .. skin) end
  local b = no(p, 'btn', { fn = fn })
  if label and label ~= '' then b.label = no(b, 'txt', { texto = label }) end
  return b
end)
def('SetClick', 'of', function(g, fn) if g then g.fn = fn end end)
def('Bar', 'onnnnssnn', function(p, x, y, w, h, back, front)
  if not corOk(back) or not corOk(front) then falha('cor inválida na barra') end
  return no(p, 'bar', { valor = 1 })
end)
def('SetBar', 'on', function(g, v) if g then g.valor = v end end)
def('Scroll', 'onnnnnnbnn', function(p) local s = no(p, 'scroll'); return no(s, 'content') end)
def('SetText', 'os', function(g, s)
  if not g then return end
  if g.tipo == 'txt' then g.texto = s elseif g.label then g.label.texto = s end
end)
def('SetColor', 'os', function(g, c) if not corOk(c) then falha('cor inválida: ' .. tostring(c)) end end)
def('SetAlpha', 'on')
def('SetPos', 'onn')
def('SetSize', 'onn')
def('SetScale', 'onn')
def('SetRot', 'on')
def('SetSprite', 'os', function(g, s) if not spriteOk(s) then falha('sprite inexistente: ' .. s) end end)
def('SetActive', 'ob', function(g, a) if g then g.ativo = a end end)
def('SetGray', 'ob')
def('Front', 'o')
def('SetRaycast', 'ob')
def('Kill', 'o', function(g) matar(g) end)
def('Clear', 'o', function(g) if g then for _, f in ipairs(g.filhos) do matar(f) end; g.filhos = {} end end)
def('Alive', 'o', function(g) return g ~= nil and g.vivo == true end)
def('MoveTo', 'onnnif', function(g, x, y, d, e, fn) if g and g.vivo then agendar(g, d, fn) end end)
def('ScaleTo', 'onnif', function(g, s, d, e, fn) if g and g.vivo then agendar(g, d, fn) end end)
def('FadeTo', 'onnf', function(g, a, d, fn) if g and g.vivo then agendar(g, d, fn) end end)
def('RotTo', 'onni')
def('Punch', 'onn')
def('Shake', 'onn')
def('After', 'nf', function(s, fn) agendar(nil, s, fn) end)
def('Bob', 'onn'); def('Breath', 'onn'); def('Spin', 'on'); def('Sway', 'onn'); def('StopLoop', 'o')
def('Burst', 'onnisnnnn', function(p, x, y, n, cor) if not corOk(cor) then falha('cor inválida: ' .. tostring(cor)) end end)
def('Ring', 'onnsnn', function(p, x, y, cor) if not corOk(cor) then falha('cor inválida: ' .. tostring(cor)) end end)
def('Flash', 'sn', function(cor) if not corOk(cor) then falha('cor inválida: ' .. tostring(cor)) end end)
def('Float', 'osinns', function(p, s, size, x, y, cor) if not corOk(cor) then falha('cor inválida: ' .. tostring(cor)) end end)
local SONS = { toque = 1, golpe = 1, critico = 1, especial = 1, cura = 1, moeda = 1, nivel = 1, vitoria = 1, derrota = 1, ssr = 1, abrir = 1 }
def('Som', 's', function(n) if not SONS[n] then falha('som inexistente: ' .. n) end; M.sons[n] = (M.sons[n] or 0) + 1 end)
def('Ambiente', 's')
def('SomLigado', 'b')
def('Load', 's', function(k) return M.salvo[k] or '' end)
def('Save', 'ss', function(k, v) M.salvo[k] = v end)
def('Now', '', function() return M.relogio + tempo end)
def('Vibrate', ''); def('Quit', '')
def('Log', 's', function(s) M.avisos[#M.avisos + 1] = s end)
def('Hex', 's')
def('Arg', 's', function() return '' end)
def('Shot', 's')

-- física de apresentação (UIKit.Corpo, partículas, projéteis, pausa de impacto, brilho aditivo)
def('Existe', 's', function(s) return SPRITES[s] ~= nil end)
def('Pausa', 'n')
def('Aditivo', 'o')
def('Parar', 'o')
def('Cancelar', 'o')
def('Lancar', 'onnnnnnnnbf', function(g, vx, vy, gr, chao, q, arr, giro, vida, destruir, fim)
  if g and g.vivo then agendar(g, vida > 0 and vida or 0.6, fim) end
  if destruir and g then agendar(nil, vida > 0 and vida or 0.6, function() matar(g) end) end
end)
def('Particulas', 'osnnisnnnnnnnb', function(p, sp, x, y, n, cor)
  if not spriteOk(sp) then falha('sprite inexistente: ' .. sp) end
  if not corOk(cor) then falha('cor inválida: ' .. tostring(cor)) end
end)
def('Projetil', 'osnnnnnnnnsbbsf', function(p, sp, x0, y0, x1, y1, dur, arco, w, h, cor, ori, adi, rastro, fn)
  if not spriteOk(sp) then falha('sprite inexistente: ' .. sp) end
  if not corOk(cor) then falha('cor inválida: ' .. tostring(cor)) end
  if rastro ~= '' and not corOk(rastro) then falha('cor de rastro inválida: ' .. tostring(rastro)) end
  local g = no(p, 'img', { sprite = sp })
  agendar(g, dur, fn)
  agendar(nil, dur, function() matar(g) end)
  return g
end)

-- boneco com esqueleto (Boneco2D) e tentáculos com física de corda; o driver preenche M.RIGS a partir dos JSON
local RIGS = {}
M.RIGS = RIGS
local function boneco(nome, g)
  if g ~= nil and g.tipo ~= 'boneco' then falha(nome .. ': objeto não é boneco (' .. tostring(g.tipo) .. ')') end
end
def('TemRig', 's', function(s) return RIGS[s] ~= nil end)
def('Boneco', 'osnnnnnn', function(p, arte)
  if not RIGS[arte] then falha('boneco sem rig: ' .. tostring(arte)) end
  return no(p, 'boneco', { arte = arte })
end)
def('BonecoAnim', 'osn', function(g, a, vel)
  boneco('BonecoAnim', g)
  if g and not RIGS[g.arte].anims[a] then falha('animação inexistente: ' .. tostring(a)) end
  if vel <= 0 then falha('BonecoAnim: velocidade <= 0') end
  return g and RIGS[g.arte].anims[a] / vel or 0.0
end)
def('BonecoPonto', 'osno', function(g, osso)
  boneco('BonecoPonto', g)
  if g and not RIGS[g.arte].ossos[osso] then falha('osso inexistente: ' .. tostring(osso)) end
  return 0.0, 0.0
end)
def('BonecoImpulso', 'osn', function(g, osso)
  boneco('BonecoImpulso', g)
  if g and not RIGS[g.arte].ossos[osso] then falha('osso inexistente: ' .. tostring(osso)) end
end)
def('BonecoFlacido', 'on', function(g) boneco('BonecoFlacido', g) end)
def('BonecoRastro', 'osnnosn', function(g, osso, t0, t1, camada, cor)
  boneco('BonecoRastro', g)
  if g and not RIGS[g.arte].ossos[osso] then falha('osso inexistente: ' .. tostring(osso)) end
  if not corOk(cor) then falha('cor inválida no rastro: ' .. tostring(cor)) end
end)
def('Tentaculo', 'onnnss', function(p, x, y, esp, cor, brilho)
  if not corOk(cor) or not corOk(brilho) then falha('cor inválida no tentáculo') end
  return no(p, 'tentaculo')
end)
local function tent(nome, t) if t ~= nil and t.tipo ~= 'tentaculo' then falha(nome .. ': objeto não é tentáculo') end end
def('TentPreso', 'oosn', function(t, b, osso)
  tent('TentPreso', t); boneco('TentPreso', b)
  if b and not RIGS[b.arte].ossos[osso] then falha('osso inexistente: ' .. tostring(osso)) end
end)
def('TentAlcancar', 'oonnnn', function(t) tent('TentAlcancar', t) end)
def('TentEnrolar', 'oonnnnnn', function(t) tent('TentEnrolar', t) end)
def('TentApertar', 'onn', function(t) tent('TentApertar', t) end)
def('TentSoltar', 'on', function(t, d) tent('TentSoltar', t); if t then agendar(nil, d, function() matar(t) end) end end)

-- avança o tempo e dispara callbacks (como o Runner do C#: alvo destruído = callback descartado)
function M.avancar(dt)
  tempo = tempo + dt
  local prontos = {}
  local resto = {}
  for _, t in ipairs(timers) do
    if t.t <= tempo then prontos[#prontos + 1] = t else resto[#resto + 1] = t end
  end
  timers = resto
  table.sort(prontos, function(a, b) return a.t < b.t end)
  for _, t in ipairs(prontos) do
    if t.fn and (t.alvo == nil or t.alvo.vivo) then
      local ok, err = pcall(t.fn)
      if not ok then M.erros[#M.erros + 1] = 'callback: ' .. tostring(err) end
    end
  end
end

function M.quadro(dt)
  local ok, err = pcall(Game_Update, dt)
  if not ok then M.erros[#M.erros + 1] = 'Game_Update: ' .. tostring(err) end
  M.avancar(dt)
end

function M.quadros(n, dt)
  for _ = 1, n do M.quadro(dt or (1 / 30)) end
end

local function visivel(n)
  while n do
    if not n.vivo or not n.ativo then return false end
    n = n.pai
  end
  return true
end

local function clicavel(n)
  while n do
    if n.fn then return n end
    n = n.pai
  end
end

-- procura o último nó vivo com o texto (busca simples) e clica no ancestral clicável
function M.clicar(texto)
  for i = #M.nos, 1, -1 do
    local n = M.nos[i]
    if n.tipo == 'txt' and n.texto and visivel(n) and n.texto:find(texto, 1, true) then
      local c = clicavel(n)
      if c then
        local ok, err = pcall(c.fn)
        if not ok then M.erros[#M.erros + 1] = 'clique "' .. texto .. '": ' .. tostring(err) end
        return true
      end
    end
  end
  M.erros[#M.erros + 1] = 'não achei botão com texto: ' .. texto
  return false
end

function M.clicarSprite(sp)
  for i = #M.nos, 1, -1 do
    local n = M.nos[i]
    if n.sprite == sp and visivel(n) then
      local c = clicavel(n)
      if c then
        local ok, err = pcall(c.fn)
        if not ok then M.erros[#M.erros + 1] = 'clique sprite ' .. sp .. ': ' .. tostring(err) end
        return true
      end
    end
  end
  M.erros[#M.erros + 1] = 'não achei sprite clicável: ' .. sp
  return false
end

-- clica no último botão criado dentro de uma camada
function M.clicarUltimo(camada)
  local raiz = camadas[camada]
  for i = #M.nos, 1, -1 do
    local n = M.nos[i]
    if n.fn and visivel(n) then
      local p = n
      while p.pai do p = p.pai end
      if p == raiz then
        local ok, err = pcall(n.fn)
        if not ok then M.erros[#M.erros + 1] = 'clique último ' .. camada .. ': ' .. tostring(err) end
        return true
      end
    end
  end
  M.erros[#M.erros + 1] = 'nenhum botão na camada ' .. camada
  return false
end

function M.existe(texto)
  for i = #M.nos, 1, -1 do
    local n = M.nos[i]
    if n.tipo == 'txt' and n.texto and visivel(n) and n.texto:find(texto, 1, true) then return true end
  end
  return false
end

function M.vivos()
  local c = 0
  for _, n in ipairs(M.nos) do if n.vivo then c = c + 1 end end
  return c
end

-- limpa nós mortos da lista (evita crescer sem limite nos testes longos)
function M.compactar()
  local v = {}
  for _, n in ipairs(M.nos) do if n.vivo then v[#v + 1] = n end end
  M.nos = v
end

M.K = K
return M
