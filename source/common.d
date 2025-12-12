module common;

import std.conv : to;
import std.exception : enforce;

import bindbc.glfw;
import erupted;
mixin(bindGLFW_Vulkan);

version(Windows)
{
    import core.sys.windows.windows;
    import erupted.platform_extensions;
    mixin Platform_Extensions!USE_PLATFORM_WIN32_KHR;
}

void enforceVK(VkResult result)
{
    enforce(result == VkResult.VK_SUCCESS, result.to!string);
}

// missing vulkan binding.
nothrow @nogc:

alias PFN_vkCreateDebugUtilsMessenger = VkResult function(
    VkInstance, VkDebugUtilsMessengerCreateInfoEXT*, void*, VkDebugUtilsMessengerEXT*
);

/*
alias PFN_vkSetDebugUtilsObjectNameEXT = VkResult function(
    VkInstance, VkDebugUtilsObjectNameEXT*
);
*/

void clear(T)(ref T[] arr)
{
    arr.length = 0;
    arr.destroy!false(); // this doesn't initiate a GC cycle or free any GC memory.
}
