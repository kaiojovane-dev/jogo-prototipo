using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

// Personagem 2D com esqueleto e física de molas, desenhado como uma malha que deforma (no estilo Spine/Live2D).
// A arte vem de um atlas (corpo + partes recortadas que giram por cima, ex.: o braço com a arma) e o rig de
// Resources/Rigs/<arte>.json. Cada osso é uma mola angular: os "músculos" seguem as poses da animação (com a
// velocidade da pose somada, para não atrasar nos golpes rápidos); cabelo, lenço e arma também sentem a inércia
// do corpo (corrida, golpe, empurrão) e a gravidade. Morto, o boneco fica "flácido" e cai pelo próprio peso.
// Só apresentação: a batalha continua decidida pelo motor determinístico em Lua.
public class Boneco2D : MaskableGraphic
{
    // ------------------------------------------------------------------ formato do rig (JSON)
    // Coordenadas da arte original em pixels (x para a direita, y para baixo). Valores 0 = padrão.
    [Serializable] public class OssoDef { public string nome, pai; public float x, y, px, py, raio, k, zeta, iner, grav, lim; public bool semPeso; }
    [Serializable] public class RegiaoDef { public string osso; public float[] pol; public float suave; }
    [Serializable] public class ParteDef { public string nome; public float ox, oy, w, h, ax, ay; public int gx, gy; public string[] ossos; public RegiaoDef[] regioes; }
    [Serializable] public class PoseDef { public string nome, v; }
    // e: 0 suave, 1 linear, 2 acelerando (golpe), 3 freando
    [Serializable] public class ChaveDef { public float t; public string p; public int e; }
    [Serializable] public class AnimDef { public string nome, fim; public bool loop; public ChaveDef[] q; }
    [Serializable] public class RigDef
    {
        public string textura; public float largura, altura, atlasW, atlasH, chao, gravidade, raizK, raizZeta;
        public OssoDef[] ossos; public ParteDef[] partes; public PoseDef[] poses; public AnimDef[] anims;
    }

    // ------------------------------------------------------------------ dados compartilhados por arte
    class Pose { public float[] ang; public float x, y, sx = 1, sy = 1; }
    class Anim { public string nome, fim; public bool loop; public float[] t; public Pose[] p; public int[] e; }

    class Modelo
    {
        public RigDef def; public Sprite sprite;
        public int n; public string[] nomes; public int[] pai;
        public Vector2[] rest, ponta; public float[] len, k, zeta, iner, grav, lim;
        public Vector2[] vp, uv; public int[] bi; public float[] bw;   // 4 influências por vértice
        public int[] tris;
        public Dictionary<string, Anim> anims = new Dictionary<string, Anim>();
        public Dictionary<string, int> indice = new Dictionary<string, int>();
        public float W, H, chao, gravidade, raizK, raizZeta;
    }

    static readonly Dictionary<string, Modelo> cache = new Dictionary<string, Modelo>();

    public static bool Tem(string arte) => Carregar(arte) != null;

    static Modelo Carregar(string arte)
    {
        if (string.IsNullOrEmpty(arte)) return null;
        if (cache.TryGetValue(arte, out var m)) return m;
        m = null;
        var ta = Resources.Load<TextAsset>("Rigs/" + arte);
        if (ta)
        {
            try { m = Montar(JsonUtility.FromJson<RigDef>(ta.text)); }
            catch (Exception e) { Debug.LogError("[Boneco] rig " + arte + ": " + e.Message); m = null; }
        }
        cache[arte] = m;
        return m;
    }

