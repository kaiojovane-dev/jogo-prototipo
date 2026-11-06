using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using UnityEditor;
using UnityEditor.Android;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine;

// Build em linha de comando:
// Unity.exe -batchmode -quit -projectPath . -buildTarget Android -executeMethod BuildTool.BuildApk -logFile Builds/build.log
public static class BuildTool
{
    const string SCENE = "Assets/Scenes/Main.unity";
    // O projeto Unity fica na raiz do repositório (Assets/ ao lado de client/, shared/, tools/)
    static string RepoRoot => Path.GetFullPath(Path.Combine(Application.dataPath, ".."));

    [MenuItem("Mare/Empacotar Lua")]
    public static void PackLua()
    {
        var roots = new[] { Path.Combine(RepoRoot, "shared", "lua"), Path.Combine(RepoRoot, "client", "lua") };
        var entries = new List<KeyValuePair<string, byte[]>>();
        foreach (var r in roots)
        {
            if (!Directory.Exists(r)) continue;
            foreach (var f in Directory.GetFiles(r, "*.lua", SearchOption.AllDirectories))
            {
                string rel = f.Substring(r.Length + 1).Replace('\\', '/');
                string name = rel.Substring(0, rel.Length - 4).Replace('/', '.');
                var data = File.ReadAllBytes(f);
                LuaManager.Cipher(data);
                entries.Add(new KeyValuePair<string, byte[]>(name, data));
            }
        }
        var ms = new MemoryStream();
        var w = new BinaryWriter(ms);
        w.Write(Encoding.ASCII.GetBytes("MLPK"));
        w.Write(entries.Count);
        foreach (var e in entries)
        {
            var nb = Encoding.UTF8.GetBytes(e.Key);
            w.Write(nb.Length); w.Write(nb);
            w.Write(e.Value.Length); w.Write(e.Value);
        }
        Directory.CreateDirectory(Path.Combine(Application.dataPath, "Resources"));
        File.WriteAllBytes(Path.Combine(Application.dataPath, "Resources", "LuaPack.bytes"), ms.ToArray());
        AssetDatabase.ImportAsset("Assets/Resources/LuaPack.bytes", ImportAssetOptions.ForceUpdate);
        Debug.Log("[Build] Lua empacotado: " + entries.Count + " arquivos");
    }

    static void ConfigurePlayer()
    {
        PlayerSettings.companyName = "SnyX Studio";
        PlayerSettings.productName = "Fim do Mapa";
        PlayerSettings.bundleVersion = "0.1.0";
        PlayerSettings.Android.bundleVersionCode = 1;
        var android = NamedBuildTarget.Android;
        PlayerSettings.SetApplicationIdentifier(android, "com.snyxstudio.fimdomapa");
        PlayerSettings.SetScriptingBackend(android, ScriptingImplementation.IL2CPP);
        PlayerSettings.SetManagedStrippingLevel(android, ManagedStrippingLevel.Minimal);
        // Unity 6.6 só gera ARM64 no Android (x86_64 foi removido)
        PlayerSettings.Android.targetArchitectures = AndroidArchitecture.ARM64;
        PlayerSettings.Android.targetSdkVersion = AndroidSdkVersions.AndroidApiLevelAuto;
        PlayerSettings.defaultInterfaceOrientation = UIOrientation.AutoRotation;
        PlayerSettings.allowedAutorotateToLandscapeLeft = true;
        PlayerSettings.allowedAutorotateToLandscapeRight = true;
        PlayerSettings.allowedAutorotateToPortrait = false;
        PlayerSettings.allowedAutorotateToPortraitUpsideDown = false;
        // obsoleta no Unity 6.6, mas ainda é a forma suportada de esconder as barras do sistema neste pin;
        // trocar por requestedVisibleInsets quando o projeto migrar para o 6.7 LTS
#pragma warning disable CS0618
        PlayerSettings.Android.startInFullscreen = true;
#pragma warning restore CS0618
        // o cenário ocupa a tela toda (inclusive ao lado do notch); botões e textos ficam na área segura (UIKit)
        PlayerSettings.Android.renderOutsideSafeArea = true;
        PlayerSettings.SplashScreen.backgroundColor = new Color32(7, 19, 39, 255);
        PlayerSettings.Android.applicationEntry = AndroidApplicationEntry.Activity;
        EditorUserBuildSettings.buildAppBundle = false;
    }

