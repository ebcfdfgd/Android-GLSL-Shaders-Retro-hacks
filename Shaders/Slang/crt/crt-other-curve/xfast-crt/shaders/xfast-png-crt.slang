#version 450

/* ULTIMATE-TURBO-HYBRID (Curved & Border Edition)
    - INTEGRATED: Quilez Scaling + Zfast Scanlines + Sharp PNG Mask.
    - GEOMETRY: CRT Barrel Warp, Smooth Border & Vignette from good-crt-curve.
*/

#pragma parameter CRT_WARP        "Curvature Amount"        0.10  0.0  0.5  0.01
#pragma parameter CRT_BORDER      "Border Sharpness"        0.02  0.001 0.1  0.001
#pragma parameter VIGNETTE_AMOUNT "Vignette Strength"      0.35  0.0  1.0  0.05
#pragma parameter VIGNETTE_RADIUS "Vignette Radius"        0.9   0.3  1.5  0.05
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.25 0.5 2.0 0.05
#pragma parameter MASK_STR "Mask Intensity" 0.45 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width" 6.0 1.0 64.0 1.0
#pragma parameter MASK_H "Mask Height" 2.0 1.0 64.0 1.0
#pragma parameter LOWLUMSCAN "Scanline Darkness" 4.5 0.0 15.0 0.5
#pragma parameter SCAN_FADE_POINT "Scanline Fade Cutoff" 0.85 0.5 1.0 0.05

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float CRT_WARP;
	float CRT_BORDER;
	float VIGNETTE_AMOUNT;
	float VIGNETTE_RADIUS;
	float BRIGHT_BOOST;
	float MASK_STR;
	float MASK_W;
	float MASK_H;
	float LOWLUMSCAN;
	float SCAN_FADE_POINT;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 TEX0;

void main() {
    TEX0 = TexCoord;
    gl_Position = global.MVP * Position;
}

#pragma stage fragment
layout(location = 0) in vec2 TEX0;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D SamplerMask1;

void main() {
    // 1. Texture Atlas Fix & Coordinate Mapping
    vec2 frameScale = params.SourceSize.xy / params.SourceSize.xy;
    vec2 framePos = TEX0 / frameScale;

    // 2. CRT Barrel Warp
    vec2 cc = framePos - 0.5;
    float dist = dot(cc, cc) * params.CRT_WARP;
    vec2 warpedFramePos = framePos + cc * dist;

    // 3. Black Bounds & Smooth Border Mask
    vec2 edgeDist = min(warpedFramePos, 1.0 - warpedFramePos);
    float inBounds = step(0.0, min(edgeDist.x, edgeDist.y));
    float borderMask = smoothstep(0.0, params.CRT_BORDER, min(edgeDist.x, edgeDist.y));

    // 4. Quilez Scaling
    vec2 final_uv = warpedFramePos * frameScale;
    vec2 q_p = final_uv * params.SourceSize.xy;
    vec2 q_i = floor(q_p) + 0.5;
    vec2 q_f = q_p - q_i;
    vec2 q_final = (q_i + 4.0 * q_f * q_f * q_f) / params.SourceSize.xy;
    
    vec3 res = texture(Source, q_final).rgb;

    // 5. Zfast Pixel-Sync Scanlines
    float pos_y = final_uv.y * params.SourceSize.y;
    float scan_dist = fract(pos_y) - 0.5;
    float Y = scan_dist * scan_dist;
    float YY = Y * Y;

    float scanWeightL = (params.BRIGHT_BOOST - params.LOWLUMSCAN * (Y - 1.5 * YY));
    float luma = dot(res, vec3(0.299, 0.587, 0.114));
    float final_scan = mix(scanWeightL, 1.0, smoothstep(0.1, params.SCAN_FADE_POINT, luma));
    res *= final_scan;

    // 6. Sharp PNG Mask
    vec2 mask_size = vec2(floor(params.MASK_W), floor(params.MASK_H));
    vec2 m_uv = (mod(floor(gl_FragCoord.xy), mask_size) + 0.5) / mask_size;
    vec3 mcol = texture(SamplerMask1, m_uv).rgb * 1.5;
    res = mix(res, res * mcol, params.MASK_STR);

    // 7. Vignette
    float vignetteDist = length(cc) / params.VIGNETTE_RADIUS;
    float vignette = 1.0 - clamp(vignetteDist * vignetteDist, 0.0, 1.0) * params.VIGNETTE_AMOUNT;
    res *= vignette;

    // 8. Final Polish & Apply Bounds/Border
    res *= params.BRIGHT_BOOST;
    res *= borderMask * inBounds;

    FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
