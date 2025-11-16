module vulkancontext;

version(Windows) import core.sys.windows.windows;
import core.stdc.stdio : printf, snprintf;
import std.concurrency : initOnce;
import std.stdio;

import erupted;

import commandbuffer;
import common;
import isurfaceprovider;
import swapchain;

static class VulkanContext
{
public:
    enum MAX_INFLIGHT_FRAMES = 2;

    struct FrameContext
    {
        CommandBuffer commandBuffer;
        VkFence inflightFence;
    }

    static VulkanContext get()
    {
        __gshared VulkanContext instance;
        return initOnce!instance(new VulkanContext);
    }

    void initialize(const(char)* appName, ISurfaceProvider surfaceProvider)
    {
        m_surfaceProvider = surfaceProvider;
        createInstance(appName);
        common.loadInstanceLevelFunctions(m_vkInstance);
        pickPhysicalDevice();
        writeln("get device");
        createLogicalDevice();
        writeln("create command pool");
        createCommandPool();
    }

    void recreateSwapchain()
    {
        if (m_swapchain is null)
        {
            m_swapchain = new Swapchain;
        }

        if (m_surface is null)
        {
            createSurface();
        }

        auto width = m_surfaceProvider.getFrameBufferWidth();
        auto height = m_surfaceProvider.getFrameBufferHeight();
        m_swapchain.recreate(width, height);
    }    

    VkPhysicalDevice getVkPhysicalDevice()
    {
        return m_vkPhysicalDevice;
    }

    VkDevice getVkDevice()
    {
        return m_vkDevice;
    }

    VkSurfaceKHR getSurface()
    {
        return m_surface;
    }

    VkCommandPool getCommandPool()
    {
        return m_commandPool;
    }

    Swapchain getSwapchain()
    {
        return m_swapchain;
    }

    FrameContext getCurrentFrameContext()
    {
        return m_frameContext[m_currentFrameIndex];
    }

    VkResult acquireNextImage()
    {
        auto frame = getCurrentFrameContext();
        auto fence = frame.inflightFence;
        vkWaitForFences(m_vkDevice, 1, &fence, VK_TRUE, ulong.max);

        auto result = m_swapchain.acquireNextImage();
        if (result == VK_SUCCESS)
        {
            vkResetFences(m_vkDevice, 1, &fence);
        }
        assert(result != VK_ERROR_DEVICE_LOST);
        return VK_SUCCESS;
    }

    void submitPresent()
    {
        auto frame = getCurrentFrameContext();

        VkPipelineStageFlags waitStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
        VkSubmitInfo submitInfo;
        // 本フレームで使用するセマフォを取得する
        VkSemaphore renderCompleteSem = m_swapchain.getRenderCompleteSemaphore();
        VkSemaphore presentCompleteSem = m_swapchain.getPresentCompleteSemaphore();

        VkCommandBuffer commandBuffer = frame.commandBuffer.get();
        submitInfo.commandBufferCount = 1;
        submitInfo.pCommandBuffers = &commandBuffer;
        submitInfo.pWaitDstStageMask = &waitStageMask;
        submitInfo.waitSemaphoreCount = 1;
        submitInfo.pWaitSemaphores = &presentCompleteSem;
        submitInfo.signalSemaphoreCount = 1;
        submitInfo.pSignalSemaphores = &renderCompleteSem;
        auto result = vkQueueSubmit(m_graphicsQueue, 1, &submitInfo, frame.inflightFence);
        assert(result != VK_ERROR_DEVICE_LOST);

        // GraphicsQueueがすでにPresentをサポートしていることは確認済
        m_swapchain.queuePresent(m_graphicsQueue);
        advanceFrame();
    }

    void advanceFrame()
    {
        m_currentFrameIndex = (m_currentFrameIndex + 1) % MAX_INFLIGHT_FRAMES;
    }

