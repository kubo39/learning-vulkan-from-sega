module graphicspipelinebuilder;

import std.string : toStringz;

import erupted;

import common;
import vulkancontext;

class GraphicsPipelineBuilder
{
public:
    this()
    {
        m_device = VulkanContext.get().getVkDevice();
        VkPipelineColorBlendStateCreateInfo colorBlendState = {
            attachmentCount: 1,
            pAttachments: &m_colorBlendAttachment
        };
        m_colorBlendState = colorBlendState;
    }

    void addShaderStage(
        VkShaderStageFlagBits stage,
        VkShaderModule mod,
        string entry = "main"
    )
    {
        VkPipelineShaderStageCreateInfo shaderStage = {
            pNext: null,
            flags: 0,
            stage: stage,
            Module: mod,
            pName: entry.toStringz,
            pSpecializationInfo: null
        };
        m_shaderStages ~= shaderStage;
    }

    void setVertexInput(
        VkVertexInputBindingDescription* bindings,
        uint bindingCount,
        VkVertexInputAttributeDescription* attributes,
        uint attributeCount
    )
    {
        VkPipelineVertexInputStateCreateInfo vertexInputState = {
            pNext: null,
            vertexBindingDescriptionCount: bindingCount,
            pVertexBindingDescriptions: bindings,
            vertexAttributeDescriptionCount: attributeCount,
            pVertexAttributeDescriptions: attributes
        };
        m_vertexInputState = vertexInputState;
    }

    void setViewport(ref VkViewport viewport, ref VkRect2D scissor)
    {
        m_viewport = viewport;
        m_scissor = scissor;
        VkPipelineViewportStateCreateInfo viewportCI = {
            pNext: null,
            viewportCount: 1,
            pViewports: &m_viewport,
            scissorCount: 1,
            pScissors: &m_scissor
        };
        m_viewportState = viewportCI;
    }

    void setPipelineLayout(ref VkPipelineLayout layout)
    {
        m_pipelineLayout = layout;
    }

    VkPipeline build()
    {
        VkGraphicsPipelineCreateInfo graphicsPipelineCI = {
            pNext: null,
            flags: 0,
            stageCount: cast(uint) m_shaderStages.length,
            pStages: m_shaderStages.ptr,
            pVertexInputState: &m_vertexInputState,
            pInputAssemblyState: &m_inputAssemblyState,
            pTessellationState: null,
            pViewportState: &m_viewportState,
            pRasterizationState: &m_rasterizerState,
            pMultisampleState: &m_multisampleState,
            pDepthStencilState: null,
            pColorBlendState: &m_colorBlendState,
            pDynamicState: null,
            layout: m_pipelineLayout,
            renderPass: null,
            subpass: 0,
            basePipelineHandle: null,
            basePipelineIndex: 0
        };
        // dynamic rendering拡張はrenderpassを設定しない
        // かわりに以下を設定する
        graphicsPipelineCI.pNext = &m_renderingInfo;

        VkPipeline pipeline;
        enforceVK(
            vkCreateGraphicsPipelines(
                m_device, null, 1, &graphicsPipelineCI,
                null, &pipeline
            )
        );
        return pipeline;
    }

    void useDynamicRendering(VkFormat colorFormat, VkFormat depthFormat = VK_FORMAT_UNDEFINED)
    {
        m_colorFormat = colorFormat;
        VkPipelineRenderingCreateInfo renderingInfo = {
            colorAttachmentCount: 1,
            pColorAttachmentFormats: &m_colorFormat
        };
        m_renderingInfo = renderingInfo;
    }

private:
    VkDevice m_device;

    VkPipelineShaderStageCreateInfo[] m_shaderStages;

    VkPipelineVertexInputStateCreateInfo m_vertexInputState;
    VkVertexInputBindingDescription[] m_bindingDescriptions;
    VkVertexInputAttributeDescription[] m_attributeDescriptions;

    VkPipelineInputAssemblyStateCreateInfo m_inputAssemblyState = {
        topology: VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
        primitiveRestartEnable: VK_FALSE
    };
    VkPipelineViewportStateCreateInfo m_viewportState;
    VkViewport m_viewport;
    VkRect2D m_scissor;

    VkPipelineRasterizationStateCreateInfo m_rasterizerState = {
        depthClampEnable: VK_FALSE,
        rasterizerDiscardEnable: VK_FALSE,
        polygonMode: VK_POLYGON_MODE_FILL,
        cullMode: VK_CULL_MODE_NONE,
        frontFace: VK_FRONT_FACE_COUNTER_CLOCKWISE,
        depthBiasEnable: VK_FALSE,
        lineWidth: 1.0f
    };
    VkPipelineMultisampleStateCreateInfo m_multisampleState = {
        rasterizationSamples: VK_SAMPLE_COUNT_1_BIT,
        sampleShadingEnable: VK_FALSE
    };
    VkPipelineColorBlendAttachmentState m_colorBlendAttachment = {
        blendEnable: VK_FALSE,
        colorWriteMask: VK_COLOR_COMPONENT_R_BIT |
                        VK_COLOR_COMPONENT_G_BIT |
                        VK_COLOR_COMPONENT_B_BIT |
                        VK_COLOR_COMPONENT_A_BIT
    };
    VkPipelineColorBlendStateCreateInfo m_colorBlendState;

    VkPipelineLayout m_pipelineLayout = null;
    VkFormat m_colorFormat = VK_FORMAT_UNDEFINED;
    VkFormat m_depthFormat = VK_FORMAT_UNDEFINED;

    bool m_useRenderPass = false;
    VkRenderPass m_renderPass = null;
    uint m_subPass = 0;

    VkPipelineRenderingCreateInfo m_renderingInfo;
}
