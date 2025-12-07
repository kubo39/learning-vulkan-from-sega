module bufferresource;

import erupted;

import common;
import vulkancontext;

interface IBufferResource
{
    bool isHostAccessible();
    VkBuffer getVkBuffer();
    VkDeviceSize getBufferSize();

    void setAccessFlags(VkAccessFlags flags);
    VkAccessFlags getAccessFlags();

    void* map();
    void unmap();

    VkDescriptorBufferInfo getDescriptorInfo();
}

class BufferResource(T) : IBufferResource
{
public:
    bool isHostAccessible()
    {
        return (m_memProps & VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT) != 0;
    }

    VkAccessFlags getAccessFlags()
    {
        return m_accessFlags;
    }

    void setAccessFlags(VkAccessFlags flags)
    {
        m_accessFlags = flags;
    }

    VkBuffer getVkBuffer()
    {
        return m_buffer;
    }

    VkDeviceSize getBufferSize()
    {
        return m_size;
    }

    void cleanup()
    {
        auto context = VulkanContext.get();
        auto device = context.getVkDevice();
        if (m_buffer !is null)
        {
            vkDestroyBuffer(device, m_buffer, null);
            m_buffer = null;
        }
        if (m_memory !is null)
        {
            vkFreeMemory(device, m_memory, null);
            m_memory = null;
        }
        m_size = 0;
    }

    VkDescriptorBufferInfo getDescriptorInfo()
    {
        VkDescriptorBufferInfo info;
        info.buffer = m_buffer;
        info.offset = 0;
        info.range = m_size;
        return info;
    }

    bool createBuffer(
        VkBufferCreateInfo createInfo,
        VkMemoryPropertyFlags memProps
    )
    {
        auto context = VulkanContext.get();
        auto device = context.getVkDevice();

        auto result = vkCreateBuffer(device, &createInfo, null, &m_buffer);
        if (result != VK_SUCCESS)
        {
            return false;
        }

        // メモリ要件を取得
        VkMemoryRequirements memRequirements;
        vkGetBufferMemoryRequirements(device, m_buffer, &memRequirements);

        VkMemoryAllocateInfo allocInfo;
        allocInfo.allocationSize = memRequirements.size;
        allocInfo.memoryTypeIndex = context.findMemoryType(memRequirements, memProps);

        result = vkAllocateMemory(device, &allocInfo, null, &m_memory);
        if (result != VK_SUCCESS)
        {
            return false;
        }

        enforceVK(vkBindBufferMemory(device, m_buffer, m_memory, 0));
        m_size = createInfo.size;
        m_memProps = memProps;
        return true;
    }

    void* map() { assert(false); }
    void unmap() { assert(false); }

private:
    VkBuffer m_buffer;
    VkDeviceMemory m_memory;
    VkDeviceSize m_size;
    VkMemoryPropertyFlags m_memProps;
    VkAccessFlags m_accessFlags = VK_ACCESS_NONE;
}

class VertexBuffer : BufferResource!VertexBuffer
{
    static VertexBuffer create(VkDeviceSize size, VkMemoryPropertyFlags memProps)
    {
        auto buffer = new VertexBuffer;
        if (!buffer.initialize(size, memProps))
        {
            return null;
        }
        return buffer;
    }

    bool initialize(VkDeviceSize size, VkMemoryPropertyFlags memProps)
    {
        auto context = VulkanContext.get();
        auto device = context.getVkDevice();

        VkBufferCreateInfo bufferInfo;
        bufferInfo.size = size;
        bufferInfo.usage =
            VK_BUFFER_USAGE_VERTEX_BUFFER_BIT |
            VK_BUFFER_USAGE_TRANSFER_DST_BIT;
        bufferInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
        setAccessFlags(VK_ACCESS_VERTEX_ATTRIBUTE_READ_BIT);
        return createBuffer(bufferInfo, memProps);
    }

    override void* map()
    {
        if (!(m_memProps & VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT))
        {
            return null;
        }

        void* mapped;
        vkMapMemory(
            VulkanContext.get().getVkDevice(),
            m_memory, 0, m_size, 0, &mapped
        );
        return mapped;
    }

    override void unmap()
    {
        if (!(m_memProps & VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT))
        {
            return;
        }
        vkUnmapMemory(
            VulkanContext.get().getVkDevice(),
            m_memory
        );
    }
}
