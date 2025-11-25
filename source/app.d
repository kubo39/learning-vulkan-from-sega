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

        VkAttachmentDescription[1] attachments;
	    with (attachments[0])
	    {
		    format = swapchain.getImageFormat.format;
		    samples = VK_SAMPLE_COUNT_1_BIT;
		    loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR;
		    storeOp = VK_ATTACHMENT_STORE_OP_STORE;
		    stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
		    stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
		    initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
		    finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;
	    }

	    VkAttachmentReference colorAttachment = {
		    attachment: 0,
		    layout: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
	    };
	    VkSubpassDescription subpass = {
		    pipelineBindPoint: VK_PIPELINE_BIND_POINT_GRAPHICS,
		    colorAttachmentCount: 1,
		    pColorAttachments: &colorAttachment,
	    };

	    VkSubpassDependency dependency = {
		    srcSubpass: VK_SUBPASS_EXTERNAL,
		    dstSubpass: 0,
		    srcStageMask: VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
		    srcAccessMask: 0,
		    dstStageMask: VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
		    dstAccessMask: VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
	    };

	    VkRenderPassCreateInfo renderPassCI = {
		    attachmentCount: 1,
		    pAttachments: attachments.ptr,
		    subpassCount: 1,
		    pSubpasses: &subpass,
		    dependencyCount: 1,
		    pDependencies: &dependency,
        };
        VkRenderPass renderPass;
        enforceVK(vkCreateRenderPass(device, &renderPassCI, null, &renderPass));

        auto clearColor = VkClearValue(VkClearColorValue([0.6f, 0.2f, 0.3f, 1.0f]));
        VkRenderPassBeginInfo passBeginInfo = {
            renderPass: renderPass,
            renderArea: VkRect2D(VkOffset2D(0, 0), extent),
            clearValueCount: 1,
            pClearValues: &clearColor,
        };

        writeln("vkCmdBeginRenderPass");
        vkCmdBeginRenderPass(commandBuffer.get(), &passBeginInfo, VK_SUBPASS_CONTENTS_INLINE);
        vkCmdEndRenderPass(commandBuffer.get());

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
