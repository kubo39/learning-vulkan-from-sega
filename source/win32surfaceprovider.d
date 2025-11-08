module win32surfaceprovider;

version(Windows):

import core.sys.windows.windows;

import bindbc.glfw;
import erupted;

import common;
import isurfaceprovider;

class Win32SurfaceProvider : ISurfaceProvider
{
    this(GLFWwindow* window)
    {
        m_window = window;
    }

    VkSurfaceKHR createSurface(VkInstance instance)
    {
        assert(loadGLFW_Windows);
        VkWin32SurfaceCreateInfoKHR createInfo = {
            hinstance: GetModuleHandle(null),
            hwnd: glfwGetWin32Window(m_window)
        };
        VkSurfaceKHR surface;
        enforceVK(vkCreateWin32SurfaceKHR(instance, &createInfo, null, &surface));
        return surface;
    }

    uint getFrameBufferWidth()
    {
        int width;
        glfwGetFramebufferSize(m_window, &width, null);
        return cast(uint) width;
    }

    uint getFrameBufferHeight()
    {
        int height;
        glfwGetFramebufferSize(m_window, null, &height);
        return cast(uint) height;
    }

private:
    GLFWwindow* m_window;
}
