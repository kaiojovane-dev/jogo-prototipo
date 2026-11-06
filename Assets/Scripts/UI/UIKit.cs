using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;
using XLua;

// Primitivas de interface, animação e efeitos usadas pelos scripts Lua para montar as telas.
// Coordenadas virtuais: altura 1080. Cada elemento é ancorado em (ax, ay) do pai, com centro em (x, y).
[LuaCallCSharp]
public static class UIKit
{
    static Canvas canvas;
    static RectTransform root;
    static Font font;
    static Runner runner;
    static readonly Dictionary<string, GameObject> layers = new Dictionary<string, GameObject>();
    static readonly Dictionary<string, Sprite> sprites = new Dictionary<string, Sprite>();

    // ------------------------------------------------------------------ inicialização
    public static void Init(GameObject host)
    {
        var cgo = new GameObject("UI", typeof(RectTransform));
        cgo.transform.SetParent(host.transform, false);
        canvas = cgo.AddComponent<Canvas>();
        canvas.renderMode = RenderMode.ScreenSpaceOverlay;
        canvas.pixelPerfect = false;
        var scaler = cgo.AddComponent<CanvasScaler>();
        scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
        scaler.referenceResolution = new Vector2(1920, 1080);
        // Expand: a tela virtual nunca é menor que 1920 x 1080. Celular comprido (19.5:9, 21:9) ganha largura;
        // tablet e dobrável (4:3, 3:2, 16:10) ganham altura — nada do layout de 1920 sai da tela.
        scaler.screenMatchMode = CanvasScaler.ScreenMatchMode.Expand;
        cgo.AddComponent<GraphicRaycaster>();
        root = (RectTransform)cgo.transform;

        // área segura (notch, furo da câmera): os cenários ocupam a tela toda; o conteúdo fica dentro dela
        var sg = new GameObject("seguro", typeof(RectTransform));
        seguro = (RectTransform)sg.transform;
        seguro.SetParent(root, false);
        float.TryParse(Arg("-notch"), System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out notchTeste);
        AplicarAreaSegura();

        var es = new GameObject("EventSystem");
        es.transform.SetParent(host.transform, false);
        es.AddComponent<EventSystem>();
        es.AddComponent<StandaloneInputModule>();

        font = Resources.Load<Font>("Fonts/LilitaOne-Regular");
        runner = host.AddComponent<Runner>();
    }

    // ------------------------------------------------------------------ tamanho da tela e área segura
    static RectTransform seguro;
    static Rect areaAplicada;
    static float notchTeste;   // -notch <px>: simula um entalhe à esquerda (teste no PC)

    // escala do CanvasScaler em modo Expand
    static float EscalaTela() => Mathf.Max(0.0001f, Mathf.Min(Screen.width / 1920f, Screen.height / 1080f));

    // tela inteira em unidades virtuais (>= 1920 x 1080): para cenários e véus que cobrem tudo
    public static float WTela() => Screen.width > 0 ? Screen.width / EscalaTela() : 1920f;
    public static float HTela() => Screen.height > 0 ? Screen.height / EscalaTela() : 1080f;

    // área útil (dentro da área segura): é nela que o conteúdo e os botões são posicionados
    public static float W() => Screen.width > 0 ? WTela() * AreaSegura().width / Screen.width : 1920f;
    public static float H() => Screen.height > 0 ? HTela() * AreaSegura().height / Screen.height : 1080f;

    static Rect AreaSegura()
    {
        var a = Screen.safeArea;
        if (notchTeste > 0) a = new Rect(notchTeste, 0, Screen.width - notchTeste, Screen.height);
        if (a.width <= 1 || a.height <= 1) a = new Rect(0, 0, Screen.width, Screen.height);
        return a;
    }

    // ancora a camada "seguro" na área segura atual (muda ao girar o aparelho: o entalhe troca de lado)
    static void AplicarAreaSegura()
    {
        if (!seguro || Screen.width <= 0 || Screen.height <= 0) return;
        var a = AreaSegura();
        if (a == areaAplicada) return;
        areaAplicada = a;
        seguro.anchorMin = new Vector2(a.xMin / Screen.width, a.yMin / Screen.height);
        seguro.anchorMax = new Vector2(a.xMax / Screen.width, a.yMax / Screen.height);
        seguro.offsetMin = seguro.offsetMax = Vector2.zero;
    }

    // Camadas: 'fundo' (cenário) e 'flash' cobrem a tela inteira; as demais ficam na área segura.
    public static GameObject Layer(string name)
    {
        if (layers.TryGetValue(name, out var g) && g) return g;
        g = new GameObject(name, typeof(RectTransform));
        var rt = (RectTransform)g.transform;
        bool inteira = name == "fundo" || name == "flash";
        rt.SetParent(inteira || !seguro ? root : seguro, false);
        rt.anchorMin = Vector2.zero; rt.anchorMax = Vector2.one; rt.offsetMin = rt.offsetMax = Vector2.zero;
        if (name == "fundo") rt.SetAsFirstSibling();
        layers[name] = g;
        return g;
    }