    static Modelo Montar(RigDef d)
    {
        var m = new Modelo { def = d };
        m.sprite = Resources.Load<Sprite>("Sprites/" + d.textura);
        if (!m.sprite) throw new Exception("textura inexistente: " + d.textura);
        m.W = d.largura; m.H = d.altura;
        m.chao = m.H - (d.chao > 0 ? d.chao : d.altura);
        m.gravidade = d.gravidade > 0 ? d.gravidade : 2000f;
        m.raizK = d.raizK > 0 ? d.raizK : 380f;
        m.raizZeta = d.raizZeta > 0 ? d.raizZeta : 0.42f;
        int n = d.ossos.Length;
        m.n = n; m.nomes = new string[n]; m.pai = new int[n];
        m.rest = new Vector2[n]; m.ponta = new Vector2[n]; m.len = new float[n];
        m.k = new float[n]; m.zeta = new float[n]; m.iner = new float[n]; m.grav = new float[n]; m.lim = new float[n];
        for (int i = 0; i < n; i++)
        {
            var o = d.ossos[i];
            m.nomes[i] = o.nome; m.indice[o.nome] = i;
            m.rest[i] = Img(m, o.x, o.y); m.ponta[i] = Img(m, o.px, o.py);
            m.len[i] = Mathf.Max(8f, (m.ponta[i] - m.rest[i]).magnitude);
            m.k[i] = o.k > 0 ? o.k : 300f; m.zeta[i] = o.zeta > 0 ? o.zeta : 0.5f;
            m.iner[i] = o.iner; m.grav[i] = o.grav; m.lim[i] = o.lim * Mathf.Deg2Rad;
        }
        for (int i = 0; i < n; i++)
        {
            var p = d.ossos[i].pai;
            m.pai[i] = string.IsNullOrEmpty(p) ? -1 : m.indice[p];
            if (m.pai[i] >= i) throw new Exception("o pai precisa vir antes do filho: " + d.ossos[i].nome);
        }
        MontarMalha(m);
        foreach (var a in d.anims) m.anims[a.nome] = MontarAnim(m, a);
        return m;
    }

    // arte (y para baixo) -> espaço do esqueleto (y para cima)
    static Vector2 Img(Modelo m, float x, float y) => new Vector2(x, m.H - y);

    static Pose LerPose(Modelo m, string v)
    {
        var p = new Pose { ang = new float[m.n] };
        if (string.IsNullOrEmpty(v)) return p;
        var t = v.Split(new[] { ' ', ',', '\t' }, StringSplitOptions.RemoveEmptyEntries);
        for (int i = 0; i + 1 < t.Length; i += 2)
        {
            float val = float.Parse(t[i + 1], System.Globalization.CultureInfo.InvariantCulture);
            switch (t[i])
            {
                case "raiz.x": p.x = val; break;
                case "raiz.y": p.y = val; break;
                case "raiz.sx": p.sx = val; break;
                case "raiz.sy": p.sy = val; break;
                default:
                    if (m.indice.TryGetValue(t[i], out var o)) p.ang[o] = val * Mathf.Deg2Rad;
                    else throw new Exception("osso inexistente na pose: " + t[i]);
                    break;
            }
        }
        return p;
    }

    static Anim MontarAnim(Modelo m, AnimDef a)
    {
        var poses = new Dictionary<string, string>();
        foreach (var p in m.def.poses) poses[p.nome] = p.v;
        var r = new Anim { nome = a.nome, fim = a.fim, loop = a.loop, t = new float[a.q.Length], p = new Pose[a.q.Length], e = new int[a.q.Length] };
        for (int i = 0; i < a.q.Length; i++)
        {
            var q = a.q[i];
            // "pose" ou "pose+ajuste": ajuste soma ângulos (ex.: "guarda+anteA -360")
            string nome = q.p, extra = null;
            int mais = q.p.IndexOf('+');
            if (mais >= 0) { nome = q.p.Substring(0, mais); extra = q.p.Substring(mais + 1); }
            if (!poses.TryGetValue(nome, out var v)) throw new Exception("pose inexistente: " + nome);
            var pose = LerPose(m, v);
            if (extra != null) { var ex = LerPose(m, extra); for (int j = 0; j < m.n; j++) pose.ang[j] += ex.ang[j]; }
            r.t[i] = q.t; r.p[i] = pose; r.e[i] = q.e;
        }
        return r;
    }

    // ------------------------------------------------------------------ malha e pesos
    static float DistSeg(Vector2 p, Vector2 a, Vector2 b)
    {
        var ab = b - a; float l2 = ab.sqrMagnitude;
        float t = l2 > 0 ? Mathf.Clamp01(Vector2.Dot(p - a, ab) / l2) : 0;
        return (a + ab * t - p).magnitude;
    }

