module swapchain;

import std.algorithm.comparison : max;
import std.range : back, empty, popBack;

import erupted;

import common;
import vulkancontext;

class Swapchain
{
public:
    void recreate(uint width, uint height)
    {
        auto vulkanCtx = VulkanContext.get();
        auto vkPhysicalDevice = vulkanCtx.getVkPhysicalDevice();
        auto vkDevice = vulkanCtx.getVkDevice();
        auto surface = vulkanCtx.getSurface();

        VkSurfaceCapabilitiesKHR caps;
        vkGetPhysicalDeviceSurfaceCapabilitiesKHR(vkPhysicalDevice, surface, &caps);
        VkExtent2D extent = caps.currentExtent;
        if (extent.width == uint.max)
        {
            extent.width = width;
            extent.height = height;
        }

        uint count;
        vkGetPhysicalDeviceSurfaceFormatsKHR(
            vkPhysicalDevice, surface, &count, null
        );
        auto formats = new VkSurfaceFormatKHR[](count);
        vkGetPhysicalDeviceSurfaceFormatsKHR(
            vkPhysicalDevice, surface, &count, formats.ptr
        );

        VkSurfaceFormatKHR format = formats[0];
        foreach (surfaceFormat; formats)
        {
            if (surfaceFormat.colorSpace != VK_COLORSPACE_SRGB_NONLINEAR_KHR)
            {
                continue;
            }

            if (surfaceFormat.format == VK_FORMAT_B8G8R8A8_UNORM ||
                surfaceFormat.format == VK_FORMAT_R8G8B8A8_UNORM)
            {
                format = surfaceFormat;
                break;
            }
        }

        auto imageCount = max(3, caps.minImageCount);

        VkSwapchainCreateInfoKHR info;
        info.surface = surface;
        info.minImageCount = caps.minImageCount + 1;
        info.imageFormat = format.format;
        info.imageColorSpace = format.colorSpace;
        info.imageExtent = extent;
        info.imageArrayLayers = 1;
        info.imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT;
        info.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE;
        info.preTransform = VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR;
        info.compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
        info.presentMode = VK_PRESENT_MODE_FIFO_KHR;
        info.clipped = VK_TRUE;
        info.oldSwapchain = m_swapchain;

        // GPUがidle状態になってからswapchainの(再)作成
        vkDeviceWaitIdle(vkDevice);

        VkSwapchainKHR swapchain;
        enforceVK(vkCreateSwapchainKHR(vkDevice, &info, null, &swapchain));

        m_swapchain = swapchain;
        m_imageFormat = format;
        m_imageExtent = extent;

        enforceVK(vkGetSwapchainImagesKHR(vkDevice, m_swapchain, &imageCount, null));
        m_images.length = imageCount;
        enforceVK(vkGetSwapchainImagesKHR(vkDevice, m_swapchain, &imageCount, m_images.ptr));

        foreach (i, image; m_images)
        {
            VkImageViewCreateInfo imageViewCI = {
                image: image,
                viewType: VK_IMAGE_VIEW_TYPE_2D,
                format: format.format,
                components: {
                    VK_COMPONENT_SWIZZLE_IDENTITY,
                    VK_COMPONENT_SWIZZLE_IDENTITY,
                    VK_COMPONENT_SWIZZLE_IDENTITY,
                    VK_COMPONENT_SWIZZLE_IDENTITY,
                },
                subresourceRange: {
                    aspectMask: VK_IMAGE_ASPECT_COLOR_BIT,
                    baseMipLevel: 0,
                    levelCount: 1,
                    baseArrayLayer: 0,
                    layerCount: 1,
                }
            };
            VkImageView view;
            enforceVK(vkCreateImageView(vkDevice, &imageViewCI, null, &view));
            m_imageViews ~= view;
        }
        createFrameContext();
    }

