using System;
using System.Collections.Generic;
using System.Text;
using UnityEngine;
using XLua;

// Sobe o xLua e carrega os scripts do pacote cifrado Resources/LuaPack (gerado pelo BuildTool).
// Mais tarde o mesmo pacote poderá vir da CDN (atualização sem passar pela loja).
public static class LuaManager
{
    static LuaEnv env;
    static readonly Dictionary<string, byte[]> files = new Dictionary<string, byte[]>();
    static LuaFunction updateFn;
    static float gcTimer;
    public static bool Ready { get; private set; }

    public static void Init()
    {
        LoadPack();
        env = new LuaEnv();
        env.AddLoader(Loader);
        try
        {
            env.DoString("require('main')", "boot");
            updateFn = env.Global.Get<LuaFunction>("Game_Update");
            Ready = true;
        }
        catch (Exception e)
        {
            Debug.LogError("[Lua] falha ao iniciar: " + e);
        }
    }

    static void LoadPack()
    {
        files.Clear();
        var ta = Resources.Load<TextAsset>("LuaPack");
        if (ta == null) { Debug.LogError("[Lua] LuaPack não encontrado"); return; }
        var b = ta.bytes;
        int p = 0;
        if (Encoding.ASCII.GetString(b, 0, 4) != "MLPK") { Debug.LogError("[Lua] pacote inválido"); return; }
        p = 4;
        int count = BitConverter.ToInt32(b, p); p += 4;
        for (int i = 0; i < count; i++)
        {
            int nl = BitConverter.ToInt32(b, p); p += 4;
            string name = Encoding.UTF8.GetString(b, p, nl); p += nl;
            int dl = BitConverter.ToInt32(b, p); p += 4;
            var data = new byte[dl];
            Buffer.BlockCopy(b, p, data, 0, dl); p += dl;
            Cipher(data);
            files[name] = data;
        }
    }

    // Cifra de fluxo simples (a mesma do empacotador). Dificulta a leitura direta dos scripts.
    public static void Cipher(byte[] data)
    {
        uint key = 0x5EED1234u;
        for (int i = 0; i < data.Length; i++)
        {
            data[i] ^= (byte)(key >> 24);
            key = key * 1103515245u + 12345u;
        }
    }

    static byte[] Loader(ref string filepath)
    {
        string key = filepath.Replace('/', '.');
        if (files.TryGetValue(key, out var data))
        {
            filepath = key.Replace('.', '/') + ".lua";
            return data;
        }
        return null;
    }

    public static void Update(float dt)
    {
        if (!Ready) return;
        try { updateFn?.Call(dt); }
        catch (Exception e) { Debug.LogError("[Lua] " + e.Message); }
        gcTimer += dt;
        if (gcTimer > 1f) { gcTimer = 0; env.Tick(); }
    }

    public static void Call(string fn, params object[] args)
    {
        if (env == null) return;
        try
        {
            var f = env.Global.Get<LuaFunction>(fn);
            if (f != null) { f.Call(args); f.Dispose(); }
        }
        catch (Exception e) { Debug.LogError("[Lua] " + fn + ": " + e.Message); }
    }

    public static void Dispose()
    {
        Ready = false;
        updateFn?.Dispose();
        updateFn = null;
        try { env?.Dispose(); } catch (Exception) { /* callbacks ainda vivos no encerramento */ }
        env = null;
    }
}
