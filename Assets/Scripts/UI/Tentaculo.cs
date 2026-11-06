using UnityEngine;
using UnityEngine.UI;

// Tentáculo de luz com física de corda (Verlet + restrições de distância). Nasce preso a um ponto ou a um osso
// de um Boneco2D, estica até o alvo num chicote curvo, se enrola nele (a espiral acompanha o alvo, que pode ser
// erguido e batido no chão) e depois recolhe. Desenhado como uma fita que afina até a ponta, com ventosas e um
// halo aditivo. Coordenadas: as do pai (o objeto fica no centro do pai, sem deslocamento).
public class Tentaculo : MonoBehaviour
{
    const int N = 32, M = 16;             // pontos da corda; pontos da espiral (ponta) quando enrola
    public readonly Vector2[] p = new Vector2[N];
    readonly Vector2[] q = new Vector2[N];
    readonly float[] rest = new float[N], restVivo = new float[N];   // alvo e valor suavizado (sem tranco ao trocar de modo)
    public readonly float[] alfa = new float[N];
    public float esp = 26f, opacidade = 1f;
    public Color cor = new Color(0.78f, 0.42f, 1f), brilho = new Color(0.69f, 0.3f, 1f, 0.8f);

    Boneco2D preso; string osso; float ossoT; Vector2 ancora;
    enum Modo { Parado, Alcancar, Enrolar, Soltar }
    Modo modo = Modo.Parado;
    Transform alvo; Vector2 alvoOff; float t, dur, curva; Vector2 pontaIni;
    float raioX, raioY, altura, voltas, fase, aperto = 1f, apertoIni = 1f, apertoAlvo = 1f, apertoT, apertoDur;
    float relogio;
    Fita core, halo;
    bool iniciado;

    public static Tentaculo Criar(GameObject pai, float x, float y, float espessura, Color cor, Color brilho)
    {
        var g = new GameObject("tentaculo", typeof(RectTransform));
        var rt = (RectTransform)g.transform;
        rt.SetParent(pai.transform, false);
        rt.anchorMin = rt.anchorMax = new Vector2(0.5f, 0.5f);
        rt.anchoredPosition = Vector2.zero; rt.sizeDelta = new Vector2(10, 10);
        var tc = g.AddComponent<Tentaculo>();
        tc.esp = espessura; tc.cor = cor; tc.brilho = brilho;
        tc.ancora = new Vector2(x, y);
        for (int i = 0; i < N; i++) { tc.p[i] = tc.q[i] = tc.ancora; tc.alfa[i] = 1; }
        tc.halo = Fita.Nova(g, tc, true);
        tc.core = Fita.Nova(g, tc, false);
        return tc;
    }

    public void Preso(Boneco2D b, string nomeOsso, float t01) { preso = b; osso = nomeOsso; ossoT = t01; AtualizarAncora(); }

    public void Alcancar(Transform a, Vector2 off, float duracao, float curv)
    {
        alvo = a; alvoOff = off; dur = Mathf.Max(0.05f, duracao); curva = curv; t = 0;
        AtualizarAncora();
        pontaIni = ancora;
        modo = Modo.Alcancar;
    }

    public void Enrolar(Transform a, float dy, float rx, float ry, float alt, float nVoltas, float fase0)
    {
        alvo = a; alvoOff = new Vector2(0, dy); raioX = rx; raioY = ry; altura = alt; voltas = nVoltas; fase = fase0;
        t = 0; dur = 0.12f; modo = Modo.Enrolar;
    }

    public void Apertar(float k, float d) { apertoIni = aperto; apertoAlvo = k; apertoT = 0; apertoDur = Mathf.Max(0.01f, d); }

    // solta: zera a velocidade guardada (o alvo acabou de bater no chão) para o tentáculo recolher sem chicotear
    public void Soltar(float d)
    {
        t = 0; dur = Mathf.Max(0.05f, d); modo = Modo.Soltar;
        for (int i = 0; i < N; i++) q[i] = p[i];
    }

    void AtualizarAncora()
    {
        if (preso) ancora = transform.InverseTransformPoint(preso.PontoMundo(osso, ossoT));
    }

    Vector2 CentroAlvo()
    {
        if (!alvo) return p[N - 1];
        return (Vector2)transform.InverseTransformPoint(alvo.position) + alvoOff;
    }

    Vector2 Espiral(int j, Vector2 c)
    {
        float f = j / (float)(M - 1);
        float th = fase + voltas * Mathf.PI * 2f * f;
        return c + new Vector2(Mathf.Cos(th) * raioX * aperto, Mathf.Sin(th) * raioY * aperto + (f - 0.5f) * altura);
    }

