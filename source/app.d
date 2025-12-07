module app;

import core.stdc.string : memcpy;

import core.thread;
import core.time;

import std.stdio;

import bindbc.glfw;
import bindbc.loader;
import erupted;
import gl3n.linalg;

import assetpath;
import bufferresource;
import common;
import graphicspipelinebuilder;
import imagebarrier;
import shaderloader;
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
public:
    struct Vertex
    {
        vec3 position;
        vec3 color;
    }

    override void onInitialize()
    {
        initializeTriangleVertexBuffer();
        initializeGraphicsPipeline();
    }

    override void onDrawFrame()
    {
        auto vulkanCtx = VulkanContext.get();
        auto swapchain = vulkanCtx.getSwapchain();
        auto device = vulkanCtx.getVkDevice();
        auto vkCmdBeginRenderingKHR = vulkanCtx.getBeginRenderingKHR();
        auto vkCmdEndRenderingKHR = vulkanCtx.getEndRenderingKHR();

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

        VkRenderingAttachmentInfoKHR colorAttachment = {
            imageView: imageView,
            imageLayout: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
            loadOp: VK_ATTACHMENT_LOAD_OP_CLEAR,
            storeOp: VK_ATTACHMENT_STORE_OP_STORE,
            clearValue: VkClearValue(
                VkClearColorValue([0.6f, 0.2f, 0.3f, 1.0f])
            ),
        };
        VkRenderingInfoKHR renderingInfo = {
            renderArea: VkRect2D(VkOffset2D(0, 0), extent),
            layerCount: 1,
            colorAttachmentCount: 1,
            pColorAttachments: &colorAttachment
        };

        vkCmdBeginRenderingKHR(commandBuffer.get(), &renderingInfo);

        // 三角形の描画
        vkCmdBindPipeline(commandBuffer.get(), VK_PIPELINE_BIND_POINT_GRAPHICS, m_pipeline);
        auto vb = m_vertexBuffer.getVkBuffer();
        VkDeviceSize[] offsets = [0];
        vkCmdBindVertexBuffers(commandBuffer.get(), 0, 1, &vb, offsets.ptr);
        vkCmdDraw(commandBuffer.get(), 3, 1, 0, 0);

        vkCmdEndRenderingKHR(commandBuffer.get());

        // 表示用レイアウト変更
        commandBuffer.transitionLayout(
            swapchain.getCurrentImage(), range,
            ImageLayoutTransition.fromColorToPresent()
        );
        commandBuffer.end();

        vulkanCtx.submitPresent();
    }

    override void onCleanup()
    {
        auto vulkanCtx = VulkanContext.get();
        auto device = vulkanCtx.getVkDevice();

        device.vkDeviceWaitIdle();
        if (m_pipeline !is null)
        {
            vkDestroyPipeline(device, m_pipeline, null);
        }
        if (m_pipelineLayout !is null)
        {
            vkDestroyPipelineLayout(device, m_pipelineLayout, null);
        }
        m_vertexBuffer.cleanup();
    }

private:
    void initializeTriangleVertexBuffer()
    {
        Vertex[] triangleVertices = [
            Vertex(vec3(-0.5f, -0.5f, 0.0f), vec3(1.0f, 0.0f, 0.0f)),  // 赤
            Vertex(vec3( 0.5f, -0.5f, 0.0f), vec3(0.0f, 1.0f, 0.0f)),  // 緑
            Vertex(vec3( 0.0f,  0.5f, 0.0f), vec3(0.0f, 0.0f, 1.0f)),  // 青
        ];
        VkDeviceSize bufferSize = triangleVertices.length * Vertex.sizeof;
        m_vertexBuffer = VertexBuffer.create(
            bufferSize,
            VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT
        );
        void* p = m_vertexBuffer.map();
        memcpy(p, triangleVertices.ptr, bufferSize);
        m_vertexBuffer.unmap();
    }

    void initializeGraphicsPipeline()
    {
        auto vulkanCtx = VulkanContext.get();
        auto vkDevice = vulkanCtx.getVkDevice();
        auto swapchain = vulkanCtx.getSwapchain();

        VkPipelineLayoutCreateInfo layoutInfo;
        enforceVK(vkCreatePipelineLayout(
            vkDevice, &layoutInfo, null, &m_pipelineLayout)
        );

        VkShaderModule vertShaderModule = loadShaderModule(
            getAssetPath(AssetType.Shader, "triangle.vert.spv")
        );
        VkShaderModule fragShaderModule = loadShaderModule(
            getAssetPath(AssetType.Shader, "triangle.frag.spv")
        );

        VkVertexInputBindingDescription[1] bindingDescriptions = [
            {
                stride: Vertex.sizeof,
                inputRate: VK_VERTEX_INPUT_RATE_VERTEX
            }
        ];

        VkVertexInputAttributeDescription[2] attributeDescriptions = [
            {
                location: 0,
                binding: 0,
                format: VK_FORMAT_R32G32B32_SFLOAT,
                offset: Vertex.position.offsetof
            },
            {
                location: 1,
                binding: 0,
                format: VK_FORMAT_R32G32B32_SFLOAT,
                offset: Vertex.color.offsetof
            }
        ];

        auto builder = new GraphicsPipelineBuilder;
        builder.addShaderStage(
            VK_SHADER_STAGE_VERTEX_BIT,
            vertShaderModule
        );
        builder.addShaderStage(
            VK_SHADER_STAGE_FRAGMENT_BIT,
            fragShaderModule
        );
        builder.setVertexInput(
            bindingDescriptions.ptr, cast(uint) bindingDescriptions.length,
            attributeDescriptions.ptr, cast(uint) attributeDescriptions.length
        );
        auto swapchainExtent = swapchain.getExtent();
        auto scissor = VkRect2D(VkOffset2D(0, 0), swapchainExtent);
        VkViewport viewport = {
            x: 0,
            y: 0,
            width: cast(float) swapchainExtent.width,
            height: cast(float) swapchainExtent.height,
            minDepth: 0.0f,
            maxDepth: 1.0f
        };
        builder.setViewport(viewport, scissor);
        builder.setPipelineLayout(m_pipelineLayout);

        auto colorFormat = swapchain.getFormat.format;
        builder.useDynamicRendering(colorFormat);
        m_pipeline = builder.build();

        vkDestroyShaderModule(vkDevice, vertShaderModule, null);
        vkDestroyShaderModule(vkDevice, fragShaderModule, null);
    }

    VertexBuffer m_vertexBuffer;
    VkPipeline m_pipeline;
    VkPipelineLayout m_pipelineLayout;
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
