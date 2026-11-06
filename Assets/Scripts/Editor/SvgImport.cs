using UnityEditor;
using Unity.VectorGraphics.Editor;

// Importa a arte SVG como sprite com textura em alta resolução (antialias 4x).
public class SvgImport : AssetPostprocessor
{
    void OnPreprocessAsset()
    {
        if (!(assetImporter is SVGImporter svg) || !assetPath.Contains("/Resources/Sprites/")) return;
        string n = System.IO.Path.GetFileNameWithoutExtension(assetPath);
        int size = 256;
        if (n.StartsWith("bg_") || n.StartsWith("hub_")) size = 2048;
        else if (n.StartsWith("heroi_") || n.StartsWith("inimigo_")) size = 640;
        else if (n == "particula") size = 64;
        svg.SvgType = SVGType.TexturedSprite;
        svg.TextureSize = size;
        svg.KeepTextureAspectRatio = true;
        svg.SampleCount = 4;
        svg.GradientResolution = 128;
        svg.WrapMode = UnityEngine.TextureWrapMode.Clamp;  // evita a linha fina na borda das camadas
    }
}
