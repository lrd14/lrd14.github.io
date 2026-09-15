#pragma once
#include <cstdint>

/* =============================================================
/*                        gurp's offsets
/*                       https://gurp.cc
/* -------------------------------------------------------------
/*  Dumped With     : gurpDumper
/*  Roblox Version  : version-4310300497aa4917
/*  Dumper Version  : 1.0.0
/*  Dumped At       : 16:03 15/09/2026 (GMT)
/*  Total Offsets   : 28
/* -------------------------------------------------------------
/*  Join the discord!
/*  https://discord.gg/UZz5rxRjeM
/* =============================================================
*/

namespace Offsets {
    inline std::string ClientVersion = "version-4310300497aa4917";

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
         inline constexpr uintptr_t VTableRva = 0x6C861F8;
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

    namespace WorldRoot {
         inline constexpr uintptr_t BoundFnOffset = 0x80;
         inline constexpr uintptr_t RaycastDescriptorRva = 0x8217310;
         inline constexpr uintptr_t FindPartOnRayDescriptorRva = 0x8217C60;
         inline constexpr uintptr_t FindPartOnRayWithIgnoreListDescriptorRva = 0x8217D10;
         inline constexpr uintptr_t FindPartOnRayWithWhitelistDescriptorRva = 0x8217DC0;
         inline constexpr uintptr_t RaycastCachedTerrainDescriptorRva = 0x8216A00;
         inline constexpr uintptr_t RaycastBatchedDescriptorRva = 0x0;
         inline constexpr uintptr_t RaycastTerrainDescriptorRva = 0x0;
         inline constexpr uintptr_t BlockcastDescriptorRva = 0x8216B50;
         inline constexpr uintptr_t ShapecastDescriptorRva = 0x8217520;
         inline constexpr uintptr_t SpherecastDescriptorRva = 0x8217740;
    }
}
