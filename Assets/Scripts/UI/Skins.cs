using System.Collections.Generic;
using UnityEngine;

// Gera as "skins" 9-slice dos botões e painéis por código: gradiente vertical, borda e brilho interno.
public static class Skins
{
    static readonly Dictionary<string, Sprite> cache = new Dictionary<string, Sprite>();
    static Sprite white;

    // inner/innerW: filete interno logo depois da borda (moldura dupla, como nos painéis de gacha)
    struct Def { public Color top, bottom, border, shine, inner; public int radius, borderW, innerW; }

    static Color C(string h, float a = 1) { ColorUtility.TryParseHtmlString(h, out var c); c.a = a; return c; }

    static readonly Dictionary<string, Def> defs = new Dictionary<string, Def>
    {
        // botões: borda escura + filete claro (relevo); painéis: borda escura + filete dourado (moldura de gacha)
        { "ouro",       new Def { top = C("#ffe9a3"), bottom = C("#d98a0b"), border = C("#4a2800"), inner = C("#fff6cf", .9f), innerW = 2, shine = C("#ffffff", .55f), radius = 30, borderW = 4 } },
        { "azul",       new Def { top = C("#6cc4ff"), bottom = C("#1a4f8c"), border = C("#071a33"), inner = C("#bfe6ff", .8f), innerW = 2, shine = C("#ffffff", .35f), radius = 30, borderW = 4 } },
        { "vermelho",   new Def { top = C("#ff9a84"), bottom = C("#a3201a"), border = C("#3a0805"), inner = C("#ffd0c4", .8f), innerW = 2, shine = C("#ffffff", .35f), radius = 30, borderW = 4 } },
        { "verde",      new Def { top = C("#8ef5ab"), bottom = C("#17804a"), border = C("#062e18"), inner = C("#d2ffe0", .8f), innerW = 2, shine = C("#ffffff", .35f), radius = 30, borderW = 4 } },
        { "roxo",       new Def { top = C("#d6b0ff"), bottom = C("#5d2bb0"), border = C("#200b45"), inner = C("#ecdcff", .8f), innerW = 2, shine = C("#ffffff", .35f), radius = 30, borderW = 4 } },
        { "painel",     new Def { top = C("#1b3f73", .97f), bottom = C("#0a1a36", .97f), border = C("#050c1c"), inner = C("#e9b949"), innerW = 3, shine = C("#ffffff", .10f), radius = 34, borderW = 4 } },
        { "escuro",     new Def { top = C("#0f2240", .9f), bottom = C("#060f1f", .92f), border = C("#03070f", .9f), inner = C("#e9b949", .35f), innerW = 2, shine = C("#ffffff", .06f), radius = 28, borderW = 3 } },
        { "pergaminho", new Def { top = C("#fdf3dc"), bottom = C("#e4c98f"), border = C("#5c3810"), inner = C("#b8873a", .8f), innerW = 2, shine = C("#ffffff", .5f), radius = 26, borderW = 4 } },
        { "vidro",      new Def { top = C("#ffffff", .2f), bottom = C("#ffffff", .06f), border = C("#ffffff", .35f), shine = C("#ffffff", .15f), radius = 26, borderW = 3 } },
        { "card",       new Def { top = C("#2b4f86"), bottom = C("#0e1b36"), border = C("#050c1c"), inner = C("#ffffff", .9f), innerW = 3, shine = C("#ffffff", .15f), radius = 22, borderW = 3 } },
        { "barra",      new Def { top = C("#ffffff"), bottom = C("#d8d8d8"), border = C("#000000", 0f), shine = C("#ffffff", .4f), radius = 10, borderW = 0 } },
        { "circulo",    new Def { top = C("#ffffff"), bottom = C("#dcdcdc"), border = C("#000000", 0f), shine = C("#ffffff", 0f), radius = 47, borderW = 0 } },
    };

    public static Sprite White()
    {
        if (white) return white;
        var t = new Texture2D(4, 4, TextureFormat.RGBA32, false);
        var px = new Color[16]; for (int i = 0; i < 16; i++) px[i] = Color.white;
        t.SetPixels(px); t.Apply();
        white = Sprite.Create(t, new Rect(0, 0, 4, 4), new Vector2(.5f, .5f), 100);
        return white;
    }

    public static Sprite Get(string name)
    {
        if (cache.TryGetValue(name, out var s) && s) return s;
        if (!defs.TryGetValue(name, out var d)) d = defs["painel"];
        const int N = 96;
        var tex = new Texture2D(N, N, TextureFormat.RGBA32, false) { wrapMode = TextureWrapMode.Clamp, filterMode = FilterMode.Bilinear };
        var px = new Color[N * N];
        float r = d.radius;
        for (int y = 0; y < N; y++)
            for (int x = 0; x < N; x++)
            {
                float cx = Mathf.Clamp(x + 0.5f, r, N - r), cy = Mathf.Clamp(y + 0.5f, r, N - r);
                float dist = Vector2.Distance(new Vector2(x + 0.5f, y + 0.5f), new Vector2(cx, cy));
                float edge = r - dist;                       // >0 dentro
                float a = Mathf.Clamp01(edge + 0.5f);
                if (a <= 0) { px[y * N + x] = new Color(0, 0, 0, 0); continue; }
                float v = (float)y / (N - 1);               // 0 embaixo, 1 em cima
                Color fill = Color.Lerp(d.bottom, d.top, v);
                if (y > N * 0.62f && edge > d.borderW + 2) fill = Color.Lerp(fill, new Color(d.shine.r, d.shine.g, d.shine.b, 1), d.shine.a * (y - N * 0.62f) / (N * 0.38f));
                Color c = (d.borderW > 0 && edge < d.borderW) ? d.border
                        : (d.innerW > 0 && edge < d.borderW + d.innerW) ? Color.Lerp(fill, new Color(d.inner.r, d.inner.g, d.inner.b, 1), d.inner.a)
                        : fill;
                c.a *= a;
                px[y * N + x] = c;
            }
        tex.SetPixels(px); tex.Apply();
        float b = Mathf.Max(r, 12) + 2;
        s = Sprite.Create(tex, new Rect(0, 0, N, N), new Vector2(.5f, .5f), 100, 0, SpriteMeshType.FullRect, new Vector4(b, b, b, b));
        cache[name] = s;
        return s;
    }
}