    // ------------------------------------------------------------------ criação
    static RectTransform Make(GameObject parent, string name, float x, float y, float w, float h, float ax, float ay)
    {
        var g = new GameObject(name, typeof(RectTransform));
        var rt = (RectTransform)g.transform;
        rt.SetParent(parent ? parent.transform : root, false);
        rt.anchorMin = rt.anchorMax = new Vector2(ax, ay);
        rt.pivot = new Vector2(0.5f, 0.5f);
        rt.anchoredPosition = new Vector2(x, y);
        rt.sizeDelta = new Vector2(w, h);
        return rt;
    }

    public static GameObject Box(GameObject p, float x, float y, float w, float h, float ax, float ay)
    {
        return Make(p, "box", x, y, w, h, ax, ay).gameObject;
    }

    // Preenche o pai inteiro (com margem opcional)
    public static GameObject Fill(GameObject p, string sprite, string color, float margin)
    {
        var rt = Make(p, "fill", 0, 0, 0, 0, 0.5f, 0.5f);
        rt.anchorMin = Vector2.zero; rt.anchorMax = Vector2.one;
        rt.offsetMin = new Vector2(margin, margin); rt.offsetMax = new Vector2(-margin, -margin);
        var img = rt.gameObject.AddComponent<Image>();
        ApplySprite(img, sprite);
        img.color = Hex(color);
        img.raycastTarget = false;
        return rt.gameObject;
    }

    // Recorte retangular: filhos que saem da área ficam escondidos (retratos, cartas).
    public static GameObject Clip(GameObject p, float x, float y, float w, float h, float ax, float ay)
    {
        var rt = Make(p, "clip", x, y, w, h, ax, ay);
        rt.gameObject.AddComponent<RectMask2D>();
        return rt.gameObject;
    }

    // Desliga a proporção fixa (camadas de cenário esticam na largura da tela).
    public static void Stretch(GameObject g) { if (g) { var i = g.GetComponent<Image>(); if (i) i.preserveAspect = false; } }

    public static GameObject Img(GameObject p, string sprite, float x, float y, float w, float h, string color, float ax, float ay)
    {
        var rt = Make(p, sprite, x, y, w, h, ax, ay);
        var img = rt.gameObject.AddComponent<Image>();
        ApplySprite(img, sprite);
        img.color = Hex(color);
        img.raycastTarget = false;
        return rt.gameObject;
    }

    public static GameObject Txt(GameObject p, string text, int size, float x, float y, float w, float h, string color, string align, bool outline, float ax, float ay)
    {
        var rt = Make(p, "txt", x, y, w, h, ax, ay);
        var t = rt.gameObject.AddComponent<Text>();
        t.font = font;
        t.text = text;
        t.fontSize = size;
        t.color = Hex(color);
        t.raycastTarget = false;
        t.horizontalOverflow = HorizontalWrapMode.Wrap;
        t.verticalOverflow = VerticalWrapMode.Overflow;
        t.supportRichText = true;
        t.alignment = Align(align);
        if (outline)
        {
            var o = rt.gameObject.AddComponent<Outline>();
            o.effectColor = new Color(0.06f, 0.05f, 0.12f, 0.95f);
            o.effectDistance = new Vector2(Mathf.Max(2, size / 16f), -Mathf.Max(2, size / 16f));
            var s = rt.gameObject.AddComponent<Shadow>();
            s.effectColor = new Color(0, 0, 0, 0.45f);
            s.effectDistance = new Vector2(0, -Mathf.Max(3, size / 10f));
        }
        return rt.gameObject;
    }

    public static GameObject Btn(GameObject p, string skin, string label, int size, float x, float y, float w, float h, LuaFunction fn, float ax, float ay)
    {
        var rt = Make(p, "btn", x, y, w, h, ax, ay);
        var img = rt.gameObject.AddComponent<Image>();
        ApplySprite(img, skin.Length > 0 ? "skin:" + skin : "");
        if (skin.Length == 0) img.color = new Color(1, 1, 1, 0);
        var b = rt.gameObject.AddComponent<Button>();
        b.transition = Selectable.Transition.None;
        if (!string.IsNullOrEmpty(label))
        {
            var dark = skin == "ouro" || skin == "pergaminho";
            var t = Txt(rt.gameObject, label, size, 0, 2, w - 16, h, dark ? "#3b2300" : "#ffffff", "C", !dark, 0.5f, 0.5f);
            t.name = "label";
        }
        SetClick(rt.gameObject, fn);
        return rt.gameObject;
    }

    public static void SetClick(GameObject g, LuaFunction fn)
    {
        var b = g.GetComponent<Button>() ?? g.AddComponent<Button>();
        b.transition = Selectable.Transition.None;
        var gr = g.GetComponent<Graphic>();
        if (gr) gr.raycastTarget = true;
        else { var im = g.AddComponent<Image>(); im.color = new Color(0, 0, 0, 0); }
        var holder = g.GetComponent<LuaCallback>() ?? g.AddComponent<LuaCallback>();
        holder.Set(fn);
        b.onClick.RemoveAllListeners();
        b.onClick.AddListener(() =>
        {
            Sfx.Play("toque");
            Punch(g, 0.08f, 0.18f);
            holder.Invoke();
        });
        if (!g.GetComponent<PressScale>()) g.AddComponent<PressScale>();
    }

