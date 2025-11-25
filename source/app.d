module app;

import core.thread;
import core.time;

import std.stdio;

import bindbc.glfw;
import bindbc.loader;
import erupted;

import common;
import imagebarrier;
import vulkancontext;
import win32surfaceprovider;

interface ISampleApp
{
    void onInitialize();
    void onDrawFrame();
    void onCleanup();
}

class TriangleApp : ISampleApp
{
    override void onInitialize() {}

    override void onDrawFrame()
    {
        auto vulkanCtx = VulkanContext.get();
        auto swapchain = vulkanCtx.getSwapchain();
        auto device = vulkanCtx.getVkDevice();

        if (vulkanCtx.acquireNextImage() != VK_SUCCESS)
        {
            Thread.sleep(100.msecs);
            return;
        }

        auto frameCtx = vulkanCtx.getCurrentFrameContext();
        auto commandBuffer = frameCtx.commandBuffer;
        commandBuffer.begin();

        // 描画前: UNDEFINED -> COLOR_ATTACHMENT_OPTIMAL
        // VK_ATTACHMENT_LOAD_OP_CLEARを指定のため、常にUNDEFINED指定遷移で問題なし
        VkImageSubresourceRange range = {
            aspectMask: VK_IMAGE_ASPECT_COLOR_BIT,
            baseMipLevel: 0,
            levelCount: 1,
            baseArrayLayer: 0,
            layerCount: 1,
        };
        commandBuffer.transitionLayout(
            swapchain.getCurrentImage(), range,
            ImageLayoutTransition.fromUndefinedToColorAttachment()
        );

        auto imageView = swapchain.getCurrentView();
        auto extent = swapchain.getExtent();

        VkRenderingAttachmentInfo colorAttachment = {
            imageView: imageView,
            imageLayout: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
            loadOp: VK_ATTACHMENT_LOAD_OP_CLEAR,
            storeOp: VK_ATTACHMENT_STORE_OP_STORE,
            clearValue: VkClearValue(
                VkClearColorValue([0.6f, 0.2f, 0.3f, 1.0f])
            ),
        };
        VkRenderingInfo renderingInfo = {
            renderArea: VkRect2D(VkOffset2D(0, 0), extent),
            layerCount: 1,
            colorAttachmentCount: 1,
            pColorAttachments: &colorAttachment
        };
        vkCmdBeginRendering(commandBuffer.get(), &renderingInfo);

        vkCmdEndRendering(commandBuffer.get());

        // 表示用レイアウト変更
        commandBuffer.transitionLayout(
            swapchain.getCurrentImage(), range,
            ImageLayoutTransition.fromUndefinedToColorAttachment()
        );
        commandBuffer.end();

        vulkanCtx.submitPresent();
    }

    override void onCleanup() {}
}

void main()
{
    version(Windows)
    {
        const rc = loadGLFW("lib/glfw3.dll");
        assert(rc == glfwSupport);
        assert(loadGLFW_Windows);
    }
    assert(glfwInit() != 0);
    scope (exit) glfwTerminate();
    assert(glfwVulkanSupported() != 0);
    glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
    glfwWindowHint(GLFW_RESIZABLE, GLFW_FALSE);

	// vulkan initialization.
    auto window = glfwCreateWindow(1280, 780, "", null, null);
    assert(window !is null);
    scope(exit) glfwDestroyWindow(window);

    auto surfaceProvider = new Win32SurfaceProvider(window);

    auto vulkanCtx = VulkanContext.get();
    scope(exit) vulkanCtx.cleanup();
    vulkanCtx.initialize("Triangle", surfaceProvider);
    vulkanCtx.recreateSwapchain();

    auto theApp = new TriangleApp;
    theApp.onInitialize();
    scope(exit) theApp.onCleanup();

    while (glfwWindowShouldClose(window) == GLFW_FALSE)
    {
        glfwPollEvents();

        theApp.onDrawFrame();
    }
}
