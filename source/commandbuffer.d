module commandbuffer;

import erupted;

import common;
import imagebarrier;
import vulkancontext;

private alias PFN_vkCmdPipelineBarrier2KHR = PFN_vkCmdPipelineBarrier2;

class CommandBuffer
{
    this(VkCommandBuffer commandBuffer)
    {
        m_commandBuffer = commandBuffer;
        loadCmdPipelineBarrierFunctions();
    }

    void begin(VkCommandBufferUsageFlags usageFlag = 0)
    {
        VkCommandBufferBeginInfo beginInfo = {
            flags: usageFlag
        };
        enforceVK(vkBeginCommandBuffer(m_commandBuffer, &beginInfo));
    }

    void end()
    {
        vkEndCommandBuffer(m_commandBuffer);
    }

    void reset()
    {
        vkResetCommandBuffer(m_commandBuffer, 0);
    }

    VkCommandBuffer opUnary(string s)() if (s == "*")
    {
        return m_commandBuffer;
    }

    void transitionLayout(
        VkImage image,
        VkImageSubresourceRange range,
        ImageLayoutTransition transition
    )
    {
        VkImageMemoryBarrier2KHR imageBarrier = {
            srcStageMask: transition.srcStage,
            srcAccessMask: transition.srcAccessMask,
            dstStageMask: transition.dstStage,
            dstAccessMask: transition.dstAccessMask,
            oldLayout: transition.oldLayout,
            newLayout: transition.newLayout,
            srcQueueFamilyIndex: VK_QUEUE_FAMILY_IGNORED,
            dstQueueFamilyIndex: VK_QUEUE_FAMILY_IGNORED,
            image: image,
            subresourceRange: range,
        };

        VkDependencyInfoKHR dependencyInfo = {
            imageMemoryBarrierCount: 1,
            pImageMemoryBarriers: &imageBarrier,
        };
        m_pfnCmdPipelineBarrier2KHR(m_commandBuffer, &dependencyInfo);
    }

private:
    ~this()
    {
        auto vulkanCtx = VulkanContext.get();
        vkFreeCommandBuffers(
            vulkanCtx.getVkDevice(),
            vulkanCtx.getCommandPool(),
            1,
            &m_commandBuffer
        );
        m_commandBuffer = null;
    }

    // eruptedはvkCmdPipelineBarrier2KHRの定義をvulkan 1.3の機能である
    // vkCmdPipelineBarrier2のエイリアスで定義しているため、Vulkan 1.3を
    // サポートしていない環境では使えない。
    // そのため自前で関数ポインタをロードしている。
    void loadCmdPipelineBarrierFunctions()
    {
        auto vulkanCtx = VulkanContext.get();
        auto vkDevice = vulkanCtx.getVkDevice();
        m_pfnCmdPipelineBarrier2KHR = cast(PFN_vkCmdPipelineBarrier2KHR)
            vkGetDeviceProcAddr(vkDevice, "vkCmdPipelineBarrier2KHR");
    }

    VkCommandBuffer m_commandBuffer;
    PFN_vkCmdPipelineBarrier2KHR m_pfnCmdPipelineBarrier2KHR;
}