    // Barra (vida, fúria, progresso). SetBar ajusta o preenchimento (0..1).
    public static GameObject Bar(GameObject p, float x, float y, float w, float h, string back, string front, float ax, float ay)
    {
        var rt = Make(p, "bar", x, y, w, h, ax, ay);
        var bg = rt.gameObject.AddComponent<Image>();
        ApplySprite(bg, "skin:barra");
        bg.color = Hex(back);
        bg.raycastTarget = false;
        var f = Make(rt.gameObject, "fill", 0, 0, 0, 0, 0, 0);
        f.anchorMin = Vector2.zero; f.anchorMax = Vector2.one; f.offsetMin = new Vector2(2, 2); f.offsetMax = new Vector2(-2, -2);
        f.pivot = new Vector2(0, 0.5f);
        var fi = f.gameObject.AddComponent<Image>();
        ApplySprite(fi, "skin:barra");
        fi.color = Hex(front);
        fi.raycastTarget = false;
        return rt.gameObject;
    }

    public static void SetBar(GameObject bar, float v)
    {
        if (!bar) return;
        var f = (RectTransform)bar.transform.Find("fill");
        if (!f) return;
        v = Mathf.Clamp01(v);
        f.anchorMax = new Vector2(v, 1);
        f.gameObject.SetActive(v > 0.001f);
    }

    public static GameObject Scroll(GameObject p, float x, float y, float w, float h, float cw, float ch, bool vertical, float ax, float ay)
    {
        var rt = Make(p, "scroll", x, y, w, h, ax, ay);
        rt.gameObject.AddComponent<RectMask2D>();
        var bgi = rt.gameObject.AddComponent<Image>();
        bgi.color = new Color(0, 0, 0, 0);
        var sr = rt.gameObject.AddComponent<ScrollRect>();
        var content = Make(rt.gameObject, "content", 0, 0, cw, ch, 0, 1);
        content.pivot = new Vector2(0, 1);
        content.anchoredPosition = Vector2.zero;
        sr.content = content;
        sr.horizontal = !vertical; sr.vertical = vertical;
        sr.movementType = ScrollRect.MovementType.Elastic;
        sr.scrollSensitivity = 30;
        sr.viewport = rt;
        return content.gameObject;
    }


    // ------------------------------------------------------------------ alterações
    public static void SetText(GameObject g, string s)
    {
        if (!g) return;
        var t = g.GetComponent<Text>() ?? g.GetComponentInChildren<Text>();
        if (t) t.text = s;
    }
    public static void SetColor(GameObject g, string c)
    {
        if (!g) return;
        var gr = g.GetComponent<Graphic>();
        if (gr) gr.color = Hex(c);
    }
    public static void SetAlpha(GameObject g, float a)
    {
        if (!g) return;
        var cg = g.GetComponent<CanvasGroup>() ?? g.AddComponent<CanvasGroup>();
        cg.alpha = a;
    }
    public static void SetPos(GameObject g, float x, float y)
    {
        if (!g) return;
        ((RectTransform)g.transform).anchoredPosition = new Vector2(x, y);
        var a = g.GetComponent<Loop>();
        if (a) a.basePos = new Vector2(x, y);
    }
    public static void SetSize(GameObject g, float w, float h) { if (g) ((RectTransform)g.transform).sizeDelta = new Vector2(w, h); }
    public static void SetScale(GameObject g, float sx, float sy) { if (g) g.transform.localScale = new Vector3(sx, sy, 1); }
    public static void SetRot(GameObject g, float z) { if (g) g.transform.localEulerAngles = new Vector3(0, 0, z); }
    public static void SetSprite(GameObject g, string s) { if (g) { var i = g.GetComponent<Image>(); if (i) ApplySprite(i, s); } }
    public static void SetActive(GameObject g, bool a) { if (g) g.SetActive(a); }
    public static void SetGray(GameObject g, bool on)
    {
        if (!g) return;
        foreach (var gr in g.GetComponentsInChildren<Graphic>(true))
        {
            if (gr is Text) continue;
            var c = gr.color;
            gr.color = on ? new Color(c.r * 0.35f, c.g * 0.35f, c.b * 0.4f, c.a) : c;
        }
    }
    public static void Front(GameObject g) { if (g) g.transform.SetAsLastSibling(); }
    public static void SetRaycast(GameObject g, bool on) { if (g) { var gr = g.GetComponent<Graphic>(); if (gr) gr.raycastTarget = on; } }
    public static void Kill(GameObject g) { if (g) UnityEngine.Object.Destroy(g); }
    public static void Clear(GameObject g)
    {
        if (!g) return;
        for (int i = g.transform.childCount - 1; i >= 0; i--) UnityEngine.Object.Destroy(g.transform.GetChild(i).gameObject);
    }
    public static bool Alive(GameObject g) => g;

