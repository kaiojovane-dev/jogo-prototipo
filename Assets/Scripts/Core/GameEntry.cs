using UnityEngine;

// Ponto de entrada: cria câmera, interface e sobe a máquina Lua. Toda a regra do jogo fica em Lua.
public class GameEntry : MonoBehaviour
{
    public static GameEntry I { get; private set; }

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Boot()
    {
        if (I != null) return;
        var go = new GameObject("GameEntry");
        DontDestroyOnLoad(go);
        go.AddComponent<GameEntry>();
    }

    void Awake()
    {
        I = this;
        Application.targetFrameRate = 60;
        Screen.sleepTimeout = SleepTimeout.NeverSleep;
        Screen.orientation = ScreenOrientation.AutoRotation;
        Screen.autorotateToLandscapeLeft = true;
        Screen.autorotateToLandscapeRight = true;
        Screen.autorotateToPortrait = false;
        Screen.autorotateToPortraitUpsideDown = false;

        var camGo = new GameObject("Camera");
        camGo.transform.SetParent(transform, false);
        var cam = camGo.AddComponent<Camera>();
        cam.clearFlags = CameraClearFlags.SolidColor;
        cam.backgroundColor = new Color32(7, 19, 39, 255);
        cam.orthographic = true;
        cam.cullingMask = 0;

        Sfx.Init(gameObject);
        UIKit.Init(gameObject);
        LuaManager.Init();
        LuaManager.Call("Game_Start");
    }

    void Update()
    {
        LuaManager.Update(Time.unscaledDeltaTime * UIKit.Lento);
        if (Input.GetKeyDown(KeyCode.Escape)) LuaManager.Call("Game_Back");
    }

    void OnApplicationPause(bool pause)
    {
        if (LuaManager.Ready) LuaManager.Call("Game_Pause", pause);
    }

    void OnDestroy()
    {
        LuaManager.Dispose();
    }
}
