# Vulkan実践入門で学ぶVulkan

書籍「[Vulkan実践入門](https://gihyo.jp/book/2025/978-4-297-15257-4)」をやる。

## 環境

### Windows

- [Git for Windows](https://gitforwindows.org/)
  - [v2.51.2.windows.1](https://github.com/git-for-windows/git/releases/tag/v2.51.2.windows.1)
- [GLFW 3](https://www.glfw.org/)
  - using mingw64 binary.
- [Vulkan SDK](https://vulkan.lunarg.com/sdk/home)
- LDC v1.41.0
  - via [installer.sh](https://github.com/dlang/installer)
  - [7-zip](https://www.7-zip.org/) is required.

## シェーダーのコンパイル

```console
glslangValidator -V -S vert -o assets/shader/triangle.vert.spv assets/shader/triangle.vert.glsl
glslangValidator -V -S frag -o assets/shader/triangle.frag.spv assets/shader/triangle.frag.glsl
```