    // distância com sinal até a borda do polígono (positiva dentro); polígono já no espaço do esqueleto
    static float DistPol(Vector2 p, Vector2[] pol)
    {
        bool dentro = false; float dmin = float.MaxValue;
        for (int i = 0, j = pol.Length - 1; i < pol.Length; j = i++)
        {
            var a = pol[i]; var b = pol[j];
            if (((a.y > p.y) != (b.y > p.y)) && (p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x)) dentro = !dentro;
            dmin = Mathf.Min(dmin, DistSeg(p, a, b));
        }
        return dentro ? dmin : -dmin;
    }

    static void MontarMalha(Modelo m)
    {
        var d = m.def;
        var vp = new List<Vector2>(); var uv = new List<Vector2>(); var bi = new List<int>(); var bw = new List<float>(); var tris = new List<int>();
        // retângulo COMPLETO do sprite na textura (sprite.rect). Não usar textureRect nem o UV externo: o Unity
        // apara a borda transparente do sprite e o atlas inteiro (corpo + partes) ficaria deslocado.
        var tex = m.sprite.texture; var tr = m.sprite.rect;
        float aw = d.atlasW > 0 ? d.atlasW : tr.width, ah = d.atlasH > 0 ? d.atlasH : tr.height;
        var pesos = new float[m.n];
        foreach (var parte in d.partes)
        {
            int gx = parte.gx > 0 ? parte.gx : 16, gy = parte.gy > 0 ? parte.gy : 16;
            // ossos que pesam nesta parte: por distância (os de região só valem dentro do polígono)
            var permitidos = new HashSet<int>();
            foreach (var o in parte.ossos) permitidos.Add(m.indice[o]);
            var regioes = new List<(int osso, Vector2[] pol, float suave)>();
            var deRegiao = new HashSet<int>();
            if (parte.regioes != null)
                foreach (var r in parte.regioes)
                {
                    var pol = new Vector2[r.pol.Length / 2];
                    for (int i = 0; i < pol.Length; i++) pol[i] = Img(m, r.pol[i * 2], r.pol[i * 2 + 1]);
                    int o = m.indice[r.osso];
                    regioes.Add((o, pol, r.suave > 0 ? r.suave : 8f));
                    deRegiao.Add(o);
                }
            int baseV = vp.Count;
            for (int j = 0; j <= gy; j++)
                for (int i = 0; i <= gx; i++)
                {
                    float x = parte.ox + parte.w * i / gx, y = parte.oy + parte.h * j / gy;
                    var p = Img(m, x, y);
                    vp.Add(p);
                    float ax = parte.ax + parte.w * i / gx, ay = parte.ay + parte.h * j / gy;
                    uv.Add(new Vector2((tr.x + ax / aw * tr.width) / tex.width, (tr.y + (1f - ay / ah) * tr.height) / tex.height));
                    Array.Clear(pesos, 0, pesos.Length);
                    float soma = 0;
                    foreach (int o in permitidos)
                    {
                        if (deRegiao.Contains(o) || d.ossos[o].semPeso) continue;
                        float raio = d.ossos[o].raio > 0 ? d.ossos[o].raio : 60f;
                        float q = DistSeg(p, m.rest[o], m.ponta[o]) / raio;
                        float w = 1f / Mathf.Pow(1f + q * q, 3f);
                        pesos[o] = w; soma += w;
                    }
                    if (soma > 0) for (int o = 0; o < m.n; o++) pesos[o] /= soma;
                    foreach (var r in regioes)
                    {
                        float f = Mathf.Clamp01(0.5f + DistPol(p, r.pol) / r.suave);
                        if (f <= 0) continue;
                        for (int o = 0; o < m.n; o++) pesos[o] *= (1 - f);
                        pesos[r.osso] += f;
                    }
                    // 4 maiores, normalizados
                    for (int s = 0; s < 4; s++)
                    {
                        int best = -1; float bv = 0;
                        for (int o = 0; o < m.n; o++) if (pesos[o] > bv) { bv = pesos[o]; best = o; }
                        bi.Add(best < 0 ? 0 : best); bw.Add(bv);
                        if (best >= 0) pesos[best] = 0;
                    }
                    int k0 = bw.Count - 4; float t4 = bw[k0] + bw[k0 + 1] + bw[k0 + 2] + bw[k0 + 3];
                    if (t4 <= 0) { bw[k0] = 1; } else for (int s = 0; s < 4; s++) bw[k0 + s] /= t4;
                }
            for (int j = 0; j < gy; j++)
                for (int i = 0; i < gx; i++)
                {
                    int a = baseV + j * (gx + 1) + i, b = a + 1, c = a + gx + 1, e = c + 1;
                    tris.Add(a); tris.Add(c); tris.Add(b);
                    tris.Add(b); tris.Add(c); tris.Add(e);
                }
        }
        m.vp = vp.ToArray(); m.uv = uv.ToArray(); m.bi = bi.ToArray(); m.bw = bw.ToArray(); m.tris = tris.ToArray();
    }

