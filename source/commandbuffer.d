module commandbuffer;

import erupted;

import common;
import imagebarrier;
import vulkancontext;

class CommandBuffer
{
    this(VkCommandBuffer commandBuffer)
    {
        m_commandBuffer = commandBuffer;
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
        VkImageMemoryBarrier imageBarrier = {
            srcAccessMask: transition.srcAccessMask,
            dstAccessMask: transition.dstAccessMask,
            oldLayout: transition.oldLayout,
            newLayout: transition.newLayout,
            srcQueueFamilyIndex: VK_QUEUE_FAMILY_IGNORED,
            dstQueueFamilyIndex: VK_QUEUE_FAMILY_IGNORED,
            image: image,
            subresourceRange: range,
        };

        vkCmdPipelineBarrier(
            m_commandBuffer,
            transition.srcStage, transition.dstStage,
            0, 0, null, 0, null, 1, &imageBarrier
        );
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

    VkCommandBuffer m_commandBuffer;
}
