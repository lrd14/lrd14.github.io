#pragma once
#include <cstdint>

/* =============================================================
/*                        gurp's offsets
/*                       https://gurp.cc
/* -------------------------------------------------------------
/*  Dumped With     : gurpDumper
/*  Roblox Version  : version-9ac8595712b447a7
/*  Dumper Version  : 1.1.0
/*  Dumped At       : 20:21 20/10/2026 (GMT)
/*  Total Offsets   : 41
/* -------------------------------------------------------------
/*  Join the discord!
/*  https://discord.gg/UZz5rxRjeM
/* =============================================================
*/

namespace Offsets {
    inline std::string ClientVersion = "version-9ac8595712b447a7";

    namespace Attribute {
         inline constexpr uintptr_t TypeIdRva = 0x867113C;
         inline constexpr uintptr_t Key = 0x0;
         inline constexpr uintptr_t Size = 0x58;
         inline constexpr uintptr_t Value = 0x8;
    }

    namespace AttributesMap {
         inline constexpr uintptr_t Attributes = 0x18;
         inline constexpr uintptr_t Length = 0x0;
    }

    namespace Instance {
         inline constexpr uintptr_t AttributeMap = 0x38;
         inline constexpr uintptr_t AttributeToValue = 0x18;
    }

    namespace FastClusterEntity {
         inline constexpr uintptr_t VTableRva = 0x7067468;
         inline constexpr uintptr_t RenderQueueId = 0x10;
         inline constexpr uintptr_t TechniqueArrayPtr = 0x70;
         inline constexpr uintptr_t ClusterNode = 0x8;
         inline constexpr uintptr_t BoundsMin = 0x20;
         inline constexpr uintptr_t BoundsMax = 0x2C;
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
         inline constexpr uintptr_t ShaderProgram = 0x28;
         inline constexpr uintptr_t ShaderProgramBlock = 0x30;
    }

    namespace ShaderProgram {
         inline constexpr uintptr_t VulkanVTableRva = 0x6C64F70;
         inline constexpr uintptr_t D3D11VTableRva = 0x6C64828;
    }

    namespace ShaderName {
         inline constexpr uintptr_t ForcefieldFS = 0x6E7FA50;
         inline constexpr uintptr_t NeonFS = 0x6E7F980;
         inline constexpr uintptr_t GlassFS = 0x6E7FA90;
    }

    namespace FriendService {
         inline constexpr uintptr_t FriendsMap = 0x260;
    }

    namespace WorldRoot {
         inline constexpr uintptr_t BoundFnOffset = 0x90;
         inline constexpr uintptr_t RaycastDescriptorRva = 0x86E0D50;
         inline constexpr uintptr_t FindPartOnRayDescriptorRva = 0x86E1790;
         inline constexpr uintptr_t FindPartOnRayWithIgnoreListDescriptorRva = 0x86E1850;
         inline constexpr uintptr_t FindPartOnRayWithWhitelistDescriptorRva = 0x86E1910;
         inline constexpr uintptr_t RaycastCachedTerrainDescriptorRva = 0x86E0380;
         inline constexpr uintptr_t RaycastBatchedDescriptorRva = 0x0;
         inline constexpr uintptr_t RaycastTerrainDescriptorRva = 0x0;
         inline constexpr uintptr_t BlockcastDescriptorRva = 0x86E04F0;
         inline constexpr uintptr_t ShapecastDescriptorRva = 0x86E0F90;
         inline constexpr uintptr_t SpherecastDescriptorRva = 0x86E11F0;
    }
}