    // ------------------------------------------------------------------ estado da instância
    Modelo m;
    float[] a, w, alvo, alvoV;          // ângulo extra de cada osso (rad), velocidade, alvo da animação e velocidade do alvo
    float[] ang; Vector2[] pos;         // pose do mundo (espaço do esqueleto)
    float[] cosA, sinA;
    Vector2[] pAnt, vAnt, acc; int medidas;
    // canais da raiz: deslocamento x, y e escala sx, sy (molas também: o "squash & stretch" balança)
    readonly float[] rc = { 0, 0, 1, 1 }, rv = new float[4], ra = { 0, 0, 1, 1 }, rav = new float[4];
    Anim anim; float animT, animVel = 1;
    float flacidez = 1;
    Vector2[] pele;                     // vértices deformados (espaço local do RectTransform)
    bool sujo = true;

    public override Texture mainTexture => m != null && m.sprite ? m.sprite.texture : s_WhiteTexture;

    public bool Iniciar(string arte)
    {
        m = Carregar(arte);
        if (m == null) return false;
        int n = m.n;
        a = new float[n]; w = new float[n]; alvo = new float[n]; alvoV = new float[n];
        ang = new float[n]; pos = new Vector2[n]; cosA = new float[n]; sinA = new float[n];
        pAnt = new Vector2[n]; vAnt = new Vector2[n]; acc = new Vector2[n];
        pele = new Vector2[m.vp.Length];
        raycastTarget = false;
        Tocar(m.anims.ContainsKey("parado") ? "parado" : null, 1);
        Cinematica();
        sujo = true;
        SetVerticesDirty();
        return true;
    }

    // toca uma animação; devolve a duração (s) já com a velocidade
    public float Tocar(string nome, float vel)
    {
        if (m == null) return 0;
        if (nome == null || !m.anims.TryGetValue(nome, out var an)) return 0;
        anim = an; animT = 0; animVel = vel > 0 ? vel : 1;
        // ângulos que deram a volta inteira (ex.: o giro da frigideira) voltam para perto do novo alvo sem desenrolar
        var p0 = an.p[0];
        for (int i = 0; i < m.n; i++)
        {
            float k = Mathf.Round((a[i] - p0.ang[i]) / (Mathf.PI * 2));
            a[i] -= k * Mathf.PI * 2;
        }
        Avaliar();
        return an.t[an.t.Length - 1] / animVel;
    }

    public void Impulso(string osso, float grausPorSeg)
    {
        if (m == null || !m.indice.TryGetValue(osso, out var i)) return;
        w[i] += grausPorSeg * Mathf.Deg2Rad;
    }

    public void Flacido(float f) { flacidez = Mathf.Clamp(f, 0.01f, 1f); }

    // ponto ao longo do osso (0 = junta, 1 = ponta) em coordenadas do mundo
    public Vector3 PontoMundo(string osso, float t)
    {
        if (m == null || !m.indice.TryGetValue(osso, out var i)) return transform.position;
        var d = (m.ponta[i] - m.rest[i]) * t;
        var p = pos[i] + new Vector2(d.x * cosA[i] - d.y * sinA[i], d.x * sinA[i] + d.y * cosA[i]);
        return transform.TransformPoint(ParaLocal(Escalar(p)));
    }

