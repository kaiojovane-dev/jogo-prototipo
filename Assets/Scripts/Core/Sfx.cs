using System.Collections.Generic;
using UnityEngine;

// Efeitos sonoros sintetizados na inicialização (sem arquivos de áudio) e trilha ambiente procedural.
public static class Sfx
{
    static readonly Dictionary<string, AudioClip> clips = new Dictionary<string, AudioClip>();
    static AudioSource[] pool;
    static AudioSource music;
    static int next;
    public static bool On = true;
    const int SR = 44100;

    public static void Init(GameObject host)
    {
        pool = new AudioSource[10];
        for (int i = 0; i < pool.Length; i++) { pool[i] = host.AddComponent<AudioSource>(); pool[i].playOnAwake = false; }
        music = host.AddComponent<AudioSource>();
        music.loop = true; music.volume = 0.35f; music.playOnAwake = false;

        clips["toque"] = Tone(0.06f, t => Wave(2, 660, t), 0.25f);
        clips["golpe"] = Tone(0.10f, t => Noise() * 0.7f + Wave(1, 160 - 600 * t, t) * 0.4f, 0.35f);
        clips["critico"] = Tone(0.18f, t => Noise() * 0.6f + Wave(3, 340 - 900 * t, t) * 0.5f, 0.45f);
        clips["especial"] = Tone(0.55f, t => Wave(3, 220 + 900 * t, t) * 0.4f + Noise() * (t > 0.2f ? 0.5f : 0.1f), 0.4f);
        clips["cura"] = Tone(0.45f, t => Wave(0, 520 + 300 * t, t) * 0.5f + Wave(0, 780 + 200 * t, t) * 0.3f, 0.35f);
        clips["moeda"] = Tone(0.22f, t => Wave(1, t < 0.07f ? 988 : 1319, t), 0.22f);
        clips["nivel"] = Tone(0.3f, t => Wave(2, 440 + 880 * t, t), 0.3f);
        clips["vitoria"] = Arp(new float[] { 523, 659, 784, 1047, 1319 }, 0.12f, 2);
        clips["derrota"] = Arp(new float[] { 392, 330, 262, 196 }, 0.2f, 2);
        clips["ssr"] = Arp(new float[] { 523, 659, 784, 1047, 1319, 1568 }, 0.09f, 0);
        clips["abrir"] = Tone(0.18f, t => Wave(0, 300 + 500 * t, t), 0.25f);
        clips["mar"] = Ocean();
    }

    static float Noise() => Random.value * 2f - 1f;

    static float Wave(int type, float f, float t)
    {
        float ph = (f * t) % 1f;
        switch (type)
        {
            case 1: return ph < 0.5f ? 1f : -1f;                 // quadrada
            case 2: return 1f - 4f * Mathf.Abs(ph - 0.5f);         // triangular
            case 3: return ph * 2f - 1f;                          // dente de serra
            default: return Mathf.Sin(ph * Mathf.PI * 2f);        // seno
        }
    }

    static AudioClip Tone(float dur, System.Func<float, float> fn, float vol)
    {
        int n = (int)(SR * dur);
        var d = new float[n];
        for (int i = 0; i < n; i++)
        {
            float t = (float)i / SR;
            float env = Mathf.Min(1f, t * 200f) * Mathf.Pow(1f - (float)i / n, 1.6f);
            d[i] = Mathf.Clamp(fn(t) * env * vol, -1f, 1f);
        }
        var c = AudioClip.Create("sfx", n, 1, SR, false);
        c.SetData(d, 0);
        return c;
    }

    static AudioClip Arp(float[] notes, float step, int type)
    {
        float dur = step * notes.Length + 0.35f;
        int n = (int)(SR * dur);
        var d = new float[n];
        for (int k = 0; k < notes.Length; k++)
        {
            int start = (int)(k * step * SR), len = (int)(0.35f * SR);
            for (int i = 0; i < len && start + i < n; i++)
            {
                float t = (float)i / SR;
                d[start + i] += Wave(type, notes[k], t) * 0.22f * Mathf.Pow(1f - (float)i / len, 1.4f) * Mathf.Min(1f, t * 300f);
            }
        }
        var c = AudioClip.Create("arp", n, 1, SR, false);
        c.SetData(d, 0);
        return c;
    }

    // ondas do mar: ruído filtrado com volume ondulando (loop de 8 s)
    static AudioClip Ocean()
    {
        int n = SR * 8;
        var d = new float[n];
        float lp = 0;
        for (int i = 0; i < n; i++)
        {
            float t = (float)i / SR;
            lp += (Noise() - lp) * 0.02f;
            float swell = 0.5f + 0.5f * Mathf.Sin(t / 8f * Mathf.PI * 2f * 2f);
            d[i] = lp * (0.25f + 0.75f * swell) * 0.9f;
        }
        var c = AudioClip.Create("mar", n, 1, SR, false);
        c.SetData(d, 0);
        return c;
    }

    public static void Play(string name)
    {
        if (!On || !clips.TryGetValue(name, out var c)) return;
        var s = pool[next]; next = (next + 1) % pool.Length;
        s.pitch = name == "golpe" ? Random.Range(0.9f, 1.1f) : 1f;
        s.PlayOneShot(c);
    }

    public static void Ambient(string name)
    {
        if (!clips.TryGetValue(name, out var c)) { music.Stop(); return; }
        if (music.clip == c && music.isPlaying) return;
        music.clip = c;
        if (On) music.Play();
    }

    public static void SetOn(bool on)
    {
        On = on;
        if (!on) music.Pause(); else if (music.clip) music.Play();
    }
}
