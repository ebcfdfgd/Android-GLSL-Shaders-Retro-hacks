#version 450

/*
    CRT Shader (s3) + crt_full Geometry & Vignette
    - Added: CRT Barrel Warp & Smooth Border Mask
    - Added: Vignette Radius & Amount
    - Updated: MASK_W default set to 2.0
*/

#pragma parameter CRT_WARP        "Curvature Amount"        0.10  0.0  0.5  0.01
#pragma parameter CRT_BORDER      "Border Sharpness"        0.02  0.001 0.1 0.001
#pragma parameter MASK_W          "PAS700 Mask Width"       3.0   1.0  16.0 1.0
#pragma parameter MASK_STRENGTH   "Mask Strength"           0.50  0.00 1.00 0.05
#pragma parameter VIGNETTE_AMOUNT "Vignette Strength"      0.35  0.0  1.0  0.05
#pragma parameter VIGNETTE_RADIUS "Vignette Radius"        0.9   0.3  1.5  0.05
#pragma parameter BRIGHT_BOOST    "Brightness Boost"       1.30  0.50 3.00 0.05
#pragma parameter SCANLINE_DEPTH  "Scanline Depth"        0.85  0.00 1.00 0.05
#pragma parameter WHITE_FADE      "Scanline White Fade"   1.00  0.00 2.00 0.10

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float CRT_WARP;
	float CRT_BORDER;
	float MASK_W;
	float MASK_STRENGTH;
	float VIGNETTE_AMOUNT;
	float VIGNETTE_RADIUS;
	float BRIGHT_BOOST;
	float SCANLINE_DEPTH;
	float WHITE_FADE;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 uv;

void main() {
    uv = TexCoord;
    gl_Position = global.MVP * Position;
}

#pragma stage fragment
layout(location = 0) in vec2 uv;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main() {
    // 1. Texture Atlas Fix & Coordinate Mapping
    vec2 frameScale = params.SourceSize.xy / params.SourceSize.xy;
    vec2 framePos = uv / frameScale;

    // 2. CRT Barrel Warp
    vec2 cc = framePos - 0.5;
    float dist = dot(cc, cc) * params.CRT_WARP;
    vec2 warpedFramePos = framePos + cc * dist;

    // 3. Black Bounds & Smooth Border Mask
    vec2 edgeDist = min(warpedFramePos, 1.0 - warpedFramePos);
    float inBounds = step(0.0, min(edgeDist.x, edgeDist.y));
    float borderMask = smoothstep(0.0, params.CRT_BORDER, min(edgeDist.x, edgeDist.y));

    // Sample texture with warped UVs
    vec2 warped_uv = warpedFramePos * frameScale;
    vec3 color = texture(Source, warped_uv).rgb;

    // 4. Enhanced Scan Beam & Bloom
    float game_y = warpedFramePos.y * params.SourceSize.y; 
    float scan_pos = fract(game_y);
    float scanline = sin(scan_pos * 3.14159265); 

    float luma = dot(color, vec3(0.299, 0.587, 0.114));
    float fade_curve = pow(luma, max(params.WHITE_FADE, 0.001));
    float current_scan_depth = params.SCANLINE_DEPTH * (1.0 - fade_curve);
    float scan_factor = mix(1.0 - current_scan_depth, 1.0, scanline);
    
    color *= scan_factor;

    // 5. PAS700 Procedural RGB Mask (Size 2.0)
    float W = floor(params.MASK_W);
    float pos = mod(gl_FragCoord.x, W) / W;
    vec3 mcol = clamp(2.0 - abs(pos * 6.0 - vec3(1.0, 3.0, 5.0)), 0.0, 1.0);
    color = mix(color, color * mcol, params.MASK_STRENGTH);

    // 6. Vignette
    float vignetteDist = length(cc) / params.VIGNETTE_RADIUS;
    float vignette = 1.0 - clamp(vignetteDist * vignetteDist, 0.0, 1.0) * params.VIGNETTE_AMOUNT;
    color *= vignette;

    // 7. Bright Boost & Apply Bounds/Border
    color *= params.BRIGHT_BOOST;
    color *= borderMask * inBounds;

    FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