    void cleanup()
    {
        // デバイスがidle状態になってから破棄
        vkDeviceWaitIdle(m_vkDevice);

        destroyFrameContexts();
        vkDestroyCommandPool(m_vkDevice, m_commandPool, null);

        if (m_swapchain !is null)
        {
            m_swapchain.cleanup();
        }

        if (m_surface !is null)
        {
            vkDestroySurfaceKHR(m_vkInstance, m_surface, null);
            m_surface = null;
        }

        vkDestroyDevice(m_vkDevice, null);
        vkDestroyInstance(m_vkInstance, null);
        m_vkDevice = null;
        m_vkInstance = null;
    }

private:
    void createInstance(const(char)* appName)
    {
        import erupted.vulkan_lib_loader : loadGlobalLevelFunctions;
	    loadGlobalLevelFunctions();

        VkApplicationInfo appInfo;
        appInfo.pApplicationName = appName;
        appInfo.applicationVersion = VK_MAKE_VERSION(1, 0, 0);
        appInfo.pEngineName = "VulkanBookEngine".ptr;
        appInfo.engineVersion = VK_MAKE_VERSION(1, 0, 0);
        appInfo.apiVersion = VK_API_VERSION_1_3;

        const(char)*[] extensionList = [
            VK_KHR_SURFACE_EXTENSION_NAME,
		    VK_KHR_WIN32_SURFACE_EXTENSION_NAME,
        ];
        const(char)*[] layerList = [
            "VK_LAYER_KHRONOS_validation"
        ];
        // 開発時には検証レイヤーを有効化
        //  TODO: debugフラグで切り替えできるように
        extensionList ~= VK_EXT_DEBUG_UTILS_EXTENSION_NAME;

        VkInstanceCreateInfo createInfo;
        createInfo.pApplicationInfo = &appInfo;
        createInfo.enabledExtensionCount = cast(uint) extensionList.length;
        createInfo.ppEnabledExtensionNames = extensionList.ptr;

        //  TODO: debugフラグで切り替えできるように
        createInfo.enabledLayerCount = cast(uint) layerList.length;
        createInfo.ppEnabledLayerNames = layerList.ptr;

        enforceVK(vkCreateInstance(&createInfo, null, &m_vkInstance));
        loadInstanceLevelFunctionsExt(m_vkInstance);
    }

    void pickPhysicalDevice()
    {
        uint count;
        enforceVK(vkEnumeratePhysicalDevices(m_vkInstance, &count, null));
        auto devices = new VkPhysicalDevice[](count);
        enforceVK(vkEnumeratePhysicalDevices(m_vkInstance, &count, devices.ptr));
        m_vkPhysicalDevice = devices[0];

        vkGetPhysicalDeviceMemoryProperties(m_vkPhysicalDevice, &m_memoryProperties);
        vkGetPhysicalDeviceProperties(m_vkPhysicalDevice, &m_physicalDeviceProperties);
    }

    void createLogicalDevice()
    {
        uint queueCount;
        vkGetPhysicalDeviceQueueFamilyProperties(m_vkPhysicalDevice, &queueCount, null);
        auto queues = new VkQueueFamilyProperties[](queueCount);
        vkGetPhysicalDeviceQueueFamilyProperties(m_vkPhysicalDevice, &queueCount, queues.ptr);

        m_graphicsQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        foreach (i, const ref props; queues)
        {
            if ((props.queueFlags & VK_QUEUE_GRAPHICS_BIT) != 0)
            {
                m_graphicsQueueFamilyIndex = cast(uint) i;
            }
        }

        // 拡張機能の設定
        buildVkFeatures();

        const(char)*[] deviceExtensions = [
            VK_KHR_SWAPCHAIN_EXTENSION_NAME,
        ];

        float priority = 1.0;
        VkDeviceQueueCreateInfo queueInfo;
        queueInfo.queueFamilyIndex = m_graphicsQueueFamilyIndex;
        queueInfo.queueCount = 1;
        queueInfo.pQueuePriorities = &priority;

        VkDeviceCreateInfo deviceInfo;
        deviceInfo.queueCreateInfoCount = 1;
        deviceInfo.pQueueCreateInfos = &queueInfo;
        deviceInfo.enabledExtensionCount = cast(uint) deviceExtensions.length;
        deviceInfo.ppEnabledExtensionNames = deviceExtensions.ptr;

        deviceInfo.pNext = &m_physDevFeatures;
        deviceInfo.pEnabledFeatures = null;

        writeln("vkCreateDevice");
        enforceVK(vkCreateDevice(m_vkPhysicalDevice, &deviceInfo, null, &m_vkDevice));
        assert(m_vkDevice !is null);

        loadDeviceLevelFunctionsExtI(m_vkInstance);

        writeln("vkGetDeviceQueue");
        vkGetDeviceQueue(m_vkDevice, m_graphicsQueueFamilyIndex, 0, &m_graphicsQueue);
    }

    void buildVkFeatures()
    {
        buildVkExtensionChain(
            m_physDevFeatures,
            m_vulkan11Features, m_vulkan12Features, m_vulkan13Features
        );

        vkGetPhysicalDeviceFeatures2(m_vkPhysicalDevice, &m_physDevFeatures);

        m_vulkan13Features.dynamicRendering = VK_TRUE;
        m_vulkan13Features.synchronization2 = VK_TRUE;
    }

    void createCommandPool()
    {
        VkCommandPoolCreateInfo commandPoolCI;
        commandPoolCI.queueFamilyIndex = m_graphicsQueueFamilyIndex;
        commandPoolCI.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
        enforceVK(vkCreateCommandPool(m_vkDevice, &commandPoolCI, null, &m_commandPool));
    }

