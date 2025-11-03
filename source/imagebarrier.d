module imagebarrier;

import erupted;

struct ImageLayoutTransition
{
    VkImageLayout oldLayout;
    VkImageLayout newLayout;
    VkAccessFlags srcAccessMask;
    VkAccessFlags dstAccessMask;
    VkPipelineStageFlags srcStage;
    VkPipelineStageFlags dstStage;

    static ImageLayoutTransition fromUndefinedToColorAttachment()
    {
        ImageLayoutTransition transition;
        transition.oldLayout = VK_IMAGE_LAYOUT_UNDEFINED;
        transition.newLayout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
        transition.srcAccessMask = 0;
        transition.dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
        transition.srcStage = VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT;
        transition.dstStage = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
        return transition;
    }

    static ImageLayoutTransition fromPresentSrcToColorAttachment()
    {
        ImageLayoutTransition transition;
        transition.oldLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;
        transition.newLayout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
        transition.srcAccessMask = 0;
        transition.dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
        transition.srcStage = VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT;
        transition.dstStage = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
        return transition;
    }

    static ImageLayoutTransition fromColorToPresent()
    {
        ImageLayoutTransition transition;
        transition.oldLayout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
        transition.newLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;
        transition.srcAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
        transition.dstAccessMask = 0;
        transition.srcStage = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
        transition.dstStage = VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT;
        return transition;
    }
}