    // ------------------------------------------------------------------ animação
    // ease: 0 linear, 1 saída suave, 2 entrada, 3 saída com recuo, 4 seno ida-e-volta
    public static void MoveTo(GameObject g, float x, float y, float dur, int ease, LuaFunction done)
    {
        if (!g) return;
        var rt = (RectTransform)g.transform;
        Vector2 a = rt.anchoredPosition, b = new Vector2(x, y);
        runner.Add(g, dur, ease, t => { if (rt) rt.anchoredPosition = Vector2.LerpUnclamped(a, b, t); }, done);
    }
    public static void ScaleTo(GameObject g, float s, float dur, int ease, LuaFunction done)
    {
        if (!g) return;
        var tr = g.transform; Vector3 a = tr.localScale, b = new Vector3(s * Mathf.Sign(a.x == 0 ? 1 : a.x), s, 1);
        runner.Add(g, dur, ease, t => { if (tr) tr.localScale = Vector3.LerpUnclamped(a, b, t); }, done);
    }
    public static void FadeTo(GameObject g, float alpha, float dur, LuaFunction done)
    {
        if (!g) return;
        var cg = g.GetComponent<CanvasGroup>() ?? g.AddComponent<CanvasGroup>();
        float a = cg.alpha;
        runner.Add(g, dur, 0, t => { if (cg) cg.alpha = Mathf.Lerp(a, alpha, t); }, done);
    }
    public static void RotTo(GameObject g, float z, float dur, int ease)
    {
        if (!g) return;
        var tr = g.transform; float a = tr.localEulerAngles.z; if (a > 180) a -= 360;
        runner.Add(g, dur, ease, t => { if (tr) tr.localEulerAngles = new Vector3(0, 0, Mathf.LerpUnclamped(a, z, t)); }, null);
    }
    public static void Punch(GameObject g, float amount, float dur)
    {
        if (!g) return;
        var tr = g.transform; var b = tr.localScale; if (b.y == 0) return;
        float sx = Mathf.Sign(b.x);
        runner.Add(g, dur, 0, t =>
        {
            if (!tr) return;
            float k = 1 + amount * Mathf.Sin(t * Mathf.PI);
            tr.localScale = new Vector3(Mathf.Abs(b.x) * k * sx, b.y * k, 1);
            if (t >= 1) tr.localScale = b;
        }, null);
    }
    public static void Shake(GameObject g, float force, float dur)
    {
        if (!g) return;
        var rt = (RectTransform)g.transform; var b = rt.anchoredPosition;
        runner.Add(g, dur, 0, t =>
        {
            if (!rt) return;
            float f = force * (1 - t);
            rt.anchoredPosition = t >= 1 ? b : b + new Vector2(UnityEngine.Random.Range(-f, f), UnityEngine.Random.Range(-f, f));
        }, null);
    }
    public static void After(float s, LuaFunction fn)
    {
        runner.Add(null, s, 0, null, fn);
    }

    // movimentos contínuos (balanço, respiração, giro)
    public static void Bob(GameObject g, float amp, float period) { var l = GetLoop(g); if (l) { l.bobAmp = amp; l.bobPeriod = period; } }
    public static void Breath(GameObject g, float amp, float period) { var l = GetLoop(g); if (l) { l.breathAmp = amp; l.breathPeriod = period; } }
    public static void Spin(GameObject g, float degPerSec) { var l = GetLoop(g); if (l) l.spin = degPerSec; }
    public static void Sway(GameObject g, float deg, float period) { var l = GetLoop(g); if (l) { l.swayDeg = deg; l.swayPeriod = period; } }
    public static void StopLoop(GameObject g) { if (g) { var l = g.GetComponent<Loop>(); if (l) UnityEngine.Object.Destroy(l); } }
    static Loop GetLoop(GameObject g)
    {
        if (!g) return null;
        var l = g.GetComponent<Loop>();
        if (!l) { l = g.AddComponent<Loop>(); l.basePos = ((RectTransform)g.transform).anchoredPosition; l.baseScale = g.transform.localScale; l.phase = UnityEngine.Random.value * 10f; }
        return l;
    }

