namespace Offsets {
    inline std::string ClientVersion = "version-d584fb6c717a43d9";

    namespace Attribute {
         inline constexpr uintptr_t TypeIdRva = 0x867113c;
    }

    namespace FastClusterEntity {
         inline constexpr uintptr_t VTableRva = 0x68CB818;
         inline constexpr uintptr_t RenderQueueId = 0x10;
         inline constexpr uintptr_t TechniqueArrayPtr = 0x70;
    }

    namespace TechniqueArray {
         inline constexpr uintptr_t BeginOffset = 0x00;
         inline constexpr uintptr_t EndOffset = 0x08;
    }

    namespace MaterialLayer {
         inline constexpr uintptr_t Stride = 136;
         inline constexpr uintptr_t FillModeByte = 0x11;
         inline constexpr uintptr_t MatFlags = 0x18;
         inline constexpr uintptr_t Param = 0x1C;
         inline constexpr uintptr_t Flags2 = 0x20;
         inline constexpr uintptr_t ColorData = 0x24;
    }

    namespace WorldRoot {
         inline constexpr uintptr_t BoundFnOffset = 0x80;
         inline constexpr uintptr_t RaycastDescriptorRva = 0;
         inline constexpr uintptr_t FindPartOnRayDescriptorRva = 0x8201B40;
         inline constexpr uintptr_t FindPartOnRayWithIgnoreListDescriptorRva = 0x8201BF0;
         inline constexpr uintptr_t FindPartOnRayWithWhitelistDescriptorRva = 0x8201CA0;
         inline constexpr uintptr_t RaycastCachedTerrainDescriptorRva = 0;
         inline constexpr uintptr_t RaycastBatchedDescriptorRva = 0;
         inline constexpr uintptr_t RaycastTerrainDescriptorRva = 0;
    }
}
