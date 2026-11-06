// Recorta o fundo branco liso das artes geradas (personagens) e grava PNG com transparência.
// Uso (PowerShell): Add-Type -Path tools/arte/Recorte.cs -ReferencedAssemblies System.Drawing
//                   [Recorte]::Personagem('entrada.jpg', 'saida.png', $false)
// Regras: o fundo é o branco ligado à borda (preenchimento a partir das bordas), então brancos
// internos do personagem (olhos, camisa) ficam; a borda recebe alfa suave e perde o halo branco;
// manchas soltas pequenas (marca d'água, ruído do JPEG) são descartadas; a imagem é cortada no
// contorno do personagem com uma margem.
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Linq;
using System.Runtime.InteropServices;

public static class Recorte
{
    // distância ao branco (0 = branco puro). Abaixo de FUNDO é fundo; entre FUNDO e BORDA vira alfa parcial.
    const int FUNDO = 26, BORDA = 70, MARGEM = 12;

    static int Dist(byte r, byte g, byte b) { return 255 - Math.Min(r, Math.Min(g, b)); }

    public static string Personagem(string entrada, string saida, bool espelhar)
    {
        return Personagem(entrada, saida, espelhar, -1, int.MaxValue);
    }

    // buracoMedia/buracoArea: regiões brancas FECHADAS pelo desenho (entre pernas, dentro de laços) também viram
    // fundo quando a distância média ao branco for <= buracoMedia e a área >= buracoArea. Use Buracos() para medir.
    public static string Personagem(string entrada, string saida, bool espelhar, double buracoMedia, int buracoArea)
    {
        using (var src = new Bitmap(entrada))
        {
            int w = src.Width, h = src.Height;
            var px = Ler(src);
            var fundo = Fundo(px, w, h);
            var fila = new Queue<int>();
            if (buracoMedia >= 0)
                foreach (var b in RegioesBrancas(px, w, h, fundo))
                    if (b.Media <= buracoMedia && b.Pixels.Count >= buracoArea)
                        foreach (var i in b.Pixels) fundo[i] = true;
            // componentes do primeiro plano: fica o maior e os que tiverem pelo menos 1,5% dele
            var comp = new int[w * h];
            var areas = new List<int> { 0 };
            for (int i = 0; i < w * h; i++)
            {
                if (fundo[i] || comp[i] != 0) continue;
                int id = areas.Count, area = 0;
                comp[i] = id; fila.Enqueue(i);
                while (fila.Count > 0)
                {
                    int j = fila.Dequeue(), x = j % w, y = j / w; area++;
                    for (int k = 0; k < 4; k++)
                    {
                        int nx = x + (k == 0 ? -1 : k == 1 ? 1 : 0), ny = y + (k == 2 ? -1 : k == 3 ? 1 : 0);
                        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
                        int n = ny * w + nx;
                        if (!fundo[n] && comp[n] == 0) { comp[n] = id; fila.Enqueue(n); }
                    }
                }
                areas.Add(area);
            }
            int maior = 0; for (int k = 1; k < areas.Count; k++) maior = Math.Max(maior, areas[k]);
            int x0 = w, y0 = h, x1 = -1, y1 = -1;
            var outPx = new byte[w * h * 4];
            for (int i = 0; i < w * h; i++)
            {
                if (fundo[i] || areas[comp[i]] < maior * 0.015) continue;
                byte b = px[i * 4], g = px[i * 4 + 1], r = px[i * 4 + 2];
                int x = i % w, y = i / w;
                bool vizFundo = (x > 0 && fundo[i - 1]) || (x < w - 1 && fundo[i + 1]) || (y > 0 && fundo[i - w]) || (y < h - 1 && fundo[i + w]);
                float a = 1f;
                if (vizFundo) a = Math.Max(0f, Math.Min(1f, (Dist(r, g, b) - FUNDO) / (float)(BORDA - FUNDO)));
                if (a < 1f && a > 0f)
                {   // tira o branco misturado na borda (des-pré-multiplica contra o branco)
                    r = (byte)Math.Max(0, Math.Min(255, (r - 255 * (1 - a)) / a));
                    g = (byte)Math.Max(0, Math.Min(255, (g - 255 * (1 - a)) / a));
                    b = (byte)Math.Max(0, Math.Min(255, (b - 255 * (1 - a)) / a));
                }
                if (a <= 0f) continue;
                outPx[i * 4] = b; outPx[i * 4 + 1] = g; outPx[i * 4 + 2] = r; outPx[i * 4 + 3] = (byte)(a * 255);
                if (x < x0) x0 = x; if (y < y0) y0 = y; if (x > x1) x1 = x; if (y > y1) y1 = y;
            }
            if (x1 < 0) return "vazio: nada sobrou depois do recorte";
            x0 = Math.Max(0, x0 - MARGEM); y0 = Math.Max(0, y0 - MARGEM); x1 = Math.Min(w - 1, x1 + MARGEM); y1 = Math.Min(h - 1, y1 + MARGEM);
            int cw = x1 - x0 + 1, ch = y1 - y0 + 1;
            var crop = new byte[cw * ch * 4];
            for (int y = 0; y < ch; y++)
                for (int x = 0; x < cw; x++)
                {
                    int sx = espelhar ? x1 - x : x0 + x;
                    Buffer.BlockCopy(outPx, ((y0 + y) * w + sx) * 4, crop, (y * cw + x) * 4, 4);
                }
            using (var dst = new Bitmap(cw, ch, PixelFormat.Format32bppArgb))
            {
                Gravar(dst, crop);
                dst.Save(saida, ImageFormat.Png);
            }
            return string.Format("{0}x{1} -> {2}x{3}, componentes {4}", w, h, cw, ch, areas.Count - 1);
        }
    }