    // ------------------------------------------------------------------ efeitos
    public static void Burst(GameObject p, float x, float y, int n, string color, float speed, float size, float life, float gravity)
    {
        var c = Hex(color);
        for (int i = 0; i < n; i++)
        {
            var g = Img(p, "particula", x, y, size, size, color, 0.5f, 0.5f);
            float ang = UnityEngine.Random.value * Mathf.PI * 2, sp = speed * (0.35f + UnityEngine.Random.value * 0.75f);
            var v = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang)) * sp;
            var rt = (RectTransform)g.transform; var img = g.GetComponent<Image>();
            float lf = life * (0.6f + UnityEngine.Random.value * 0.6f);
            runner.Add(g, lf, 0, t =>
            {
                if (!rt) return;
                rt.anchoredPosition += v * Dt();
                v.y -= gravity * Dt();
                img.color = new Color(c.r, c.g, c.b, c.a * (1 - t));
                rt.localScale = Vector3.one * (1 - t * 0.6f);
                if (t >= 1) UnityEngine.Object.Destroy(g);
            }, null);
        }
    }

    public static void Ring(GameObject p, float x, float y, string color, float size, float dur)
    {
        var g = Img(p, "brilho", x, y, size, size, color, 0.5f, 0.5f);
        var img = g.GetComponent<Image>(); var c = img.color; var tr = g.transform;
        tr.localScale = Vector3.one * 0.2f;
        runner.Add(g, dur, 1, t =>
        {
            if (!tr) return;
            tr.localScale = Vector3.one * (0.2f + 1.6f * t);
            img.color = new Color(c.r, c.g, c.b, c.a * (1 - t));
            if (t >= 1) UnityEngine.Object.Destroy(g);
        }, null);
    }

    public static void Flash(string color, float dur)
    {
        var g = Fill(Layer("flash"), "", color, 0);
        var img = g.GetComponent<Image>(); var c = img.color;
        runner.Add(g, dur, 0, t =>
        {
            if (!img) return;
            img.color = new Color(c.r, c.g, c.b, c.a * (1 - t));
            if (t >= 1) UnityEngine.Object.Destroy(g);
        }, null);
    }

    // texto flutuante (dano, cura): sobe, cresce e some
    public static void Float(GameObject p, string text, int size, float x, float y, string color)
    {
        var g = Txt(p, text, size, x, y, 420, 120, color, "C", true, 0.5f, 0.5f);
        var rt = (RectTransform)g.transform; var tx = g.GetComponent<Text>(); var c = tx.color;
        float dx = UnityEngine.Random.Range(-30f, 30f);
        runner.Add(g, 0.95f, 0, t =>
        {
            if (!rt) return;
            rt.anchoredPosition = new Vector2(x + dx * t, y + 110 * (1 - (1 - t) * (1 - t)));
            float s = t < 0.15f ? Mathf.Lerp(0.6f, 1.25f, t / 0.15f) : Mathf.Lerp(1.25f, 1f, (t - 0.15f) / 0.85f);
            rt.localScale = Vector3.one * s;
            tx.color = new Color(c.r, c.g, c.b, t > 0.6f ? 1 - (t - 0.6f) / 0.4f : 1);
            if (t >= 1) UnityEngine.Object.Destroy(g);
        }, null);
    }

    // ------------------------------------------------------------------ física de apresentação
    // Só visual: a batalha continua decidida pelo motor determinístico em Lua. Coordenadas da UI (y para cima).
    static float pausaAte;
    static Material aditivo;

    // tempo de animação do quadro, parado durante a pausa de impacto (hit-stop)
    public static float Dt() => Time.unscaledTime < pausaAte ? 0f : Time.unscaledDeltaTime * Lento;

    // câmera lenta (1 = normal): usada pela vitrine de revisão para filmar golpes rápidos quadro a quadro.
    // Vale para o Lua (GameEntry multiplica o dt) e para tweens, corpos, bonecos e tentáculos.
    public static float Lento { get; private set; } = 1f;
    public static void CameraLenta(float f) { Lento = Mathf.Clamp(f, 0.05f, 1f); }

    // congela tweens, partículas e corpos por alguns centésimos: o golpe "pesa"
    public static void Pausa(float s) { pausaAte = Mathf.Max(pausaAte, Time.unscaledTime + s); }

    public static bool Existe(string sprite)
    {
        if (string.IsNullOrEmpty(sprite)) return false;
        if (!sprites.TryGetValue(sprite, out var s)) { s = Resources.Load<Sprite>("Sprites/" + sprite); sprites[sprite] = s; }
        return s != null;
    }

    // brilho somado à cena (criaturas de luz, faíscas): fica vivo sobre o mar escuro
    public static void Aditivo(GameObject g)
    {
        if (!g) return;
        if (!aditivo)
        {
            var sh = Resources.Load<Shader>("Shaders/UI_Fx_Aditivo");
            if (sh) aditivo = new Material(sh);
        }
        var gr = g.GetComponent<Graphic>();
        if (gr && aditivo) gr.material = aditivo;
    }

    // Lança um objeto com velocidade inicial; gravidade puxa para baixo; o chão (y) faz quicar.
    // vida > 0: some no fim (destruir) ou só desbota; vida <= 0: fica até parar.
    public static void Lancar(GameObject g, float vx, float vy, float grav, float chao, float quique, float arrasto, float giro, float vida, bool destruir, LuaFunction fim)
    {
        if (!g) return;
        var c = g.GetComponent<Corpo>() ?? g.AddComponent<Corpo>();
        c.Iniciar(new Vector2(vx, vy), grav, chao, quique, arrasto, giro, vida, destruir, fim);
    }

    public static void Parar(GameObject g)
    {
        if (!g) return;
        var c = g.GetComponent<Corpo>();
        if (c) UnityEngine.Object.Destroy(c);
    }

    // cancela os tweens em andamento de um objeto (ex.: o golpe novo interrompe a volta ao lugar)
    public static void Cancelar(GameObject g) { if (g) runner.Cancel(g); }

    // Jato de partículas com física: direção (graus), abertura do cone, velocidade, gravidade e chão.
    public static void Particulas(GameObject p, string sprite, float x, float y, int n, string cor, float vel, float ang, float abertura,
        float tam, float vida, float grav, float chao, bool aditivoOn)
    {
        for (int i = 0; i < n; i++)
        {
            float s = tam * (0.55f + UnityEngine.Random.value * 0.7f);
            var g = Img(p, sprite, x, y, s, s, cor, 0.5f, 0.5f);
            if (aditivoOn) Aditivo(g);
            float a = (ang + (UnityEngine.Random.value - 0.5f) * abertura) * Mathf.Deg2Rad;
            float sp = vel * (0.35f + UnityEngine.Random.value * 0.8f);
            g.transform.localEulerAngles = new Vector3(0, 0, UnityEngine.Random.value * 360f);
            Lancar(g, Mathf.Cos(a) * sp, Mathf.Sin(a) * sp, grav, chao, 0.35f, 1.2f, (UnityEngine.Random.value - 0.5f) * 720f,
                vida * (0.7f + UnityEngine.Random.value * 0.6f), true, null);
        }
    }

    // Projétil em arco de (x0,y0) até (x1,y1): parábola de altura 'arco', gira na direção do voo,
    // deixa rastro opcional (cor) e chama 'chegou' no impacto.
    public static GameObject Projetil(GameObject p, string sprite, float x0, float y0, float x1, float y1, float dur, float arco,
        float w, float h, string cor, bool orientar, bool aditivoOn, string rastro, LuaFunction chegou)
    {
        var g = Img(p, sprite, x0, y0, w, h, cor, 0.5f, 0.5f);
        if (aditivoOn) Aditivo(g);
        var rt = (RectTransform)g.transform;
        Vector2 a = new Vector2(x0, y0), b = new Vector2(x1, y1), ant = a;
        float acc = 0;
        runner.Add(g, dur, 0, t =>
        {
            if (!rt) return;
            var pos = Vector2.Lerp(a, b, t) + new Vector2(0, arco * 4f * t * (1 - t));
            rt.anchoredPosition = pos;
            var d = pos - ant;
            if (orientar && d.sqrMagnitude > 0.01f) rt.localEulerAngles = new Vector3(0, 0, Mathf.Atan2(d.y, d.x) * Mathf.Rad2Deg);
            ant = pos;
            acc += Dt();
            if (!string.IsNullOrEmpty(rastro) && acc > 0.02f)
            {
                acc = 0;
                var r = Img(p, "particula", pos.x, pos.y, w * 0.35f, w * 0.35f, rastro, 0.5f, 0.5f);
                Aditivo(r);
                FadeTo(r, 0, 0.3f, null);
                ScaleTo(r, 0.2f, 0.3f, 0, null);
                UnityEngine.Object.Destroy(r, 0.35f);
            }
            if (t >= 1) UnityEngine.Object.Destroy(g);
        }, chegou);
        return g;
    }

    // ------------------------------------------------------------------ boneco com esqueleto (Boneco2D) e tentáculos
    // Personagens com rig (Resources/Rigs/<arte>.json) viram malha deformável com física de molas.
    public static bool TemRig(string arte) => Boneco2D.Tem(arte);

    public static GameObject Boneco(GameObject p, string arte, float x, float y, float w, float h, float ax, float ay)
    {
        var rt = Make(p, "boneco_" + arte, x, y, w, h, ax, ay);
        var b = rt.gameObject.AddComponent<Boneco2D>();
        if (!b.Iniciar(arte)) Debug.LogWarning("[Boneco] sem rig: " + arte);
        return rt.gameObject;
    }

    // toca uma animação do rig (parado, correr, golpe, dano, especial, morto, vitoria...); devolve a duração
    public static float BonecoAnim(GameObject g, string anim, float vel)
    {
        var b = g ? g.GetComponent<Boneco2D>() : null;
        return b ? b.Tocar(anim, vel) : 0f;
    }

    // ponto ao longo de um osso (0 = junta, 1 = ponta) nas coordenadas de 'refg' (centro do objeto)
    public static void BonecoPonto(GameObject g, string osso, float t, GameObject refg, out float x, out float y)
    {
        x = 0; y = 0;
        var b = g ? g.GetComponent<Boneco2D>() : null;
        if (!b || !refg) return;
        Vector2 l = refg.transform.InverseTransformPoint(b.PontoMundo(osso, t));
        x = l.x; y = l.y;
    }

    public static void BonecoImpulso(GameObject g, string osso, float grausPorSeg)
    {
        var b = g ? g.GetComponent<Boneco2D>() : null;
        if (b) b.Impulso(osso, grausPorSeg);
    }

    // rastro do golpe entre dois pontos de um osso (t0 e t1 ao longo dele), desenhado na 'camada' por 'dur' segundos
    public static void BonecoRastro(GameObject g, string osso, float t0, float t1, GameObject camada, string cor, float dur)
    {
        var b = g ? g.GetComponent<Boneco2D>() : null;
        if (b && camada) RastroGolpe.Criar(camada, b, osso, t0, t1, Hex(cor), dur);
    }

    // 1 = músculos normais; perto de 0 = mole (morto): cai pelo próprio peso
    public static void BonecoFlacido(GameObject g, float f)
    {
        var b = g ? g.GetComponent<Boneco2D>() : null;
        if (b) b.Flacido(f);
    }

    public static GameObject Tentaculo(GameObject p, float x, float y, float esp, string cor, string brilho)
    {
        if (!p) return null;
        return global::Tentaculo.Criar(p, x, y, esp, Hex(cor), Hex(brilho)).gameObject;
    }

    static Tentaculo Tent(GameObject g) => g ? g.GetComponent<Tentaculo>() : null;

    // a raiz do tentáculo acompanha um osso do boneco (ex.: o antebraço com a Marca)
    public static void TentPreso(GameObject t, GameObject boneco, string osso, float pos)
    {
        var tc = Tent(t); var b = boneco ? boneco.GetComponent<Boneco2D>() : null;
        if (tc && b) tc.Preso(b, osso, pos);
    }

    // estica até o alvo (centro + dx, dy) em 'dur' segundos, num arco de chicote ('curva' px para o lado)
    public static void TentAlcancar(GameObject t, GameObject alvo, float dx, float dy, float dur, float curva)
    {
        var tc = Tent(t);
        if (tc && alvo) tc.Alcancar(alvo.transform, new Vector2(dx, dy), dur, curva);
    }

    // enrola a ponta numa espiral em volta do alvo (elipse raioX x raioY, subindo 'altura' em 'voltas' voltas)
    public static void TentEnrolar(GameObject t, GameObject alvo, float dy, float raioX, float raioY, float altura, float voltas, float fase)
    {
        var tc = Tent(t);
        if (tc && alvo) tc.Enrolar(alvo.transform, dy, raioX, raioY, altura, voltas, fase);
    }

    // aperta (fator < 1) ou afrouxa a espiral em 'dur' segundos
    public static void TentApertar(GameObject t, float fator, float dur) { var tc = Tent(t); if (tc) tc.Apertar(fator, dur); }

    // solta o alvo e recolhe até a raiz; o objeto some sozinho no fim
    public static void TentSoltar(GameObject t, float dur) { var tc = Tent(t); if (tc) tc.Soltar(dur); }

    // ------------------------------------------------------------------ áudio, dados, sistema
    public static void Som(string n) => Sfx.Play(n);
    public static void Ambiente(string n) => Sfx.Ambient(n);
    public static void SomLigado(bool on) => Sfx.SetOn(on);
    public static string Load(string k) => PlayerPrefs.GetString(k, "");
    public static void Save(string k, string v) { PlayerPrefs.SetString(k, v); PlayerPrefs.Save(); }
    public static double Now() => (DateTime.UtcNow - new DateTime(1970, 1, 1)).TotalSeconds;
    public static void Vibrate()
    {
#if UNITY_ANDROID || UNITY_IOS
        Handheld.Vibrate();
#endif
    }
    public static void Quit() => Application.Quit();
    public static void Log(string s) => Debug.Log("[Lua] " + s);
    // argumento de linha de comando: valor seguinte, "1" se vier sozinho, "" se não existir
    public static string Arg(string name)
    {
        var a = Environment.GetCommandLineArgs();
        for (int i = 0; i < a.Length; i++)
            if (a[i] == name) return (i + 1 < a.Length && !a[i + 1].StartsWith("-")) ? a[i + 1] : "1";
        return "";
    }
    // captura da tela (usada pelo modo de teste automático e para gerar imagens de divulgação)
    public static void Shot(string path) => ScreenCapture.CaptureScreenshot(path);

    // ------------------------------------------------------------------ utilidades internas
    public static Color Hex(string c)
    {
        if (string.IsNullOrEmpty(c)) return Color.white;
        if (ColorUtility.TryParseHtmlString(c, out var col)) return col;
        return Color.white;
    }

    static TextAnchor Align(string a)
    {
        switch (a)
        {
            case "L": return TextAnchor.MiddleLeft;
            case "R": return TextAnchor.MiddleRight;
            case "TL": return TextAnchor.UpperLeft;
            case "T": return TextAnchor.UpperCenter;
            case "TR": return TextAnchor.UpperRight;
            case "BL": return TextAnchor.LowerLeft;
            case "B": return TextAnchor.LowerCenter;
            default: return TextAnchor.MiddleCenter;
        }
    }

    static void ApplySprite(Image img, string name)
    {
        if (string.IsNullOrEmpty(name)) { img.sprite = Skins.White(); img.type = Image.Type.Simple; return; }
        if (name.StartsWith("skin:"))
        {
            img.sprite = Skins.Get(name.Substring(5));
            img.type = Image.Type.Sliced;
            img.pixelsPerUnitMultiplier = 1f;
            return;
        }
        if (!sprites.TryGetValue(name, out var s))
        {
            s = Resources.Load<Sprite>("Sprites/" + name);
            sprites[name] = s;
        }
        img.sprite = s;
        img.type = Image.Type.Simple;
        img.preserveAspect = true;
    }

    // ------------------------------------------------------------------ componentes auxiliares
    public class LuaCallback : MonoBehaviour
    {
        LuaFunction fn;
        public void Set(LuaFunction f) { fn?.Dispose(); fn = f; }
        public void Invoke()
        {
            if (fn == null) return;
            try { fn.Call(); } catch (Exception e) { Debug.LogError("[Lua] clique: " + e.Message); }
        }
        void OnDestroy() { if (LuaManager.Ready) fn?.Dispose(); fn = null; }
    }

    public class PressScale : MonoBehaviour, IPointerDownHandler, IPointerUpHandler
    {
        Vector3 b;
        public void OnPointerDown(PointerEventData e) { b = transform.localScale; transform.localScale = b * 0.94f; }
        public void OnPointerUp(PointerEventData e) { if (b != Vector3.zero) transform.localScale = b; }
    }

    // Corpo com física simples: gravidade, arrasto do ar, giro e chão com quique e atrito.
    public class Corpo : MonoBehaviour
    {
        Vector2 v; float g, chao, quique, arrasto, giro, vida, t; bool destruir, parado;
        LuaFunction fim; RectTransform rt; CanvasGroup cg;

        public void Iniciar(Vector2 vel, float grav, float ch, float q, float arr, float gi, float vi, bool des, LuaFunction f)
        {
            rt = (RectTransform)transform;
            v = vel; g = grav; chao = ch; quique = q; arrasto = arr; giro = gi; vida = vi; destruir = des; t = 0; parado = false;
            fim?.Dispose(); fim = f;
            if (vida > 0 && !cg) cg = GetComponent<CanvasGroup>() ?? gameObject.AddComponent<CanvasGroup>();
            if (cg) cg.alpha = 1;
        }

        void Update()
        {
            float dt = Dt();
            if (dt <= 0 || !rt) return;
            t += dt;
            if (!parado)
            {
                v.y -= g * dt;
                v *= Mathf.Exp(-arrasto * dt);
                var p = rt.anchoredPosition + v * dt;
                if (p.y < chao)
                {
                    p.y = chao;
                    if (v.y < -90f && quique > 0) { v.y = -v.y * quique; v.x *= 0.75f; giro *= 0.6f; }
                    else { v.y = 0; v.x *= Mathf.Exp(-10f * dt); giro *= Mathf.Exp(-10f * dt); if (Mathf.Abs(v.x) < 6f) parado = true; }
                }
                rt.anchoredPosition = p;
                if (giro != 0) rt.Rotate(0, 0, giro * dt);
            }
            if (vida > 0)
            {
                float k = t / vida;
                if (cg && k > 0.6f) cg.alpha = Mathf.Clamp01(1 - (k - 0.6f) / 0.4f);
                if (t >= vida) Terminar();
            }
            else if (parado && fim != null) Terminar();
        }

        void Terminar()
        {
            var f = fim; fim = null;
            if (f != null) { try { f.Call(); } catch (Exception e) { Debug.LogError("[Lua] corpo: " + e.Message); } f.Dispose(); }
            if (destruir) Destroy(gameObject); else Destroy(this);
        }

        void OnDestroy() { if (LuaManager.Ready) fim?.Dispose(); fim = null; }
    }

    public class Loop : MonoBehaviour
    {
        public Vector2 basePos; public Vector3 baseScale = Vector3.one; public float phase;
        public float bobAmp, bobPeriod = 1, breathAmp, breathPeriod = 1, spin, swayDeg, swayPeriod = 1;
        RectTransform rt;
        void Awake() { rt = (RectTransform)transform; }
        void Update()
        {
            float t = Time.unscaledTime + phase;
            if (bobAmp != 0) rt.anchoredPosition = basePos + new Vector2(0, bobAmp * Mathf.Sin(t * Mathf.PI * 2 / bobPeriod));
            if (breathAmp != 0)
            {
                float k = 1 + breathAmp * Mathf.Sin(t * Mathf.PI * 2 / breathPeriod);
                transform.localScale = new Vector3(baseScale.x * (2 - k), baseScale.y * k, 1);
            }
            if (spin != 0) transform.Rotate(0, 0, spin * Time.unscaledDeltaTime);
            else if (swayDeg != 0) transform.localEulerAngles = new Vector3(0, 0, swayDeg * Mathf.Sin(t * Mathf.PI * 2 / swayPeriod));
        }
    }

    class Tw
    {
        public GameObject g; public bool hasTarget, morto; public float dur, t; public int ease; public Action<float> step; public LuaFunction done;
    }

    public class Runner : MonoBehaviour
    {
        readonly List<Tw> list = new List<Tw>();
        readonly List<Tw> add = new List<Tw>();

        public void Add(GameObject g, float dur, int ease, Action<float> step, LuaFunction done)
        {
            add.Add(new Tw { g = g, hasTarget = g != null, dur = Mathf.Max(0.0001f, dur), ease = ease, step = step, done = done });
        }

        // marca para remoção (seguro mesmo de dentro de um callback durante o Update)
        public void Cancel(GameObject g)
        {
            foreach (var w in list) if (w.hasTarget && w.g == g) w.morto = true;
            foreach (var w in add) if (w.hasTarget && w.g == g) w.morto = true;
        }

        static float Ease(int e, float t)
        {
            switch (e)
            {
                case 1: return 1 - (1 - t) * (1 - t);
                case 2: return t * t;
                case 3: { const float c1 = 1.70158f, c3 = c1 + 1; return 1 + c3 * Mathf.Pow(t - 1, 3) + c1 * Mathf.Pow(t - 1, 2); }
                case 4: return -(Mathf.Cos(Mathf.PI * t) - 1) / 2;
                default: return t;
            }
        }

        int telaW, telaH; float redimT = -1;

        void Update()
        {
            AplicarAreaSegura();
            // janela mudou de tamanho (navegador, celular girado na versão web): avisa o Lua depois que estabiliza
            if (Screen.width != telaW || Screen.height != telaH)
            {
                if (telaW > 0) redimT = 0.35f;
                telaW = Screen.width; telaH = Screen.height;
            }
            if (redimT > 0 && (redimT -= Time.unscaledDeltaTime) <= 0) LuaManager.Call("Game_Resize");
            if (add.Count > 0) { list.AddRange(add); add.Clear(); }
            float dt = Dt();
            if (dt <= 0) return;  // pausa de impacto
            for (int i = list.Count - 1; i >= 0; i--)
            {
                var w = list[i];
                if (w.morto || (w.hasTarget && !w.g)) { w.done?.Dispose(); list.RemoveAt(i); continue; }
                w.t += dt;
                float k = Mathf.Clamp01(w.t / w.dur);
                try { w.step?.Invoke(k >= 1 ? 1 : Ease(w.ease, k)); } catch (Exception e) { Debug.LogError(e.Message); }
                if (k >= 1)
                {
                    list.RemoveAt(i);
                    if (w.done != null)
                    {
                        try { w.done.Call(); } catch (Exception e) { Debug.LogError("[Lua] tween: " + e.Message); }
                        w.done.Dispose();
                    }
                }
            }
        }
    }
}