    // ------------------------------------------------------------------ animação
    static float Ease(int e, float u)
    {
        switch (e)
        {
            case 1: return u;
            case 2: return u * u;
            case 3: return 1 - (1 - u) * (1 - u);
            default: return u * u * (3 - 2 * u);
        }
    }
    static float EaseD(int e, float u)
    {
        switch (e)
        {
            case 1: return 1;
            case 2: return 2 * u;
            case 3: return 2 * (1 - u);
            default: return 6 * u * (1 - u);
        }
    }

    void Avaliar()
    {
        if (anim == null) { for (int i = 0; i < m.n; i++) { alvo[i] = 0; alvoV[i] = 0; } return; }
        var t = anim.t; int n = t.Length;
        float tt = animT;
        if (n == 1 || tt >= t[n - 1]) { Copiar(anim.p[n - 1], 0, null, 0); return; }
        int j = 0;
        while (j < n - 2 && tt >= t[j + 1]) j++;
        float dur = Mathf.Max(0.0001f, t[j + 1] - t[j]);
        float u = Mathf.Clamp01((tt - t[j]) / dur);
        int e = anim.e[j + 1];
        Copiar(anim.p[j], Ease(e, u), anim.p[j + 1], EaseD(e, u) / dur * animVel);
    }

    void Copiar(Pose a0, float s, Pose a1, float ds)
    {
        for (int i = 0; i < m.n; i++)
        {
            float b = a1 != null ? a1.ang[i] : a0.ang[i];
            alvo[i] = a0.ang[i] + (b - a0.ang[i]) * s;
            alvoV[i] = (b - a0.ang[i]) * ds;
        }
        var b1 = a1 ?? a0;
        Canal(0, a0.x, b1.x, s, ds); Canal(1, a0.y, b1.y, s, ds);
        Canal(2, a0.sx, b1.sx, s, ds); Canal(3, a0.sy, b1.sy, s, ds);
    }

    void Canal(int c, float v0, float v1, float s, float ds) { ra[c] = v0 + (v1 - v0) * s; rav[c] = (v1 - v0) * ds; }

    // ------------------------------------------------------------------ física
    void LateUpdate()
    {
        if (m == null) return;
        float dt = UIKit.Dt();
        if (dt <= 0) { if (sujo) { sujo = false; SetVerticesDirty(); } return; }
        dt = Mathf.Min(dt, 1f / 20f);
        if (anim != null)
        {
            animT += dt * animVel;
            float fimT = anim.t[anim.t.Length - 1];
            if (animT >= fimT)
            {
                if (anim.loop && fimT > 0) animT %= fimT;
                else if (!string.IsNullOrEmpty(anim.fim)) { Tocar(anim.fim, 1); }
            }
            Avaliar();
        }
        Medir(dt);
        int passos = Mathf.Clamp(Mathf.CeilToInt(dt * 240f), 1, 12);
        float h = dt / passos;
        Vector2 g = Gravidade();
        for (int s = 0; s < passos; s++) Passo(h, g);
        Cinematica();
        SetVerticesDirty();
    }

    // aceleração de cada junta no mundo (corrida, empurrão, giro do pai), convertida para o espaço do esqueleto
    void Medir(float dt)
    {
        var cv = canvas ? (RectTransform)canvas.rootCanvas.transform : null;
        if (!cv) return;
        float esc = Escala();
        if (esc <= 0) return;
        for (int i = 0; i < m.n; i++)
        {
            Vector2 p = cv.InverseTransformPoint(transform.TransformPoint(ParaLocal(Escalar(pos[i]))));
            if (medidas < 2) { pAnt[i] = p; vAnt[i] = Vector2.zero; acc[i] = Vector2.zero; continue; }
            var v = (p - pAnt[i]) / dt;
            if (v.sqrMagnitude > 25000f * 25000f) v = vAnt[i];          // teletransporte (SetPos): ignora
            var ac = (v - vAnt[i]) / dt;
            if (ac.sqrMagnitude > 500000f * 500000f) ac = ac.normalized * 500000f;
            Vector2 local = transform.InverseTransformVector(cv.TransformVector(ac));
            acc[i] = Vector2.Lerp(acc[i], local / esc, 1f - Mathf.Exp(-dt / 0.03f));
            pAnt[i] = p; vAnt[i] = v;
        }
        medidas++;
    }