    void Update()
    {
        float dt = UIKit.Dt();
        if (dt <= 0) return;
        dt = Mathf.Min(dt, 1f / 20f);
        relogio += dt; t += dt;
        if (preso) AtualizarAncora();
        if (apertoT < apertoDur) { apertoT += dt; aperto = Mathf.Lerp(apertoIni, apertoAlvo, Mathf.SmoothStep(0, 1, apertoT / apertoDur)); }

        // comprimentos de descanso de cada segmento conforme o modo
        Vector2 c = CentroAlvo();
        float livre;
        if (modo == Modo.Enrolar)
        {
            float lc = 0;
            for (int j = 1; j < M; j++) lc += (Espiral(j, c) - Espiral(j - 1, c)).magnitude;
            livre = (Espiral(0, c) - ancora).magnitude * 1.06f + 6f;
            for (int i = 0; i < N - 1; i++) rest[i] = i < N - M ? livre / (N - M) : lc / (M - 1);
        }
        else
        {
            float alc;
            if (modo == Modo.Alcancar)
            {
                float u = Mathf.Clamp01(t / dur);
                alc = (c - ancora).magnitude * (0.15f + 0.95f * (1 - (1 - u) * (1 - u) * (1 - u))) + 12f;
            }
            else if (modo == Modo.Soltar) alc = Mathf.Max(2f, (p[N - 1] - ancora).magnitude * (1f - Mathf.Clamp01(t / dur)) * 0.9f);
            else alc = 2f;
            for (int i = 0; i < N - 1; i++) rest[i] = alc / (N - 1);
        }

        float kr = 1f - Mathf.Exp(-dt * 16f);
        for (int i = 0; i < N - 1; i++) restVivo[i] = iniciado ? Mathf.Lerp(restVivo[i], rest[i], kr) : rest[i];

        int passos = Mathf.Clamp(Mathf.CeilToInt(dt * 120f), 1, 6);
        float h = dt / passos;
        for (int s = 0; s < passos; s++) Passo(h, c);

        // opacidade: nasce rápido, some ao recolher; a parte da espiral atrás do alvo fica translúcida
        if (modo == Modo.Soltar)
        {
            opacidade = 1f - Mathf.Clamp01((t - dur * 0.2f) / (dur * 0.8f));
            if (t >= dur) { Destroy(gameObject); return; }
        }
        for (int i = 0; i < N; i++) alfa[i] = 1f;
        if (modo == Modo.Enrolar)
            for (int j = 0; j < M; j++)
            {
                float f = j / (float)(M - 1);
                float th = fase + voltas * Mathf.PI * 2f * f;
                alfa[N - M + j] = Mathf.Sin(th) > 0.15f ? 0.35f : 1f;
            }
        iniciado = true;
        core.SetVerticesDirty(); halo.SetVerticesDirty();
    }

