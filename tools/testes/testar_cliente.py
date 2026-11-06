"""Teste de fumaça do Lua do cliente sem Unity: roda main.lua com o UIKit simulado e percorre todas as telas.

Uso:  py -3.14 -I tools/testes/testar_cliente.py
"""
import os
import sys

import lupa.lua54 as lupa

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SPRITES = os.path.join(RAIZ, 'Assets', 'Resources', 'Sprites')


RIGS = os.path.join(RAIZ, 'Assets', 'Resources', 'Rigs')


def caminho_lua(p):
    return p.replace('\\', '/')


def carregar_rigs():
    """Lê e valida os rigs (Assets/Resources/Rigs/*.json) do mesmo jeito que o Boneco2D.cs."""
    import json
    rigs = {}
    if not os.path.isdir(RIGS):
        return rigs
    for f in os.listdir(RIGS):
        if not f.endswith('.json'):
            continue
        nome = f[:-5]
        with open(os.path.join(RIGS, f), encoding='utf-8') as fh:
            rig = json.load(fh)
        erros = []
        if not os.path.exists(os.path.join(SPRITES, rig['textura'] + '.png')):
            erros.append('textura inexistente: ' + rig['textura'])
        vistos = set()
        for o in rig['ossos']:
            if o.get('pai') and o['pai'] not in vistos:
                erros.append('pai depois do filho (ou inexistente): %s <- %s' % (o['pai'], o['nome']))
            vistos.add(o['nome'])
        for p in rig['partes']:
            for o in p['ossos']:
                if o not in vistos:
                    erros.append('parte %s: osso inexistente %s' % (p['nome'], o))
            for r in p.get('regioes') or []:
                if r['osso'] not in vistos:
                    erros.append('parte %s: região de osso inexistente %s' % (p['nome'], r['osso']))
        poses = {}
        for p in rig['poses']:
            t = p['v'].replace(',', ' ').split()
            for i in range(0, len(t) - 1, 2):
                if t[i] not in vistos and t[i] not in ('raiz.x', 'raiz.y', 'raiz.sx', 'raiz.sy'):
                    erros.append('pose %s: osso inexistente %s' % (p['nome'], t[i]))
                float(t[i + 1])
            if len(t) % 2:
                erros.append('pose %s: valor sem par' % p['nome'])
            poses[p['nome']] = True
        for a in rig['anims']:
            ts = [q['t'] for q in a['q']]
            if ts != sorted(ts):
                erros.append('animação %s: chaves fora de ordem' % a['nome'])
            for q in a['q']:
                base = q['p'].split('+')[0]
                if base not in poses:
                    erros.append('animação %s: pose inexistente %s' % (a['nome'], base))
            if a.get('fim') and a['fim'] not in [x['nome'] for x in rig['anims']]:
                erros.append('animação %s: fim inexistente %s' % (a['nome'], a['fim']))
        if erros:
            raise SystemExit('rig %s inválido:\n  ' % nome + '\n  '.join(erros))
        rigs[nome] = rig
    return rigs


def novo_lua(largura=1920, altura=1080, notch=0):
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    raizes = [caminho_lua(os.path.join(RAIZ, 'client', 'lua')), caminho_lua(os.path.join(RAIZ, 'shared', 'lua'))]
    lua.execute('''
      local raizes = ...
      table.insert(package.searchers, 2, function(nome)
        local rel = nome:gsub('%.', '/') .. '.lua'
        for _, r in ipairs(raizes) do
          local p = r .. '/' .. rel
          local f = io.open(p, 'rb')
          if f then
            local src = f:read('a'); f:close()
            local fn, err = load(src, '@' .. rel)
            if not fn then error(err) end
            return fn, p
          end
        end
        return nil
      end)
    ''', lua.table_from(raizes))
    mock = lua.execute(open(os.path.join(os.path.dirname(__file__), 'mock_uikit.lua'), encoding='utf-8').read())
    for f in os.listdir(SPRITES):
        if f.endswith('.svg') or f.endswith('.png'):
            mock.SPRITES[f[:-4]] = True
    # rigs dos bonecos com esqueleto: animações (duração) e ossos que o Lua pode pedir
    for nome, rig in carregar_rigs().items():
        anims = lua.table_from({a['nome']: max(q['t'] for q in a['q']) for a in rig['anims']})
        ossos = lua.table_from({o['nome']: True for o in rig['ossos']})
        mock.RIGS[nome] = lua.table_from({'anims': anims, 'ossos': ossos})
    mock.w = float(largura)
    mock.h = float(altura)
    mock.notch = float(notch)
    lua.globals().CS = lua.table_from({'UIKit': mock.K})
    return lua, mock