    // Cenário: só converte para PNG (sem recorte), opcionalmente redimensionando a largura.
    public static string Cenario(string entrada, string saida, int largura)
    {
        using (var src = new Bitmap(entrada))
        {
            int w = largura > 0 ? largura : src.Width, h = (int)Math.Round(src.Height * (w / (double)src.Width));
            using (var dst = new Bitmap(w, h, PixelFormat.Format24bppRgb))
            using (var g = Graphics.FromImage(dst))
            {
                g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
                g.DrawImage(src, 0, 0, w, h);
                dst.Save(saida, ImageFormat.Png);
            }
            return string.Format("{0}x{1} -> {2}x{3}", src.Width, src.Height, w, h);
        }
    }

    // fundo ligado à borda: branco quase puro alcançável a partir das bordas da imagem
    static bool[] Fundo(byte[] px, int w, int h)
    {
        var fundo = new bool[w * h];
        var fila = new Queue<int>();
        Action<int, int> semente = (x, y) => { int i = y * w + x; if (!fundo[i] && Dist(px[i * 4 + 2], px[i * 4 + 1], px[i * 4]) < FUNDO) { fundo[i] = true; fila.Enqueue(i); } };
        for (int x = 0; x < w; x++) { semente(x, 0); semente(x, h - 1); }
        for (int y = 0; y < h; y++) { semente(0, y); semente(w - 1, y); }
        while (fila.Count > 0)
        {
            int i = fila.Dequeue(), x = i % w, y = i / w;
            if (x > 0) semente(x - 1, y);
            if (x < w - 1) semente(x + 1, y);
            if (y > 0) semente(x, y - 1);
            if (y < h - 1) semente(x, y + 1);
        }
        return fundo;
    }

    class Regiao { public List<int> Pixels = new List<int>(); public double Media; public int X0, Y0, X1, Y1; }