    void Passo(float h, Vector2 c)
    {
        p[0] = q[0] = ancora;
        // integra (Verlet) com gravidade leve e uma onda lateral que dá vida ao tentáculo
        float amort = modo == Modo.Soltar ? 0.9f : 0.985f;
        for (int i = 1; i < N; i++)
        {
            var vel = (p[i] - q[i]) * amort;
            q[i] = p[i];
            var dir = (p[Mathf.Min(i + 1, N - 1)] - p[i - 1]);
            var nrm = dir.sqrMagnitude > 0.01f ? new Vector2(-dir.y, dir.x).normalized : Vector2.up;
            float f = i / (float)(N - 1);
            float onda = Mathf.Sin(relogio * 9f - i * 0.55f) * 2600f * f * (modo == Modo.Enrolar ? 0.25f : 1f);
            var ac = new Vector2(0, -320f) + nrm * onda;
            p[i] += vel + ac * h * h;
        }
        // a ponta é conduzida pelo modo
        if (modo == Modo.Alcancar)
        {
            float u = Mathf.Clamp01(t / dur), e = 1 - (1 - u) * (1 - u) * (1 - u);
            var reto = Vector2.Lerp(pontaIni, c, e);
            var d = c - pontaIni;
            var n = d.sqrMagnitude > 1 ? new Vector2(-d.y, d.x).normalized : Vector2.up;
            Fixar(N - 1, reto + n * Mathf.Sin(Mathf.PI * e) * curva, 1f);
        }
        else if (modo == Modo.Enrolar)
        {
            float k = Mathf.Clamp01(t / dur);
            for (int j = 0; j < M; j++) Fixar(N - M + j, Espiral(j, c), Mathf.Lerp(0.25f, 1f, k));
        }
        else if (modo == Modo.Soltar)
        {
            Fixar(N - 1, Vector2.Lerp(p[N - 1], ancora, 0.18f), 1f);
        }
        // restrições de distância (várias iterações) + rigidez de dobra: pontos i e i+2 não chegam perto
        // demais, então a corda curva mas não dobra em zigue-zague quando sobra comprimento
        for (int it = 0; it < 10; it++)
        {
            for (int i = 0; i < N - 1; i++)
            {
                var d = p[i + 1] - p[i];
                float l = d.magnitude;
                if (l < 0.0001f) continue;
                float diff = (l - restVivo[i]) / l;
                bool fixoA = i == 0, fixoB = Fixo(i + 1);
                if (fixoA && fixoB) continue;
                if (fixoA) p[i + 1] -= d * diff;
                else if (fixoB) p[i] += d * diff;
                else { p[i] += d * diff * 0.5f; p[i + 1] -= d * diff * 0.5f; }
            }
            for (int i = 0; i < N - 2; i++)
            {
                var d = p[i + 2] - p[i];
                float l = d.magnitude, min = (restVivo[i] + restVivo[i + 1]) * 0.9f;
                if (l >= min || l < 0.0001f) continue;
                var corr = d * ((min - l) / l * 0.25f);
                bool fixoA = i == 0 || Fixo(i), fixoB = Fixo(i + 2);
                if (fixoA && fixoB) continue;
                if (fixoA) p[i + 2] += corr * 2f;
                else if (fixoB) p[i] -= corr * 2f;
                else { p[i] -= corr; p[i + 2] += corr; }
            }
            p[0] = ancora;
        }
    }

    bool Fixo(int i)
    {
        if (modo == Modo.Alcancar) return i == N - 1;
        if (modo == Modo.Enrolar) return i >= N - M && t >= dur;
        return false;
    }

    void Fixar(int i, Vector2 alvoP, float k)
    {
        var novo = Vector2.Lerp(p[i], alvoP, k);
        q[i] += novo - p[i];         // arrasta junto a posição anterior: sem "estilingue" ao soltar
        p[i] = novo;
        if (k < 1f) q[i] = Vector2.Lerp(q[i], p[i], 0.5f);
    }

    public bool Pronto => iniciado;
    public int Pontos => N;
}

// Fita desenhada ao longo dos pontos do tentáculo: miolo com ventosas (textura gerada) ou halo de brilho (aditivo).
public class Fita : MaskableGraphic
{
    Tentaculo dono; bool ehHalo;
    static Texture2D texMiolo, texHalo;

    public static Fita Nova(GameObject pai, Tentaculo t, bool halo)
    {
        var g = new GameObject(halo ? "halo" : "miolo", typeof(RectTransform));
        var rt = (RectTransform)g.transform;
        rt.SetParent(pai.transform, false);
        rt.anchorMin = rt.anchorMax = new Vector2(0.5f, 0.5f);
        rt.anchoredPosition = Vector2.zero; rt.sizeDelta = new Vector2(10, 10);
        var f = g.AddComponent<Fita>();
        f.dono = t; f.ehHalo = halo; f.raycastTarget = false;
        if (halo) UIKit.Aditivo(g);
        return f;
    }

    public override Texture mainTexture => ehHalo ? Halo() : Miolo();

    // seção do tentáculo: borda escura, dorso roxo com reflexo, barriga clara com uma ventosa por período (v repete)
    static Texture2D Miolo()
    {
        if (texMiolo) return texMiolo;
        const int W = 64, H = 64;
        var t = new Texture2D(W, H, TextureFormat.RGBA32, false) { wrapMode = TextureWrapMode.Repeat, filterMode = FilterMode.Bilinear };
        var px = new Color[W * H];
        // tons do espírito do polvo (a arte da Marca): violeta com reflexo quase branco e barriga rosada
        Color borda = new Color(0.32f, 0.07f, 0.46f), dorso = new Color(0.74f, 0.4f, 1f), luz = new Color(1f, 0.88f, 1f),
              barriga = new Color(1f, 0.8f, 0.95f), ventosa = new Color(0.9f, 0.5f, 0.85f), centro = new Color(1f, 0.94f, 1f);
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
            {
                float u = (x + 0.5f) / W, v = (y + 0.5f) / H;
                Color c;
                if (u < 0.08f || u > 0.92f) c = borda;
                else if (u < 0.58f)
                {
                    float k = Mathf.Abs(u - 0.26f) / 0.2f;
                    c = Color.Lerp(luz, dorso, Mathf.Clamp01(k));
                }
                else c = Color.Lerp(dorso, barriga, Mathf.Clamp01((u - 0.58f) / 0.1f));
                // ventosa: anel na barriga
                float dx = (u - 0.76f) / 0.13f, dy = (v - 0.5f) / 0.36f, r = Mathf.Sqrt(dx * dx + dy * dy);
                if (r < 1f) c = r > 0.62f ? ventosa : Color.Lerp(centro, ventosa, r / 0.62f * 0.5f);
                // borda suave (a fita não serrilha)
                float a = Mathf.Clamp01(Mathf.Min(u, 1 - u) / 0.03f);
                c.a = a;
                px[y * W + x] = c;
            }
        t.SetPixels(px); t.Apply();
        texMiolo = t;
        return t;
    }