def relatar(mock, etapa):
    erros = list(mock.erros.values())
    avisos = list(mock.avisos.values())
    if erros or avisos:
        print('  [%s]' % etapa)
        for e in erros:
            print('    ERRO:', e)
        for a in avisos:
            print('    LOG :', a)
    for i in range(len(mock.erros), 0, -1):
        mock.erros[i] = None
    for i in range(len(mock.avisos), 0, -1):
        mock.avisos[i] = None
    return len(erros)


def batalhar(lua, mock, limite_s=240):
    """Roda quadros até aparecer o resultado; devolve 'vitoria', 'derrota' ou None."""
    for _ in range(int(limite_s * 30)):
        mock.quadro(1 / 30)
        if mock.existe('VITÓRIA!'):
            mock.quadros(60)
            return 'vitoria'
        if mock.existe('DERROTA'):
            mock.quadros(60)
            return 'derrota'
    return None


def principal():
    total = 0
    # 16:9, 20:9, 4:3 (tablet/dobrável: a tela virtual cresce na altura) e 20:9 com notch de 110 à esquerda
    for largura, altura, notch in ((1920, 1080, 0), (2400, 1080, 0), (1920, 1440, 0), (2400, 1080, 110)):
        print('== tela %dx%d%s ==' % (largura, altura, ' notch %d' % notch if notch else ''))
        lua, mock = novo_lua(largura, altura, notch)
        G = lua.globals()
        try:
            lua.execute("require('main')")
        except lupa.LuaError as e:
            print('  falha ao carregar main:', e)
            return 1
        G.Game_Start()
        mock.quadros(40)
        total += relatar(mock, 'título')

        mock.clicarUltimo('tela')        # toque para zarpar -> introdução
        for _ in range(12):
            mock.quadros(20)
            if lua.eval('G.telaAtual') == 'navio':
                break
            mock.clicarUltimo('modal')
        print('  tela após a introdução:', lua.eval('G.telaAtual'))
        mock.quadros(40)
        total += relatar(mock, 'introdução/navio')

        mock.clicar('Pegar recompensa')
        mock.quadros(60)
        total += relatar(mock, 'login')
        print('  gemas após login:', lua.eval('G.Estado.s.gemas'))

        mock.clicar('Missões'); mock.quadros(10); mock.clicar('Fechar'); mock.quadros(10)
        mock.clicar('Pilhagem'); mock.quadros(10); mock.clicar('Pilhar grátis'); mock.quadros(60)
        lua.execute('G.Telas.modalBau()'); mock.quadros(10); mock.clicar('Coletar'); mock.quadros(60)
        mock.clicar('Arena'); mock.quadros(10); mock.clicar('Ver roteiro'); mock.quadros(10); mock.clicar('Fechar'); mock.quadros(10)
        lua.execute('G.config()'); mock.quadros(10); mock.clicar('Alternar sons'); mock.clicar('Fechar'); mock.quadros(10)
        mock.quadros(300)   # falas da tripulação no convés
        total += relatar(mock, 'painéis do navio')

        # campanha: primeiras fases
        mock.clicar('AVENTURA'); mock.quadros(30)
        mock.clicar('1-1'); mock.quadros(10)
        mock.clicar('Formação'); mock.quadros(10)
        mock.clicar('Auto'); mock.quadros(10)
        mock.clicar('Pronto'); mock.quadros(10)
        mock.clicar('Zarpar!'); mock.quadros(5)
        total += relatar(mock, 'preparação')
        r = batalhar(lua, mock)
        print('  fase 1-1:', r, '| vencidas =', lua.eval('G.Estado.s.vencidas'))
        total += relatar(mock, 'batalha 1-1')
        for _ in range(3):
            if r == 'vitoria' and mock.clicar('Próxima fase'):
                r = batalhar(lua, mock)
                print('  próxima:', r, '| vencidas =', lua.eval('G.Estado.s.vencidas'))
        total += relatar(mock, 'batalhas seguidas')
        mock.clicar('Navio'); mock.quadros(20)

        # pausa e desistência
        lua.execute("G.ir('batalha', 0)"); mock.quadros(90)
        lua.execute('Game_Back()'); mock.quadros(5)
        mock.clicar('Continuar'); mock.quadros(30)
        lua.execute('Game_Back()'); mock.quadros(5)
        mock.clicar('Desistir'); mock.quadros(20)
        print('  após desistir:', lua.eval('G.telaAtual'))
        total += relatar(mock, 'pausa')

        # tripulação e ficha
        lua.execute("G.ir('navio')"); mock.quadros(10)
        mock.clicar('Tripulação'); mock.quadros(30)
        mock.clicar('Pipo'); mock.quadros(20)
        for _ in range(3):
            mock.clicar('Subir nível'); mock.quadros(15)
        mock.clicar('Evoluir estrela'); mock.quadros(10)
        mock.clicar('>'); mock.quadros(10); mock.clicar('<'); mock.quadros(10)
        print('  nível do Pipo:', lua.eval("G.Estado.s.herois.pipo.nivel"))
        total += relatar(mock, 'tripulação')

        # taverna
        lua.execute("G.ir('navio')"); mock.quadros(10)
        mock.clicar('Taverna'); mock.quadros(20)
        mock.clicar('Chances e heróis'); mock.quadros(10); mock.clicar('Fechar'); mock.quadros(10)
        mock.clicar('Recrutar 10'); mock.quadros(30 * 30)
        mock.clicar('OK'); mock.quadros(10)
        mock.clicar('Recrutar 1'); mock.quadros(30 * 8)
        mock.clicar('OK'); mock.quadros(10)
        print('  heróis após taverna:', lua.eval('(function() local n=0 for _ in pairs(G.Estado.s.herois) do n=n+1 end return n end)()'))
        total += relatar(mock, 'taverna')

        # formação manual
        lua.execute("G.ir('formacao')"); mock.quadros(10)
        mock.clicar('Pipo'); mock.quadros(5)
        mock.clicar('Pronto'); mock.quadros(10)
        total += relatar(mock, 'formação')

        # todas as habilidades e chefes: elenco completo e evoluído
        lua.execute('''
          for _, id in ipairs(G.D.Herois._ordem) do
            G.Estado.ganharHeroi(id)
            G.Estado.s.herois[id].nivel = 34
            G.Estado.s.herois[id].estrelas = 3
          end
        ''')
        combos = [
            "{'pipo','kalu','marina','lina','mirto'}",
            "{'lina','bento','marina','mirto','pipo'}",
            "{'kalu','pipo','bento','lina','mirto'}",
        ]
        for fase in (4, 9):
            for combo in combos:
                lua.execute("G.Estado.s.formacao = %s; G.Estado.s.vencidas = 30; G.Estado.s.config.auto = true" % combo)
                lua.execute("G.ir('batalha', %d)" % fase)
                r = batalhar(lua, mock)
                print('  fase %d %s: %s' % (fase + 1, combo, r))
                total += relatar(mock, 'batalha %d' % (fase + 1))
                mock.compactar()
        # modo manual: toca as cartas quando a fúria enche
        # chefe da fase 10 no manual: solta o dano ao encher e guarda o atordoamento do Pipo para a Maré Negra
        lua.execute("G.Estado.s.formacao = {'pipo','kalu','marina','lina','mirto'}; G.Estado.s.config.auto = false"
                    "; for _, h in pairs(G.Estado.s.herois) do h.nivel = 8; h.estrelas = 1 end")
        lua.execute("G.ir('batalha', 9)")
        for _ in range(30 * 120):
            mock.quadro(1 / 30)
            if mock.existe('ATORDOE!'):
                mock.clicar('ATORDOE!')
            elif mock.existe('TOQUE!'):
                mock.clicar('TOQUE!')
            if mock.existe('VITÓRIA!') or mock.existe('DERROTA'):
                break
        print('  manual fase 10 (Maré Negra canceladas: %s, sofridas: %s):' % (
            lua.eval('G.Batalha.batalha() and G.Batalha.batalha().mec.interrompidas'),
            lua.eval('G.Batalha.batalha() and G.Batalha.batalha().mec.mares')),
            'vitória' if mock.existe('VITÓRIA!') else 'derrota/sem fim')
        total += relatar(mock, 'manual')

        lua.execute("G.ir('aventura')"); mock.quadros(20)
        mock.clicar('Enseada do Farol'); mock.quadros(20)
        total += relatar(mock, 'mapa')

        # save/load: recarrega o estado salvo num Lua novo
        salvo = mock.salvo['fimdomapa_save_v1']
        lua2, mock2 = novo_lua(largura, altura, notch)
        mock2.salvo['fimdomapa_save_v1'] = salvo
        lua2.execute("require('main')")
        print('  save recarregado: vencidas =', lua2.eval('G.Estado.s.vencidas'), '| tamanho', len(salvo), 'bytes')
        total += relatar(mock2, 'recarga')
        sons = dict(mock.sons.items())
        print('  sons tocados:', sons)
        print('  nós vivos no fim:', mock.vivos())
    print('TOTAL DE ERROS:', total)
    return 1 if total else 0


if __name__ == '__main__':
    sys.exit(principal())
