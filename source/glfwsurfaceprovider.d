module glfwsurfaceprovider;

import bindbc.glfw;
import erupted;

import common;
import isurfaceprovider;

class GLFWSurfaceProvider : ISurfaceProvider
{
public:
    this(GLFWwindow* window)
    {
        m_window = window;
    }

    VkSurfaceKHR createSurface(VkInstance instance)
    {
        assert(loadGLFW_Vulkan);
        VkSurfaceKHR surface;
        enforceVK(glfwCreateWindowSurface(instance, m_window, null, &surface));
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