    Vector2 Gravidade()
    {
        var cv = canvas ? canvas.rootCanvas.transform : null;
        Vector3 baixo = cv ? cv.TransformVector(Vector3.down) : Vector3.down;
        Vector2 l = transform.InverseTransformVector(baixo);
        return l.sqrMagnitude > 0 ? l.normalized * m.gravidade : Vector2.down * m.gravidade;
    }

    void Passo(float h, Vector2 g)
    {
        for (int i = 0; i < m.n; i++)
        {
            float k = m.k[i] * flacidez;
            float c = 2f * m.zeta[i] * Mathf.Sqrt(k);
            float al = k * (alvo[i] - a[i]) + c * (alvoV[i] * flacidez - w[i]);
            // direção atual do osso (pivô -> ponta) no mundo do esqueleto
            var d = m.ponta[i] - m.rest[i];
            float cs = cosA[i], sn = sinA[i];
            var u = new Vector2(d.x * cs - d.y * sn, d.x * sn + d.y * cs) / m.len[i];
            float L = m.len[i] * 0.6f;
            if (m.iner[i] > 0)
            {
                var F = -acc[i];
                float t = m.iner[i] * (u.x * F.y - u.y * F.x) / L;
                al += Mathf.Clamp(t, -260f, 260f);
            }
            float gr = flacidez < 1f ? Mathf.Max(m.grav[i], 1f) : m.grav[i];
            if (gr > 0)
            {
                float t = u.x * g.y - u.y * g.x;
                if (flacidez >= 1f)
                {
                    // só o desvio em relação à pose de descanso: parado, o acessório não cai
                    var u0 = d / m.len[i];
                    t -= u0.x * g.y - u0.y * g.x;
                }
                al += gr * t / L;
            }
            w[i] += al * h;
            w[i] *= Mathf.Exp(-0.5f * h);
            a[i] += w[i] * h;
            if (m.lim[i] > 0 && flacidez >= 1f)
            {
                float lo = alvo[i] - m.lim[i], hi = alvo[i] + m.lim[i];
                if (a[i] < lo) { a[i] = lo; w[i] = Mathf.Max(w[i], alvoV[i]); }
                else if (a[i] > hi) { a[i] = hi; w[i] = Mathf.Min(w[i], alvoV[i]); }
            }
        }
        float kr = m.raizK * Mathf.Max(flacidez, 0.3f), cr = 2f * m.raizZeta * Mathf.Sqrt(kr);
        for (int c = 0; c < 4; c++)
        {
            float al = kr * (ra[c] - rc[c]) + cr * (rav[c] - rv[c]);
            rv[c] += al * h;
            rc[c] += rv[c] * h;
        }
        // cinemática a cada passo (a direção dos ossos alimenta a inércia do próximo)
        Cinematica();
    }

    void Cinematica()
    {
        var off = new Vector2(rc[0], rc[1]);
        for (int i = 0; i < m.n; i++)
        {
            int p = m.pai[i];
            if (p < 0) { ang[i] = a[i]; pos[i] = m.rest[i] + off; }
            else
            {
                var d = m.rest[i] - m.rest[p];
                pos[i] = pos[p] + new Vector2(d.x * cosA[p] - d.y * sinA[p], d.x * sinA[p] + d.y * cosA[p]);
                ang[i] = ang[p] + a[i];
            }
            cosA[i] = Mathf.Cos(ang[i]); sinA[i] = Mathf.Sin(ang[i]);
        }
    }

    // escala global da raiz (achata e estica a partir dos pés)
    Vector2 Escalar(Vector2 p)
    {
        float gx = m.rest[0].x + rc[0], gy = m.chao;
        return new Vector2(gx + (p.x - gx) * rc[2], gy + (p.y - gy) * rc[3]);
    }

    float Escala()
    {
        var r = rectTransform.rect;
        return Mathf.Min(r.width / m.W, r.height / m.H);
    }

    Vector2 ParaLocal(Vector2 p)
    {
        var r = rectTransform.rect; float s = Escala();
        return new Vector2(r.center.x + (p.x - m.W * 0.5f) * s, r.center.y + (p.y - m.H * 0.5f) * s);
    }