    // regiões quase brancas que o desenho fecha (não tocam o fundo da borda)
    static List<Regiao> RegioesBrancas(byte[] px, int w, int h, bool[] fundo)
    {
        var visto = new bool[w * h];
        var lista = new List<Regiao>();
        var fila = new Queue<int>();
        for (int s = 0; s < w * h; s++)
        {
            if (fundo[s] || visto[s] || Dist(px[s * 4 + 2], px[s * 4 + 1], px[s * 4]) >= FUNDO) continue;
            var r = new Regiao { X0 = w, Y0 = h, X1 = -1, Y1 = -1 };
            double soma = 0;
            visto[s] = true; fila.Enqueue(s);
            while (fila.Count > 0)
            {
                int i = fila.Dequeue(), x = i % w, y = i / w;
                r.Pixels.Add(i); soma += Dist(px[i * 4 + 2], px[i * 4 + 1], px[i * 4]);
                if (x < r.X0) r.X0 = x; if (y < r.Y0) r.Y0 = y; if (x > r.X1) r.X1 = x; if (y > r.Y1) r.Y1 = y;
                for (int k = 0; k < 4; k++)
                {
                    int nx = x + (k == 0 ? -1 : k == 1 ? 1 : 0), ny = y + (k == 2 ? -1 : k == 3 ? 1 : 0);
                    if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
                    int n = ny * w + nx;
                    if (!fundo[n] && !visto[n] && Dist(px[n * 4 + 2], px[n * 4 + 1], px[n * 4]) < FUNDO) { visto[n] = true; fila.Enqueue(n); }
                }
            }
            r.Media = soma / r.Pixels.Count;
            lista.Add(r);
        }
        return lista;
    }

    // Lista as regiões brancas fechadas maiores que minArea (para escolher os limites de Personagem).
    public static string Buracos(string entrada, int minArea)
    {
        using (var src = new Bitmap(entrada))
        {
            int w = src.Width, h = src.Height;
            var px = Ler(src);
            var sb = new System.Text.StringBuilder();
            foreach (var r in RegioesBrancas(px, w, h, Fundo(px, w, h)))
                if (r.Pixels.Count >= minArea)
                    sb.AppendFormat("area {0,7}  media {1,5:F2}  caixa ({2},{3})-({4},{5})\n", r.Pixels.Count, r.Media, r.X0, r.Y0, r.X1, r.Y1);
            return sb.ToString();
        }
    }

    // Retrato para cartas: quadrado em volta da cabeça (topo do personagem recortado, PNG com alfa).
    // A cabeça é achada pelo centro horizontal dos pixels opacos na faixa do topo.
    public static string Retrato(string entrada, string saida, double fracaoAltura, int lado)
    {
        using (var src = new Bitmap(entrada))
        {
            int w = src.Width, h = src.Height;
            var px = Ler(src);
            int topo = -1;
            for (int y = 0; y < h && topo < 0; y++)
                for (int x = 0; x < w; x++) if (px[(y * w + x) * 4 + 3] > 128) { topo = y; break; }
            if (topo < 0) return "vazio";
            // densidade por coluna na faixa do topo: a cabeça é larga e cheia; cajados e lanças são finos
            int faixa = (int)(h * 0.22), t = (int)(h * fracaoAltura), jan = Math.Max(8, t / 3);
            var col = new int[w];
            for (int y = topo; y < Math.Min(h, topo + faixa); y++)
                for (int x = 0; x < w; x++) if (px[(y * w + x) * 4 + 3] > 128) col[x]++;
            int melhor = -1, cx = w / 2, acum = 0;
            for (int x = 0; x < w; x++)
            {
                acum += col[x] - (x >= jan ? col[x - jan] : 0);
                if (x >= jan - 1 && acum > melhor) { melhor = acum; cx = x - jan / 2; }
            }
            // topo da cabeça: primeira linha com pixels opacos na janela escolhida
            int topoCab = topo;
            for (int y = topo; y < h; y++)
            {
                int c = 0;
                for (int x = Math.Max(0, cx - jan / 2); x < Math.Min(w, cx + jan / 2); x++) if (px[(y * w + x) * 4 + 3] > 128) c++;
                if (c > jan / 6) { topoCab = y; break; }
            }
            int x0 = Math.Max(0, Math.Min(w - t, cx - t / 2)), y0 = Math.Max(0, topoCab - (int)(t * 0.06));
            using (var dst = new Bitmap(lado, lado, PixelFormat.Format32bppArgb))
            using (var g = Graphics.FromImage(dst))
            {
                g.Clear(Color.Transparent);
                g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
                g.DrawImage(src, new Rectangle(0, 0, lado, lado), new Rectangle(x0, y0, t, t), GraphicsUnit.Pixel);
                dst.Save(saida, ImageFormat.Png);
            }
            return string.Format("cabeça em x={0}, topo={1}, recorte {2}px", cx, topo, t);
        }
    }

