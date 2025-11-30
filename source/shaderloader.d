module shaderloader;

import std.stdio;

import erupted;

import common;
import vulkancontext;

VkShaderModule loadShaderModule(string shaderSpvPath)
{
    auto f = File(shaderSpvPath, "rb");
    scope(exit) f.close;
    size_t fileSize = f.size;
    auto buffer = f.rawRead(new ubyte[fileSize]);

    VkShaderModuleCreateInfo createInfo = {
        codeSize: fileSize,
        pCode: cast(const(uint)*) buffer
    };

    VkDevice device = VulkanContext.get().getVkDevice();

    VkShaderModule shaderModule;
    enforceVK(vkCreateShaderModule(device, &createInfo, null, &shaderModule));
    return shaderModule;
}

