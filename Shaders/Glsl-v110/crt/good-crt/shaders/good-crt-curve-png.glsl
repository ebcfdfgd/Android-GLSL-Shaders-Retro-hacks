// #version 110

/*
    CRT Shader (s3) + crt_full Geometry & Vignette
    - Added: CRT Barrel Warp & Smooth Border Mask
    - Added: Vignette Radius & Amount
    - Updated: Sharp PNG Mask integration
*/

#pragma parameter CRT_WARP        "Curvature Amount"        0.10  0.0  0.5  0.01
#pragma parameter CRT_BORDER      "Border Sharpness"        0.02  0.001 0.1 0.001
#pragma parameter MASK_STR        "Mask Intensity"          0.45  0.0  1.0  0.05
#pragma parameter MASK_W          "Mask Width"              6.0   1.0  64.0 1.0
#pragma parameter MASK_H          "Mask Height"             2.0   1.0  64.0 1.0
#pragma parameter VIGNETTE_AMOUNT "Vignette Strength"      0.35  0.0  1.0  0.05
#pragma parameter VIGNETTE_RADIUS "Vignette Radius"        0.9   0.3  1.5  0.05
#pragma parameter BRIGHT_BOOST    "Brightness Boost"       1.30  0.50 3.00 0.05
#pragma parameter SCANLINE_DEPTH  "Scanline Depth"        0.85  0.00 1.00 0.05
#pragma parameter WHITE_FADE      "Scanline White Fade"   1.00  0.00 2.00 0.10

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv;
uniform mat4 MVPMatrix;

void main() {
    uv = TexCoord;
    gl_Position = MVPMatrix * VertexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 uv;
uniform sampler2D Texture, SamplerMask1;
uniform vec2 TextureSize;
uniform vec2 InputSize;

#ifdef PARAMETER_UNIFORM
uniform float CRT_WARP;
uniform float CRT_BORDER;
uniform float MASK_W;
uniform float MASK_H;
uniform float MASK_STR;
uniform float VIGNETTE_AMOUNT;
uniform float VIGNETTE_RADIUS;
uniform float BRIGHT_BOOST;
uniform float SCANLINE_DEPTH;
uniform float WHITE_FADE;
#else
#define CRT_WARP 0.10
#define CRT_BORDER 0.02
#define MASK_W 6.0
#define MASK_H 2.0
#define MASK_STR 0.45
#define VIGNETTE_AMOUNT 0.35
#define VIGNETTE_RADIUS 0.90
#define BRIGHT_BOOST 1.30
#define SCANLINE_DEPTH 0.85
#define WHITE_FADE 1.00
#endif

void main() {
    // 1. Texture Atlas Fix & Coordinate Mapping
    vec2 frameScale = InputSize / TextureSize;
    vec2 framePos = uv / frameScale;

    // 2. CRT Barrel Warp
    vec2 cc = framePos - 0.5;
    float dist = dot(cc, cc) * CRT_WARP;
    vec2 warpedFramePos = framePos + cc * dist;

    // 3. Black Bounds & Smooth Border Mask
    vec2 edgeDist = min(warpedFramePos, 1.0 - warpedFramePos);
    float inBounds = step(0.0, min(edgeDist.x, edgeDist.y));
    float borderMask = smoothstep(0.0, CRT_BORDER, min(edgeDist.x, edgeDist.y));

    // Sample texture with warped UVs
    vec2 warped_uv = warpedFramePos * frameScale;
    vec3 color = texture2D(Texture, warped_uv).rgb;

    // 4. Enhanced Scan Beam & Bloom
    float game_y = warpedFramePos.y * InputSize.y; 
    float scan_pos = fract(game_y);
    float scanline = sin(scan_pos * 3.14159265); 

    float luma = dot(color, vec3(0.299, 0.587, 0.114));
    float fade_curve = pow(luma, max(WHITE_FADE, 0.001));
    float current_scan_depth = SCANLINE_DEPTH * (1.0 - fade_curve);
    float scan_factor = mix(1.0 - current_scan_depth, 1.0, scanline);
    
    color *= scan_factor;

    // 5. Sharp PNG Mask
    vec2 mask_size = vec2(floor(MASK_W), floor(MASK_H));
    vec2 m_uv = (mod(floor(gl_FragCoord.xy), mask_size) + 0.5) / mask_size;
    vec3 mcol = texture2D(SamplerMask1, m_uv).rgb * 1.5;
    color = mix(color, color * mcol, MASK_STR);

    // 6. Vignette
    float vignetteDist = length(cc) / VIGNETTE_RADIUS;
    float vignette = 1.0 - clamp(vignetteDist * vignetteDist, 0.0, 1.0) * VIGNETTE_AMOUNT;
    color *= vignette;

    // 7. Bright Boost & Apply Bounds/Border
    color *= BRIGHT_BOOST;
    color *= borderMask * inBounds;

    gl_FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
#endif