    // Folha de conferência: imagens lado a lado na mesma altura, sobre fundo índigo (mostra o recorte).
    public static string Folha(string[] arquivos, string saida, int altura)
    {
        var imgs = new List<Image>();
        foreach (var a in arquivos) imgs.Add(Image.FromFile(a));
        int total = 20;
        foreach (var im in imgs) total += im.Width * altura / im.Height + 20;
        using (var bmp = new Bitmap(total, altura + 40))
        using (var g = Graphics.FromImage(bmp))
        {
            g.Clear(Color.FromArgb(255, 34, 30, 74));
            g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
            int x = 20;
            foreach (var im in imgs) { int w = im.Width * altura / im.Height; g.DrawImage(im, x, 20, w, altura); x += w + 20; }
            bmp.Save(saida, ImageFormat.Png);
        }
        foreach (var im in imgs) im.Dispose();
        return total + "x" + (altura + 40);
    }

    // Fatia uma folha de ícones (fundo branco): acha cada ícone como mancha grande, junta brilhos pequenos
    // vizinhos (até 'junta' px), ordena em linhas e colunas e grava cada um recortado com o nome da lista.
    public static string Fatiar(string entrada, string pasta, string[] nomes, int minArea, int junta)
    {
        using (var src = new Bitmap(entrada))
        {
            int w = src.Width, h = src.Height;
            var px = Ler(src);
            var comp = new int[w * h];
            var caixas = new List<int[]>();   // x0, y0, x1, y1, area
            var fila = new Queue<int>();
            for (int s = 0; s < w * h; s++)
            {
                if (comp[s] != 0 || Dist(px[s * 4 + 2], px[s * 4 + 1], px[s * 4]) < FUNDO) continue;
                var c = new[] { w, h, -1, -1, 0 };
                int id = caixas.Count + 1;
                comp[s] = id; fila.Enqueue(s);
                while (fila.Count > 0)
                {
                    int i = fila.Dequeue(), x = i % w, y = i / w;
                    c[4]++;
                    if (x < c[0]) c[0] = x; if (y < c[1]) c[1] = y; if (x > c[2]) c[2] = x; if (y > c[3]) c[3] = y;
                    for (int k = 0; k < 4; k++)
                    {
                        int nx = x + (k == 0 ? -1 : k == 1 ? 1 : 0), ny = y + (k == 2 ? -1 : k == 3 ? 1 : 0);
                        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
                        int n = ny * w + nx;
                        if (comp[n] == 0 && Dist(px[n * 4 + 2], px[n * 4 + 1], px[n * 4]) >= FUNDO) { comp[n] = id; fila.Enqueue(n); }
                    }
                }
                caixas.Add(c);
            }
            var grandes = caixas.FindAll(c => c[4] >= minArea);
            foreach (var p in caixas.FindAll(c => c[4] < minArea && c[4] >= 20))
            {
                int[] melhor = null; double dm = double.MaxValue;
                foreach (var g in grandes)
                {
                    double dx = Math.Max(0, Math.Max(g[0] - p[2], p[0] - g[2])), dy = Math.Max(0, Math.Max(g[1] - p[3], p[1] - g[3]));
                    double d = Math.Sqrt(dx * dx + dy * dy);
                    if (d < dm) { dm = d; melhor = g; }
                }
                if (melhor != null && dm <= junta)
                {
                    melhor[0] = Math.Min(melhor[0], p[0]); melhor[1] = Math.Min(melhor[1], p[1]);
                    melhor[2] = Math.Max(melhor[2], p[2]); melhor[3] = Math.Max(melhor[3], p[3]);
                }
            }
            // linhas: ordena por centro y e quebra quando o salto passa de meia altura média
            grandes.Sort((a, b) => (a[1] + a[3]).CompareTo(b[1] + b[3]));
            double alt = 0; foreach (var g in grandes) alt += g[3] - g[1]; alt /= Math.Max(1, grandes.Count);
            var linhas = new List<List<int[]>>();
            foreach (var g in grandes)
            {
                double cy = (g[1] + g[3]) / 2.0;
                if (linhas.Count == 0 || cy - linhas[linhas.Count - 1].ConvertAll(q => (q[1] + q[3]) / 2.0).Average() > alt * 0.5) linhas.Add(new List<int[]>());
                linhas[linhas.Count - 1].Add(g);
            }
            var ordem = new List<int[]>();
            foreach (var l in linhas) { l.Sort((a, b) => a[0].CompareTo(b[0])); ordem.AddRange(l); }
            var sb = new System.Text.StringBuilder();
            sb.AppendFormat("{0} ícones achados em {1} linhas\n", ordem.Count, linhas.Count);
            for (int i = 0; i < ordem.Count && i < nomes.Length; i++)
            {
                var g = ordem[i];
                int m = 10, x0 = Math.Max(0, g[0] - m), y0 = Math.Max(0, g[1] - m), x1 = Math.Min(w - 1, g[2] + m), y1 = Math.Min(h - 1, g[3] + m);
                string tmp = System.IO.Path.Combine(pasta, "_tmp_" + nomes[i] + ".png");
                using (var crop = src.Clone(new Rectangle(x0, y0, x1 - x0 + 1, y1 - y0 + 1), PixelFormat.Format32bppArgb)) crop.Save(tmp, ImageFormat.Png);
                sb.AppendFormat("{0}: {1}\n", nomes[i], Personagem(tmp, System.IO.Path.Combine(pasta, nomes[i] + ".png"), false, 6.0, 200));
                System.IO.File.Delete(tmp);
            }
            return sb.ToString();
        }
    }