    VkResult acquireNextImage()
    {
        auto vulkanCtx = VulkanContext.get();
        auto vkDevice = vulkanCtx.getVkDevice();

        // プレゼンテーション完了待ちで使用するセマフォの取得
        assert(!m_presentSemaphoreList.empty);
        VkSemaphore acquireSemaphore = m_presentSemaphoreList.back;
        m_presentSemaphoreList.popBack;

        auto result = vkAcquireNextImageKHR(
            vkDevice,
            m_swapchain,
            ulong.max,
            acquireSemaphore,
            null,
            &m_currentIndex
        );
        if (result != VK_SUCCESS)
        {
            m_presentSemaphoreList ~= acquireSemaphore;
            return result;
        }

        // 前に使用していたものを置き換える
        VkSemaphore oldSemaphore = m_frames[m_currentIndex].presentComplete;
        if (oldSemaphore !is null)
        {
            m_presentSemaphoreList ~= oldSemaphore;
        }
        m_frames[m_currentIndex].presentComplete = acquireSemaphore;
        return result;
    }

    VkResult queuePresent(VkQueue queuePresent)
    {
        VkPresentInfoKHR presentInfo;
        presentInfo.swapchainCount = 1;
        presentInfo.pSwapchains = &m_swapchain;
        presentInfo.pImageIndices = &m_currentIndex;
        presentInfo.waitSemaphoreCount = 1;
        presentInfo.pWaitSemaphores = &m_frames[m_currentIndex].renderComplete;

        auto vulkanCtx = VulkanContext.get();
        return vkQueuePresentKHR(queuePresent, &presentInfo);
    }

    VkExtent2D getExtent()
    {
        return m_imageExtent;
    }

    VkImage getCurrentImage()
    {
        return m_images[m_currentIndex];
    }

    VkImageView getCurrentView()
    {
        return m_imageViews[m_currentIndex];
    }

    VkSemaphore getPresentCompleteSemaphore()
    {
        return m_frames[m_currentIndex].presentComplete;
    }

    VkSemaphore getRenderCompleteSemaphore()
    {
        return m_frames[m_currentIndex].renderComplete;
    }

    void cleanup()
    {
        auto vulkanCtx = VulkanContext.get();
        auto vkDevice = vulkanCtx.getVkDevice();
        foreach (view; m_imageViews)
        {
            vkDestroyImageView(vkDevice, view, null);
        }
        if (m_swapchain !is null)
        {
            vkDestroySwapchainKHR(vkDevice, m_swapchain, null);
            m_swapchain = null;
        }
        m_images.clear();
        m_imageViews.clear();
    }

private:
    void createFrameContext()
    {
        auto vulkanCtx = VulkanContext.get();
        auto vkDevice = vulkanCtx.getVkDevice();
        m_frames.length = m_images.length;
        foreach (frame; m_frames)
        {
            VkSemaphoreCreateInfo semCI;
            enforceVK(vkCreateSemaphore(vkDevice, &semCI, null, &frame.renderComplete));
        }
        uint presentCompleteSemaphoreCount = cast(uint) m_images.length + 1;
        m_presentSemaphoreList.reserve(presentCompleteSemaphoreCount);
        foreach (i; 0 .. presentCompleteSemaphoreCount)
        {
            VkSemaphoreCreateInfo semaphoreCI;
            VkSemaphore semaphore;
            enforceVK(vkCreateSemaphore(vkDevice, &semaphoreCI, null, &semaphore));
            m_presentSemaphoreList ~= semaphore;
        }
    }

    void destroyFrameContext()
    {
        auto vulkanCtx = VulkanContext.get();
        auto vkDevice = vulkanCtx.getVkDevice();
        foreach (frame; m_frames)
        {
            vkDestroySemaphore(vkDevice, frame.presentComplete, null);
            vkDestroySemaphore(vkDevice, frame.renderComplete, null);
        }
        m_frames.clear();
        foreach (sem; m_presentSemaphoreList)
        {
            vkDestroySemaphore(vkDevice, sem, null);
        }
        m_presentSemaphoreList.clear();
    }

    VkSwapchainKHR m_swapchain;
    uint m_currentIndex;

    VkSurfaceFormatKHR m_imageFormat;
    VkExtent2D m_imageExtent;
    VkImage[] m_images;
    VkImageView[] m_imageViews;

    struct FrameContext
    {
        VkSemaphore presentComplete;
        VkSemaphore renderComplete;
    }

    FrameContext[] m_frames;
    VkSemaphore[] m_presentSemaphoreList;
}
