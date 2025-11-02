import bindbc.glfw;
import bindbc.loader;
import erupted;

mixin(bindGLFW_Vulkan);

void main()
{
    version(Windows)
    {
        const rc = loadGLFW("lib/glfw3.dll");
        assert(rc == glfwSupport);
    }
    assert(glfwInit() != 0);
    scope (exit) glfwTerminate();
    assert(glfwVulkanSupported() != 0);
    glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
    glfwWindowHint(GLFW_RESIZABLE, GLFW_FALSE);

	// vulkan initialization.
	import erupted.vulkan_lib_loader : loadGlobalLevelFunctions;
	loadGlobalLevelFunctions();

    auto window = glfwCreateWindow(1280, 780, "", null, null);
    assert(window !is null);
    scope(exit) glfwDestroyWindow(window);
    while (glfwWindowShouldClose(window) == GLFW_FALSE)
    {
        glfwPollEvents();
    }
}