    // Efeito de luz desenhado sobre preto: a luminância vira alfa (para brilho aditivo), a cor é des-pré-multiplicada.
    public static string Luz(string entrada, string saida, int x0, int y0, int x1, int y1)
    {
        return Luz(entrada, saida, x0, y0, x1, y1, 1.0);
    }

    // ganho > 1 deixa efeitos escuros (onda da Maré Negra) mais opacos: alfa = min(255, luminância * ganho)
    public static string Luz(string entrada, string saida, int x0, int y0, int x1, int y1, double ganho)
    {
        using (var src = new Bitmap(entrada))
        {
            x1 = Math.Min(src.Width - 1, x1); y1 = Math.Min(src.Height - 1, y1);
            int w = x1 - x0 + 1, h = y1 - y0 + 1;
            var px = Ler(src);
            var buf = new byte[w * h * 4];
            for (int y = 0; y < h; y++)
                for (int x = 0; x < w; x++)
                {
                    int i = ((y0 + y) * src.Width + x0 + x) * 4, o = (y * w + x) * 4;
                    int b = px[i], g = px[i + 1], r = px[i + 2];
                    int lum = Math.Max(r, Math.Max(g, b));
                    lum = lum < 14 ? 0 : lum;   // corta o ruído do preto do JPEG
                    if (lum > 0) { buf[o] = (byte)Math.Min(255, b * 255 / lum); buf[o + 1] = (byte)Math.Min(255, g * 255 / lum); buf[o + 2] = (byte)Math.Min(255, r * 255 / lum); }
                    if (ganho != 1.0 && lum > 0)
                    {   // efeito escuro: mantém a cor original (sem clarear) e só reforça o alfa
                        buf[o] = (byte)b; buf[o + 1] = (byte)g; buf[o + 2] = (byte)r;
                    }
                    buf[o + 3] = (byte)Math.Min(255, (int)(lum * ganho));
                }
            using (var dst = new Bitmap(w, h, PixelFormat.Format32bppArgb)) { Gravar(dst, buf); dst.Save(saida, ImageFormat.Png); }
            return w + "x" + h;
        }
    }