    protected override void OnPopulateMesh(VertexHelper vh)
    {
        vh.Clear();
        if (m == null || pele == null) return;
        var vp = m.vp; var bi = m.bi; var bw = m.bw;
        Color32 c = color;
        var v = UIVertex.simpleVert;
        v.color = c;
        for (int k = 0; k < vp.Length; k++)
        {
            Vector2 r = Vector2.zero; var o = vp[k];
            for (int s = 0; s < 4; s++)
            {
                float wt = bw[k * 4 + s];
                if (wt <= 0) continue;
                int b = bi[k * 4 + s];
                var d = o - m.rest[b];
                r += wt * (pos[b] + new Vector2(d.x * cosA[b] - d.y * sinA[b], d.x * sinA[b] + d.y * cosA[b]));
            }
            v.position = ParaLocal(Escalar(r));
            v.uv0 = m.uv[k];
            vh.AddVert(v);
        }
        var t = m.tris;
        for (int k = 0; k < t.Length; k += 3) vh.AddTriangle(t[k], t[k + 1], t[k + 2]);
    }
}

// Rastro de golpe: fita aditiva varrida entre dois pontos de um osso (ex.: cabo e borda da frigideira).
// Guarda as últimas posições por alguns centésimos e desbota pela idade: o arco do golpe fica no ar por um instante.
public class RastroGolpe : MaskableGraphic
{
    const int K = 20;
    const float IDADE = 0.11f;
    readonly Vector2[] a = new Vector2[K], b = new Vector2[K];
    readonly float[] idade = new float[K];
    int n;
    Boneco2D boneco; string osso; float t0, t1, resta;

    // Uso (Lua): K.BonecoRastro(v.arte, 'frigideira', 0.55, 1.5, st.fx, '#fff1c4', 0.4)
    public static RastroGolpe Criar(GameObject camada, Boneco2D b, string osso, float t0, float t1, Color cor, float dur)
    {
        var g = new GameObject("rastro", typeof(RectTransform));
        var rt = (RectTransform)g.transform;
        rt.SetParent(camada.transform, false);
        rt.anchorMin = rt.anchorMax = new Vector2(0.5f, 0.5f);
        rt.anchoredPosition = Vector2.zero; rt.sizeDelta = new Vector2(10, 10);
        var r = g.AddComponent<RastroGolpe>();
        r.boneco = b; r.osso = osso; r.t0 = t0; r.t1 = t1; r.resta = dur; r.color = cor; r.raycastTarget = false;
        UIKit.Aditivo(g);
        return r;
    }

    void LateUpdate()
    {
        float dt = UIKit.Dt();
        if (dt <= 0) return;
        for (int i = 0; i < n; i++) idade[i] += dt;
        while (n > 0 && idade[n - 1] > IDADE) n--;
        resta -= dt;
        if (resta > 0 && boneco)
        {
            // empurra as amostras e grava a nova na frente
            for (int i = Mathf.Min(n, K - 1); i > 0; i--) { a[i] = a[i - 1]; b[i] = b[i - 1]; idade[i] = idade[i - 1]; }
            a[0] = transform.InverseTransformPoint(boneco.PontoMundo(osso, t0));
            b[0] = transform.InverseTransformPoint(boneco.PontoMundo(osso, t1));
            idade[0] = 0;
            n = Mathf.Min(n + 1, K);
        }
        else if (n == 0) { Destroy(gameObject); return; }
        SetVerticesDirty();
    }

    protected override void OnPopulateMesh(VertexHelper vh)
    {
        vh.Clear();
        if (n < 2) return;
        var v = UIVertex.simpleVert;
        for (int i = 0; i < n; i++)
        {
            float k = 1f - Mathf.Clamp01(idade[i] / IDADE);
            var c = color; c.a *= k * k;
            v.color = c;
            // o lado de dentro (cabo) é mais fraco que a borda
            var ci = c; ci.a *= 0.25f;
            v.color = ci; v.position = a[i]; vh.AddVert(v);
            v.color = c; v.position = b[i]; vh.AddVert(v);
        }
        for (int i = 0; i < n - 1; i++)
        {
            int q = i * 2;
            vh.AddTriangle(q, q + 1, q + 2);
            vh.AddTriangle(q + 1, q + 3, q + 2);
        }
    }
}
