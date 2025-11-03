module isurfaceprovider;

import erupted;

interface ISurfaceProvider
{
    VkSurfaceKHR createSurface(VkInstance instance);
    uint getFrameBufferWidth();
    uint getFrameBufferHeight();
}