    // Mira para marcar juntas: a arte sobre fundo escuro com linhas a cada 'passo' px e o valor em cada linha.
    public static string Mira(string entrada, string saida, int passo)
    {
        using (var src = new Bitmap(entrada))
        using (var bmp = new Bitmap(src.Width + 60, src.Height + 40))
        using (var g = Graphics.FromImage(bmp))
        using (var fonte = new Font("Arial", 13, FontStyle.Bold))
        using (var linha = new Pen(Color.FromArgb(150, 255, 80, 80), 1))
        using (var forte = new Pen(Color.FromArgb(220, 255, 220, 60), 2))
        {
            g.Clear(Color.FromArgb(255, 30, 34, 60));
            g.DrawImage(src, 60, 40, src.Width, src.Height);
            for (int x = 0; x <= src.Width; x += passo)
            {
                g.DrawLine(x % (passo * 2) == 0 ? forte : linha, 60 + x, 40, 60 + x, 40 + src.Height);
                g.DrawString(x.ToString(), fonte, Brushes.Yellow, 60 + x - 12, 12);
            }
            for (int y = 0; y <= src.Height; y += passo)
            {
                g.DrawLine(y % (passo * 2) == 0 ? forte : linha, 60, 40 + y, 60 + src.Width, 40 + y);
                g.DrawString(y.ToString(), fonte, Brushes.Yellow, 2, 40 + y - 9);
            }
            bmp.Save(saida, ImageFormat.Png);
            return src.Width + "x" + src.Height;
        }
    }

    // Mira ampliada de um trecho (x0,y0)-(x1,y1): para desenhar polígonos de recorte com precisão.
    public static string MiraZoom(string entrada, string saida, int x0, int y0, int x1, int y1, int escala, int passo)
    {
        using (var src = new Bitmap(entrada))
        using (var bmp = new Bitmap((x1 - x0) * escala + 60, (y1 - y0) * escala + 40))
        using (var g = Graphics.FromImage(bmp))
        using (var fonte = new Font("Arial", 12, FontStyle.Bold))
        using (var linha = new Pen(Color.FromArgb(150, 255, 80, 80), 1))
        using (var forte = new Pen(Color.FromArgb(220, 255, 220, 60), 1))
        {
            g.Clear(Color.FromArgb(255, 30, 34, 60));
            g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.NearestNeighbor;
            g.DrawImage(src, new Rectangle(60, 40, (x1 - x0) * escala, (y1 - y0) * escala), new Rectangle(x0, y0, x1 - x0, y1 - y0), GraphicsUnit.Pixel);
            for (int x = (x0 / passo) * passo; x <= x1; x += passo)
            {
                if (x < x0) continue;
                int px = 60 + (x - x0) * escala;
                g.DrawLine(x % (passo * 2) == 0 ? forte : linha, px, 40, px, bmp.Height);
                g.DrawString(x.ToString(), fonte, Brushes.Yellow, px - 12, 12);
            }
            for (int y = (y0 / passo) * passo; y <= y1; y += passo)
            {
                if (y < y0) continue;
                int py = 40 + (y - y0) * escala;
                g.DrawLine(y % (passo * 2) == 0 ? forte : linha, 60, py, bmp.Width, py);
                g.DrawString(y.ToString(), fonte, Brushes.Yellow, 2, py - 9);
            }
            bmp.Save(saida, ImageFormat.Png);
            return bmp.Width + "x" + bmp.Height;
        }
    }

