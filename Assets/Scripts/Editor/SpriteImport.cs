using UnityEditor;

// Importa as ilustrações PNG (personagens, retratos e cenários gerados) como sprites prontos para o celular:
// sem mipmap, alfa como transparência e ASTC 6x6 no Android (orçamento de memória da bíblia de arte).
public class SpriteImport : AssetPostprocessor
{
    void OnPreprocessTexture()
    {
        if (!assetPath.Contains("/Resources/Sprites/") || !assetPath.EndsWith(".png")) return;
        var ti = (TextureImporter)assetImporter;
        string n = System.IO.Path.GetFileNameWithoutExtension(assetPath);
        ti.textureType = TextureImporterType.Sprite;
        ti.spriteImportMode = SpriteImportMode.Single;
        ti.mipmapEnabled = false;
        ti.alphaIsTransparency = true;
        ti.wrapMode = UnityEngine.TextureWrapMode.Clamp;
        ti.filterMode = UnityEngine.FilterMode.Bilinear;
        int max = n.StartsWith("retrato_") ? 512 : 2048;
        ti.maxTextureSize = max;
        ti.textureCompression = TextureImporterCompression.CompressedHQ;
        var android = ti.GetPlatformTextureSettings("Android");
        android.overridden = true;
        android.maxTextureSize = max;
        android.format = TextureImporterFormat.ASTC_6x6;
        ti.SetPlatformTextureSettings(android);
    }
}
