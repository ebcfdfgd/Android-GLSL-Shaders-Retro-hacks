#version 450

/*
   PURE-COLOR-INVERTER
   - PURPOSE: Pure mathematical color inversion to mix with Core Palettes.
   - HOW IT WORKS: Inverts RGB channels instantly (Output = 1.0 - Input).
*/

// ============================================================================
// RetroArch Global UBO
// ============================================================================

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;

    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;

    uint FrameCount;
} global;


// ============================================================================
// Vertex Stage
// ============================================================================

#pragma stage vertex

layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;

layout(location = 0) out vec2 vTexCoord;

void main()
{
    gl_Position =
        global.MVP *
        Position;

    vTexCoord =
        TexCoord.xy;
}


// ============================================================================
// Fragment Stage
// ============================================================================

#pragma stage fragment

layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
    // 1. Read the color directly from the core
    vec3 core_col =
        texture(
            Source,
            vTexCoord
        ).rgb;


    // 2. Pure sharp pixel-by-pixel inversion
    vec3 inverted_col =
        vec3(1.0) -
        core_col;


    // 3. Output inverted image
    FragColor =
        vec4(
            inverted_col,
            1.0
        );
}