    // Camadas para o esqueleto 2D: separa uma parte (ex.: braço com a arma) para girar por cima do corpo.
    // 'parte' = polígono (x,y,x,y...) recortado para a camada de cima; 'apagar' = polígono removido do corpo
    // (menor que a parte perto da junta, para o corpo manter o "ombro" por baixo e não abrir buraco ao girar).
    // Saída: atlas com o corpo à esquerda e a parte à direita. Devolve "ox,oy,w,h,ax,ay" (origem na arte e posição no atlas).
    public static string Camadas(string entrada, string saida, int[] parte, int[] apagar, int margem)
    {
        using (var src = new Bitmap(entrada))
        {
            int W = src.Width, H = src.Height;
            var px = Ler(src);
            var mParte = Mascara(W, H, parte);
            var mApagar = Mascara(W, H, apagar);
            int minX = W, minY = H, maxX = 0, maxY = 0;
            for (int y = 0; y < H; y++)
                for (int x = 0; x < W; x++)
                    if (mParte[y * W + x] > 0 && px[(y * W + x) * 4 + 3] > 0)
                    { if (x < minX) minX = x; if (x > maxX) maxX = x; if (y < minY) minY = y; if (y > maxY) maxY = y; }
            minX = Math.Max(0, minX - margem); minY = Math.Max(0, minY - margem);
            maxX = Math.Min(W - 1, maxX + margem); maxY = Math.Min(H - 1, maxY + margem);
            int pw = maxX - minX + 1, ph = maxY - minY + 1;
            int AW = W + 4 + pw, AH = Math.Max(H, ph);
            var at = new byte[AW * AH * 4];
            for (int y = 0; y < H; y++)
                for (int x = 0; x < W; x++)
                {
                    int i = (y * W + x) * 4, o = (y * AW + x) * 4;
                    float k = 1f - mApagar[y * W + x];
                    at[o] = px[i]; at[o + 1] = px[i + 1]; at[o + 2] = px[i + 2]; at[o + 3] = (byte)(px[i + 3] * k);
                }
            for (int y = 0; y < ph; y++)
                for (int x = 0; x < pw; x++)
                {
                    int sx = minX + x, sy = minY + y;
                    int i = (sy * W + sx) * 4, o = (y * AW + W + 4 + x) * 4;
                    float k = mParte[sy * W + sx];
                    at[o] = px[i]; at[o + 1] = px[i + 1]; at[o + 2] = px[i + 2]; at[o + 3] = (byte)(px[i + 3] * k);
                }
            using (var bmp = new Bitmap(AW, AH, PixelFormat.Format32bppArgb))
            {
                Gravar(bmp, at);
                bmp.Save(saida, ImageFormat.Png);
            }
            return minX + "," + minY + "," + pw + "," + ph + "," + (W + 4) + ",0 atlas " + AW + "x" + AH;
        }
    }