    void createSurface()
    {
        m_surface = m_surfaceProvider.createSurface(m_vkInstance);

        // グラフィクスキューがこのサーフェースにPresentを発行できるか
        VkBool32 present = VK_FALSE;
        vkGetPhysicalDeviceSurfaceSupportKHR(
            m_vkPhysicalDevice,
            m_graphicsQueueFamilyIndex,
            m_surface,
            &present
        );
        assert(present != VK_FALSE, "not supported presentation");
    }

    CommandBuffer createCommandBuffer()
    {
        VkCommandBufferAllocateInfo commandAI = {
            commandPool: m_commandPool,
            level: VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            commandBufferCount: 1,
        };
        VkCommandBuffer commandBuffer;
        enforceVK(vkAllocateCommandBuffers(m_vkDevice, &commandAI, &commandBuffer));
        return new CommandBuffer(commandBuffer);
    }

    void createFrameContexts()
    {
        m_frameContext.length = MAX_INFLIGHT_FRAMES;
        foreach (frame; m_frameContext)
        {
            frame.commandBuffer = createCommandBuffer();
            VkFenceCreateInfo fenceCI = {
                flags: VK_FENCE_CREATE_SIGNALED_BIT
            };
            enforceVK(vkCreateFence(m_vkDevice, &fenceCI, null, &frame.inflightFence));
        }
    }

    void destroyFrameContexts()
    {
        foreach (frame; m_frameContext)
        {
            vkDestroyFence(m_vkDevice, frame.inflightFence, null);
        }
        m_frameContext.clear();
    }

    void createDebugMessenger()
    {
        VkDebugUtilsMessengerCreateInfoEXT createInfo;
        createInfo.messageSeverity =
            VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT |
            VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT |
            VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT;
        createInfo.messageType =
            VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT |
            VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT |
            VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT;
        createInfo.pfnUserCallback = &vulkanDebugCallback;

        auto vkCreateDebugUtilsMessenger = cast(PFN_vkCreateDebugUtilsMessenger)
            vkGetInstanceProcAddr(m_vkInstance, "vkCreateDebugUtilsMessengerEXT");
        
        if (vkCreateDebugUtilsMessenger)
        {
            enforceVK(vkCreateDebugUtilsMessenger(
                m_vkInstance, &createInfo, null, &m_debugMessenger
            ));
        }
/*
        m_pfnSetDebugUtilsObjectNameEXT = cast(PFN_vkSetDebugUtilsObjectNameEXT)
            VkGetInstanceProcAddr(m_vkInstance, "vkSetDebugUtilsObjectNameEXT");
*/
    }

    ISurfaceProvider m_surfaceProvider;
    VkInstance m_vkInstance;

    VkPhysicalDevice m_vkPhysicalDevice;
    VkDevice m_vkDevice;
    VkQueue m_graphicsQueue;
    uint m_graphicsQueueFamilyIndex;
    uint m_presentQueueFamilyIndex;
    VkPhysicalDeviceMemoryProperties m_memoryProperties;
    VkPhysicalDeviceProperties m_physicalDeviceProperties;

    VkSurfaceKHR m_surface;
    VkCommandPool m_commandPool;
    VkDescriptorPool m_descriptorPool;
    FrameContext[] m_frameContext;
    Swapchain m_swapchain;

    VkDebugUtilsMessengerEXT m_debugMessenger;
    //PFN_vkSetDebugUtilsObjectNameEXT m_pfnSetDebugUtilsObjectNameEXT;

    uint m_currentFrameIndex = 0;

    VkPhysicalDeviceFeatures2 m_physDevFeatures;
    VkPhysicalDeviceVulkan11Features m_vulkan11Features;
    VkPhysicalDeviceVulkan12Features m_vulkan12Features;
    VkPhysicalDeviceVulkan13Features m_vulkan13Features;
}

private:

void buildVkExtensionChain(T)(T last)
{
    last.pNext = null;
}

void buildVkExtensionChain(T, U, Rest...)(T current, U next, Rest rest)
{
    current.pNext = &next;
    buildVkExtensionChain(next, rest);
}

extern (Windows) VkBool32 vulkanDebugCallback(
    VkDebugUtilsMessageSeverityFlagBitsEXT severity,
    uint type,  // cannot use VkDebugUtilsMessageTypeFlagBitsEXT here...
    const(VkDebugUtilsMessengerCallbackDataEXT)* pCallbackData,
    void* pUserData) nothrow @nogc
{
    char[4096] message;
    snprintf(message.ptr, message.length, "[Validation Layer] %s\n", pCallbackData.pMessage);
    version(Windows)
    {
        OutputDebugStringA(message.ptr);
    }
    else
    {
        printf("%s", message.ptr);
    }
    return VK_FALSE;
}