    static void ConfigureAndroidTools()
    {
        string baseDir = Environment.GetEnvironmentVariable("MARE_ANDROID_TOOLS");
        if (string.IsNullOrEmpty(baseDir)) baseDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "AndroidRE");
        string sdk = Path.Combine(baseDir, "sdk");
        string ndkDir = Path.Combine(sdk, "ndk");
        string ndk = Directory.Exists(ndkDir) ? Directory.GetDirectories(ndkDir).OrderBy(d => d).LastOrDefault() : null;
        AndroidExternalToolsSettings.jdkRootPath = Path.Combine(baseDir, "jdk17");
        AndroidExternalToolsSettings.sdkRootPath = sdk;
        if (ndk != null) AndroidExternalToolsSettings.ndkRootPath = ndk;
        Debug.Log("[Build] JDK/SDK/NDK: " + AndroidExternalToolsSettings.jdkRootPath + " | " + sdk + " | " + ndk);
    }

    // Bibliotecas nativas do xLua: cada pasta de ABI só entra no build da arquitetura certa.
    static void EnsurePlugins()
    {
        var abis = new Dictionary<string, string> { { "arm64-v8a", "ARM64" }, { "armeabi-v7a", "ARMv7" } };
        foreach (var kv in abis)
        {
            string path = "Assets/Plugins/Android/libs/" + kv.Key + "/libxlua.so";
            if (!File.Exists(Path.Combine(Application.dataPath, "..", path))) continue;
            AssetDatabase.ImportAsset(path);
            var imp = AssetImporter.GetAtPath(path) as PluginImporter;
            if (imp == null) continue;
            imp.SetCompatibleWithAnyPlatform(false);
            imp.SetCompatibleWithEditor(false);
            imp.SetCompatibleWithPlatform(BuildTarget.Android, true);
            imp.SetPlatformData(BuildTarget.Android, "CPU", kv.Value);
            imp.SaveAndReimport();
        }
        // xLua para a web: código C do Lua 5.4.1 + xLua compilado junto com o jogo (o navegador não carrega .so/.dll).
        // Só pode valer para WebGL: no Android ele duplicaria a libxlua.so.
        foreach (var guid in AssetDatabase.FindAssets("", new[] { "Assets/Plugins/WebGL" }))
        {
            string p = AssetDatabase.GUIDToAssetPath(guid);
            if (!(AssetImporter.GetAtPath(p) is PluginImporter c)) continue;
            if (c.GetCompatibleWithPlatform(BuildTarget.WebGL) && !c.GetCompatibleWithAnyPlatform() && !c.GetCompatibleWithEditor()) continue;
            c.SetCompatibleWithAnyPlatform(false);
            c.SetCompatibleWithEditor(false);
            foreach (BuildTarget t in new[] { BuildTarget.Android, BuildTarget.StandaloneWindows64, BuildTarget.iOS })
                c.SetCompatibleWithPlatform(t, false);
            c.SetCompatibleWithPlatform(BuildTarget.WebGL, true);
            c.SaveAndReimport();
        }
        // xLua para Windows (editor e build de teste)
        const string win = "Assets/Plugins/x86_64/xlua.dll";
        if (File.Exists(Path.Combine(Application.dataPath, "..", win)))
        {
            var w = AssetImporter.GetAtPath(win) as PluginImporter;
            if (w != null)
            {
                w.SetCompatibleWithAnyPlatform(false);
                w.SetCompatibleWithEditor(true);
                w.SetEditorData("CPU", "x86_64");
                w.SetEditorData("OS", "Windows");
                w.SetCompatibleWithPlatform(BuildTarget.StandaloneWindows64, true);
                w.SaveAndReimport();
            }
        }
    }

    static void EnsureScene()
    {
        if (!File.Exists(Path.Combine(Application.dataPath, "Scenes", "Main.unity")))
        {
            Directory.CreateDirectory(Path.Combine(Application.dataPath, "Scenes"));
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            EditorSceneManager.SaveScene(scene, SCENE);
        }
        EditorBuildSettings.scenes = new[] { new EditorBuildSettingsScene(SCENE, true) };
    }

    // Build de teste para Windows (mesmo Lua, C# e arte). Rodar com:  FimDoMapa.exe -autotest <pasta>  para gerar capturas de todas as telas.
    [MenuItem("Mare/Gerar Windows (teste)")]
    public static void BuildWindows()
    {
        int code = 0;
        try
        {
            PackLua();
            ConfigurePlayer();
            EnsurePlugins();
            EnsureScene();
            PlayerSettings.SetScriptingBackend(NamedBuildTarget.Standalone, ScriptingImplementation.Mono2x);
            PlayerSettings.fullScreenMode = FullScreenMode.Windowed;
            PlayerSettings.defaultScreenWidth = 1600;
            PlayerSettings.defaultScreenHeight = 720;
            PlayerSettings.resizableWindow = true;
            PlayerSettings.runInBackground = true;
            AssetDatabase.SaveAssets();
            string outDir = Path.Combine(RepoRoot, "Builds", "Windows");
            Directory.CreateDirectory(outDir);
            var report = BuildPipeline.BuildPlayer(new BuildPlayerOptions
            {
                scenes = new[] { SCENE },
                locationPathName = Path.Combine(outDir, "FimDoMapa.exe"),
                target = BuildTarget.StandaloneWindows64,
                targetGroup = BuildTargetGroup.Standalone,
                options = BuildOptions.None,
            });
            Debug.Log("[Build] Windows: " + report.summary.result + " | erros: " + report.summary.totalErrors);
            if (report.summary.result != BuildResult.Succeeded) code = 1;
        }
        catch (Exception e)
        {
            Debug.LogError("[Build] falhou: " + e);
            code = 1;
        }
        if (Application.isBatchMode) EditorApplication.Exit(code);
    }

    // Versão web (iPhone, iPad e qualquer navegador): sai em Builds/Web, pronta para o GitHub Pages.
    // Texturas em ASTC (aceitas pelos iPhones e Androids atuais) e arquivos em gzip com descompressão no navegador,
    // porque o GitHub Pages não envia o cabeçalho Content-Encoding dos arquivos já comprimidos.
    [MenuItem("Mare/Gerar Web (iPhone)")]
    public static void BuildWebGL()
    {
        int code = 0;
        try
        {
            PackLua();
            ConfigurePlayer();
            EnsurePlugins();
            EnsureScene();
            var web = NamedBuildTarget.WebGL;
            PlayerSettings.SetManagedStrippingLevel(web, ManagedStrippingLevel.Minimal);
            PlayerSettings.WebGL.template = "PROJECT:FimDoMapa";
            PlayerSettings.WebGL.compressionFormat = WebGLCompressionFormat.Gzip;
            PlayerSettings.WebGL.decompressionFallback = true;
            PlayerSettings.WebGL.dataCaching = true;
            PlayerSettings.WebGL.exceptionSupport = WebGLExceptionSupport.ExplicitlyThrownExceptionsOnly;
            PlayerSettings.WebGL.nameFilesAsHashes = false;
            PlayerSettings.runInBackground = false;
            EditorUserBuildSettings.webGLBuildSubtarget = WebGLTextureSubtarget.ASTC;
            AssetDatabase.SaveAssets();
            string outDir = Path.Combine(RepoRoot, "Builds", "Web");
            var report = BuildPipeline.BuildPlayer(new BuildPlayerOptions
            {
                scenes = new[] { SCENE },
                locationPathName = outDir,
                target = BuildTarget.WebGL,
                targetGroup = BuildTargetGroup.WebGL,
                options = BuildOptions.None,
            });
            var s = report.summary;
            Debug.Log("[Build] Web: " + s.result + " | erros: " + s.totalErrors + " | tamanho: " + (s.totalSize / 1048576f).ToString("0.0") + " MB");
            if (s.result != BuildResult.Succeeded) code = 1;
        }
        catch (Exception e)
        {
            Debug.LogError("[Build] falhou: " + e);
            code = 1;
        }
        if (Application.isBatchMode) EditorApplication.Exit(code);
    }

    [MenuItem("Mare/Gerar APK")]
    public static void BuildApk()
    {
        int code = 0;
        try
        {
            PackLua();
            ConfigurePlayer();
            ConfigureAndroidTools();
            EnsurePlugins();
            EnsureScene();
            AssetDatabase.SaveAssets();
            string outDir = Path.Combine(RepoRoot, "Builds");
            Directory.CreateDirectory(outDir);
            var opts = new BuildPlayerOptions
            {
                scenes = new[] { SCENE },
                locationPathName = Path.Combine(outDir, "FimDoMapa.apk"),
                target = BuildTarget.Android,
                targetGroup = BuildTargetGroup.Android,
                options = BuildOptions.None,
            };
            var report = BuildPipeline.BuildPlayer(opts);
            var s = report.summary;
            Debug.Log("[Build] resultado: " + s.result + " | erros: " + s.totalErrors + " | tamanho: " + (s.totalSize / 1048576f).ToString("0.0") + " MB | tempo: " + s.totalTime);
            if (s.result != BuildResult.Succeeded) code = 1;
        }
        catch (Exception e)
        {
            Debug.LogError("[Build] falhou: " + e);
            code = 1;
        }
        if (Application.isBatchMode) EditorApplication.Exit(code);
    }
}
