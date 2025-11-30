module assetpath;

import std.array;
import std.path;

private string g_assetsRoot = "assets";

enum AssetType
{
    Shader,
    Texture,
    Model,
    AssetTypeMax
}

private string toSubDirectoryName(AssetType assetType)
{
    string[AssetType.AssetTypeMax] kAssetdirs = [
        "shader",
        "texture",
        "model"
    ];
    return kAssetdirs[assetType];
}

void setAssetRootPath(string path)
{
    string fullPath = absolutePath(path);
    g_assetsRoot = fullPath.asNormalizedPath.array;
}

string getAssetRootPath()
{
    return g_assetsRoot;
}

string getAssetPath(AssetType type, string fileName)
{
    return buildPath(
        getAssetRootPath,
        toSubDirectoryName(type),
        fileName
    );
}
