"""Exporta excel/*.xlsx para tabelas Lua em shared/lua/Data/ (usadas pelo cliente e pelo servidor).
Cada aba vira Data/<Aba>Data.lua. Linhas 1-3: campo, tipo, descrição. Dados a partir da linha 4.
Abas com coluna 'id' viram dicionário por id (com _ordem); 'Param' vira chave->valor; as demais viram lista."""
import os, sys, glob
from openpyxl import load_workbook

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
ORIGEM = os.path.join(RAIZ, 'excel')
DESTINO = os.path.join(RAIZ, 'shared', 'lua', 'Data')


def lua_str(s):
    return '"' + str(s).replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n') + '"'


def conv(v, tipo, onde):
    if v is None or v == '':
        return {'int': '0', 'float': '0', 'bool': 'false', 'list': '{}'}.get(tipo, '""')
    if tipo == 'int':
        return str(int(round(float(v))))
    if tipo == 'float':
        f = float(v)
        return repr(int(f)) if f.is_integer() else repr(f)
    if tipo == 'bool':
        return 'true' if v in (True, 1, '1', 'true', 'TRUE', 'sim') else 'false'
    if tipo == 'list':
        itens = [x.strip() for x in str(v).split(',') if x.strip()]
        return '{' + ', '.join(lua_str(x) for x in itens) + '}'
    if tipo == 'str':
        return lua_str(v)
    raise ValueError('%s: tipo desconhecido %r' % (onde, tipo))


def exportar_aba(ws, arquivo):
    linhas = list(ws.iter_rows(values_only=True))
    if len(linhas) < 3:
        return None
    campos, tipos = linhas[0], linhas[1]
    cols = [(i, c, tipos[i]) for i, c in enumerate(campos) if c]
    dados = [l for l in linhas[3:] if l and any(x not in (None, '') for x in l)]
    nome = ws.title
    out = ['-- Gerado por tools/excel2lua.py a partir de %s (aba %s). Não edite à mão.' % (arquivo, nome)]
    if nome == 'Param':
        out.append('return {')
        for l in dados:
            out.append('  %s = %s,' % (l[0], conv(l[1], 'float', nome)))
        out.append('}')
    elif any(c == 'id' for _, c, _ in cols):
        ordem = []
        out.append('local t = {')
        for l in dados:
            reg = ', '.join('%s = %s' % (c, conv(l[i], t, '%s.%s' % (nome, c))) for i, c, t in cols)
            out.append('  [%s] = {%s},' % (lua_str(l[cols[0][0]]), reg))
            ordem.append(lua_str(l[cols[0][0]]))
        out.append('}')
        out.append('t._ordem = {%s}' % ', '.join(ordem))
        out.append('return t')
    else:
        out.append('return {')
        for l in dados:
            out.append('  {%s},' % ', '.join('%s = %s' % (c, conv(l[i], t, nome)) for i, c, t in cols))
        out.append('}')
    os.makedirs(DESTINO, exist_ok=True)
    caminho = os.path.join(DESTINO, nome + 'Data.lua')
    open(caminho, 'w', encoding='utf-8', newline='\n').write('\n'.join(out) + '\n')
    return nome, len(dados)


if __name__ == '__main__':
    total = []
    for xl in sorted(glob.glob(os.path.join(ORIGEM, '*.xlsx'))):
        wb = load_workbook(xl, data_only=True)
        for ws in wb.worksheets:
            r = exportar_aba(ws, os.path.basename(xl))
            if r:
                total.append(r)
    for nome, n in total:
        print('%-10s %3d linhas -> shared/lua/Data/%sData.lua' % (nome, n, nome))
    if not total:
        sys.exit('nenhuma planilha encontrada em excel/')