    static Texture2D Halo()
    {
        if (texHalo) return texHalo;
        const int W = 64;
        var t = new Texture2D(W, 4, TextureFormat.RGBA32, false) { wrapMode = TextureWrapMode.Clamp, filterMode = FilterMode.Bilinear };
        var px = new Color[W * 4];
        for (int x = 0; x < W; x++)
        {
            float u = (x + 0.5f) / W, k = 1f - Mathf.Abs(u * 2f - 1f);
            for (int y = 0; y < 4; y++) px[y * W + x] = new Color(1, 1, 1, k * k);
        }
        t.SetPixels(px); t.Apply();
        texHalo = t;
        return t;
    }

    // curva lisa: 3 amostras Catmull-Rom por segmento (buffers reaproveitados, nada alocado por quadro)
    const int SUB = 3;
    Vector2[] curva; float[] alfaC;

    static Vector2 CatmullRom(Vector2 a, Vector2 b, Vector2 c, Vector2 d, float t)
    {
        float t2 = t * t, t3 = t2 * t;
        return 0.5f * (2f * b + (c - a) * t + (2f * a - 5f * b + 4f * c - d) * t2 + (3f * b - a - 3f * c + d) * t3);
    }

    protected override void OnPopulateMesh(VertexHelper vh)
    {
        vh.Clear();
        if (dono == null || !dono.Pronto) return;
        var p = dono.p; int n = p.Length;
        int m = (n - 1) * SUB + 1;
        if (curva == null || curva.Length != m) { curva = new Vector2[m]; alfaC = new float[m]; }
        for (int i = 0; i < n - 1; i++)
            for (int s = 0; s < SUB; s++)
            {
                float t = s / (float)SUB;
                curva[i * SUB + s] = CatmullRom(p[Mathf.Max(i - 1, 0)], p[i], p[i + 1], p[Mathf.Min(i + 2, n - 1)], t);
                alfaC[i * SUB + s] = Mathf.Lerp(dono.alfa[i], dono.alfa[i + 1], t);
            }
        curva[m - 1] = p[n - 1]; alfaC[m - 1] = dono.alfa[n - 1];

        float largura = dono.esp * (ehHalo ? 2.4f : 1f);
        Color baseCor = ehHalo ? dono.brilho : dono.cor;
        float comp = 0;
        var v = UIVertex.simpleVert;
        for (int i = 0; i < m; i++)
        {
            var tg = curva[Mathf.Min(i + 1, m - 1)] - curva[Mathf.Max(i - 1, 0)];
            var nr = tg.sqrMagnitude > 0.0001f ? new Vector2(-tg.y, tg.x).normalized : Vector2.up;
            float f = i / (float)(m - 1);
            // grosso na base, afina até uma ponta fina e arredondada
            float w = largura * 0.5f * Mathf.Pow(1f - 0.88f * f, 0.9f) * (1f + 0.25f * Mathf.Clamp01(1f - f * 8f));
            if (i > 0) comp += (curva[i] - curva[i - 1]).magnitude;
            var c = baseCor; c.a *= dono.opacidade * alfaC[i];
            v.color = c;
            float vv = comp / Mathf.Max(8f, dono.esp * 1.4f);
            v.position = curva[i] + nr * w; v.uv0 = new Vector2(0, vv); vh.AddVert(v);
            v.position = curva[i] - nr * w; v.uv0 = new Vector2(1, vv); vh.AddVert(v);
        }
        for (int i = 0; i < m - 1; i++)
        {
            int a = i * 2;
            vh.AddTriangle(a, a + 1, a + 2);
            vh.AddTriangle(a + 1, a + 3, a + 2);
        }
    }
}