    // máscara suave (0..1) de um polígono: 1 dentro, borda com 1,5 px de transição
    static float[] Mascara(int W, int H, int[] pol)
    {
        var m = new float[W * H];
        int n = pol.Length / 2;
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
            {
                float fx = x + 0.5f, fy = y + 0.5f;
                bool dentro = false;
                float dmin = float.MaxValue;
                for (int i = 0, j = n - 1; i < n; j = i++)
                {
                    float xi = pol[i * 2], yi = pol[i * 2 + 1], xj = pol[j * 2], yj = pol[j * 2 + 1];
                    if (((yi > fy) != (yj > fy)) && (fx < (xj - xi) * (fy - yi) / (yj - yi) + xi)) dentro = !dentro;
                    float dx = xj - xi, dy = yj - yi, l2 = dx * dx + dy * dy;
                    float t = l2 > 0 ? Math.Max(0, Math.Min(1, ((fx - xi) * dx + (fy - yi) * dy) / l2)) : 0;
                    float ex = xi + t * dx - fx, ey = yi + t * dy - fy, d = (float)Math.Sqrt(ex * ex + ey * ey);
                    if (d < dmin) dmin = d;
                }
                float s = dentro ? dmin : -dmin;
                m[y * W + x] = Math.Max(0, Math.Min(1, 0.5f + s / 1.5f));
            }
        return m;
    }

    // Grade de um mesmo trecho (x,y,w,h) de várias capturas, ampliado: para revisar animação quadro a quadro.
    public static string GradeTrecho(string[] arquivos, string saida, int x, int y, int w, int h, int colunas, float escala)
    {
        int cw = (int)(w * escala), ch = (int)(h * escala), linhas = (arquivos.Length + colunas - 1) / colunas;
        using (var bmp = new Bitmap(colunas * (cw + 6) + 6, linhas * (ch + 6) + 6))
        using (var g = Graphics.FromImage(bmp))
        using (var fonte = new Font("Arial", 11, FontStyle.Bold))
        {
            g.Clear(Color.Black);
            g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
            for (int i = 0; i < arquivos.Length; i++)
                using (var im = Image.FromFile(arquivos[i]))
                {
                    int px = 6 + (i % colunas) * (cw + 6), py = 6 + (i / colunas) * (ch + 6);
                    g.DrawImage(im, new Rectangle(px, py, cw, ch), new Rectangle(x, y, w, h), GraphicsUnit.Pixel);
                    g.DrawString(System.IO.Path.GetFileName(arquivos[i]).Substring(0, 3), fonte, Brushes.Yellow, px + 3, py + 3);
                }
            bmp.Save(saida, ImageFormat.Png);
        }
        return linhas + " linhas";
    }

    // Grade de conferência: capturas em colunas, cada uma reduzida à largura dada.
    public static string Grade(string[] arquivos, string saida, int colunas, int largura)
    {
        var imgs = new List<Image>();
        foreach (var a in arquivos) imgs.Add(Image.FromFile(a));
        int altura = imgs[0].Height * largura / imgs[0].Width, linhas = (imgs.Count + colunas - 1) / colunas;
        using (var bmp = new Bitmap(colunas * (largura + 8) + 8, linhas * (altura + 8) + 8))
        using (var g = Graphics.FromImage(bmp))
        {
            g.Clear(Color.Black);
            g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
            for (int i = 0; i < imgs.Count; i++)
                g.DrawImage(imgs[i], 8 + (i % colunas) * (largura + 8), 8 + (i / colunas) * (altura + 8), largura, altura);
            bmp.Save(saida, ImageFormat.Png);
        }
        foreach (var im in imgs) im.Dispose();
        return linhas + " linhas";
    }

    static byte[] Ler(Bitmap bmp)
    {
        var d = bmp.LockBits(new Rectangle(0, 0, bmp.Width, bmp.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        var buf = new byte[bmp.Width * bmp.Height * 4];
        for (int y = 0; y < bmp.Height; y++) Marshal.Copy(d.Scan0 + y * d.Stride, buf, y * bmp.Width * 4, bmp.Width * 4);
        bmp.UnlockBits(d);
        return buf;
    }

    static void Gravar(Bitmap bmp, byte[] buf)
    {
        var d = bmp.LockBits(new Rectangle(0, 0, bmp.Width, bmp.Height), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
        for (int y = 0; y < bmp.Height; y++) Marshal.Copy(buf, y * bmp.Width * 4, d.Scan0 + y * d.Stride, bmp.Width * 4);
        bmp.UnlockBits(d);
    }
}
