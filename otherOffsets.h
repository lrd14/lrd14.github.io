#pragma once
#include <cstdint>

/* =============================================================
/*                        gurp's offsets
/*                       https://gurp.cc
/* -------------------------------------------------------------
/*  Dumped With     : gurpDumper
/*  Roblox Version  : version-ddf602d9cfe44005
/*  Dumper Version  : 1.0.0
/*  Dumped At       : 11:04 22/08/2026 (GMT)
/*  Total Offsets   : 21
/* -------------------------------------------------------------
/*  Join the discord!
/*  https://discord.gg/UZz5rxRjeM
/* =============================================================
*/

namespace Offsets {
    inline std::string ClientVersion = "version-ddf602d9cfe44005";
    
    namespace Instance {
         inline constexpr uintptr_t AttributeMap = 0x38;
         inline constexpr uintptr_t AttributeToValue = 0x18;
    }
     namespace AttributesMap {
         inline constexpr uintptr_t Attributes = 0x18;
         inline constexpr uintptr_t Length = 0x0;
    }
     namespace Attribute {
         inline constexpr uintptr_t TypeIdRva = 0x867113C;
         inline constexpr uintptr_t Key = 0x0;
         inline constexpr uintptr_t Size = 0x58;
         inline constexpr uintptr_t Value = 0x8;
    }

    namespace FastClusterEntity {
         inline constexpr uintptr_t VTableRva = 0x68CB818;
         inline constexpr uintptr_t RenderQueueId = 0x10;
         inline constexpr uintptr_t TechniqueArrayPtr = 0x70;
    }

    namespace TechniqueArray {
         inline constexpr uintptr_t BeginOffset = 0x0;
         inline constexpr uintptr_t EndOffset = 0x8;
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
         inline constexpr uintptr_t RaycastDescriptorRva = 0x82012A0;
         inline constexpr uintptr_t FindPartOnRayDescriptorRva = 0x8201B40;
         inline constexpr uintptr_t FindPartOnRayWithIgnoreListDescriptorRva = 0x8201BF0;
         inline constexpr uintptr_t FindPartOnRayWithWhitelistDescriptorRva = 0x8201CA0;
         inline constexpr uintptr_t RaycastCachedTerrainDescriptorRva = 0x8200990;
         inline constexpr uintptr_t RaycastBatchedDescriptorRva = 0x0;
         inline constexpr uintptr_t RaycastTerrainDescriptorRva = 0x0;
    }
}
