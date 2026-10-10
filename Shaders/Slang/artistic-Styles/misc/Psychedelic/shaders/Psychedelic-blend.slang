#version 450

/*
    PSYCHEDELIC SHADER WITH SGPT
    - Effect: Pop Art Studio Psychedelic Wave / Inversion Filter + SGPT Blending
    - Detail Preservation: keeps the original brightness so game details survive
*/

#pragma parameter PSY_AMOUNT "Amount" 100.0 0.0 100.0 1.0
#pragma parameter PSY_FREQ "Frequency" 3.0 0.5 30.0 0.5
#pragma parameter PSY_DETAIL "Detail Preservation" 1.0 0.0 1.0 0.05
#pragma parameter SGPT_BLEND_LEVEL "SGPT Blend Level" 1.0 0.0 1.0 0.05


// ============================================================================
// Push Constants
// ============================================================================

layout(push_constant) uniform Push
{
    float PSY_AMOUNT;
    float PSY_FREQ;
    float PSY_DETAIL;
    float SGPT_BLEND_LEVEL;
} params;


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

layout(location = 0) out vec2 uv;

void main()
{
    gl_Position = global.MVP * Position;
    uv = TexCoord;
}


// ============================================================================
// Fragment Stage
// ============================================================================

#pragma stage fragment

layout(location = 0) in vec2 uv;
layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 2) uniform sampler2D Source;

const vec3 Y = vec3(0.299, 0.587, 0.114);


void main()
{
    // 1. SGPT Sampling (3 Taps)
    vec2 dx = vec2(1.0 / global.SourceSize.x, 0.0);
    vec3 C = texture(Source, uv).rgb;
    vec3 L = texture(Source, uv - dx).rgb;
    vec3 R = texture(Source, uv + dx).rgb;

    // 2. SGPT Difference & Blending
    vec3 diffL = C - L;
    vec3 diffR = C - R;

    float wL = dot(abs(diffL), Y);
    float wR = dot(abs(diffR), Y);

    vec3 core_col = (wR < wL) ? (C - 0.5 * params.SGPT_BLEND_LEVEL * diffR)
                              : (C - 0.5 * params.SGPT_BLEND_LEVEL * diffL);

    // 3. Psychedelic Color Wave (Trigonometric Inversion)
    float amt = params.PSY_AMOUNT / 100.0;
    vec3 psy = 0.5 + 0.5 * sin((vec3(1.0) - core_col) * params.PSY_FREQ * 3.14159265);

    // 4. Detail Preservation: keep ORIGINAL brightness, take only new colors
    float lumOrig = dot(core_col, Y);
    float lumPsy  = dot(psy, Y);
    vec3 psyKeep  = clamp(psy + (lumOrig - lumPsy), 0.0, 1.0);
    psy = mix(psy, psyKeep, params.PSY_DETAIL);

    // 5. Blend Core Color with Psychedelic Effect
    vec3 final_col = mix(core_col, psy, amt);

    // 6. Output Final Color
    FragColor = vec4(clamp(final_col, 0.0, 1.0), 1.0);
}
