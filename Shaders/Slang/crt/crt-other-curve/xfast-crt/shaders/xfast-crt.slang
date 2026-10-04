#version 450

/* 777-TURBO-ZFAST-QUILEZ-EDITION + PAS700 MASK (Curved & Border Edition)
    - INTEGRATED: Quilez Scaling + ZFast Scanlines.
    - MASK: PAS700 Procedural Aperture Grille.
    - GEOMETRY: CRT Barrel Warp, Smooth Border & Vignette from good-crt-curve.
*/

#pragma parameter CRT_WARP        "Curvature Amount"        0.10  0.0  0.5  0.01
#pragma parameter CRT_BORDER      "Border Sharpness"        0.02  0.001 0.1  0.001
#pragma parameter VIGNETTE_AMOUNT "Vignette Strength"      0.35  0.0  1.0  0.05
#pragma parameter VIGNETTE_RADIUS "Vignette Radius"        0.9   0.3  1.5  0.05
#pragma parameter LOWLUMSCAN "Scanline Darkness - Low" 4.5 0.0 15.0 0.5
#pragma parameter BRIGHTBOOST "Brightness Boost" 1.25 0.5 2.0 0.05
#pragma parameter MASK_STR "Mask Intensity" 0.45 0.0 1.0 0.05
#pragma parameter MASK_W "PAS700 Mask Width" 6.0 1.0 16.0 1.0
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
	float LOWLUMSCAN;
	float BRIGHTBOOST;
	float MASK_STR;
	float MASK_W;
	float SCAN_FADE_POINT;
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

    // 4. Quilez Scaling Algorithm
    vec2 texCoord = warpedFramePos * frameScale;
    vec2 q_p = texCoord * params.SourceSize.xy;
    vec2 q_i = floor(q_p) + 0.5;
    vec2 q_f = q_p - q_i;
    vec2 q_final = (q_i + 4.0 * q_f * q_f * q_f) / params.SourceSize.xy;
    
    vec3 res = texture(Source, q_final).rgb;

    // 5. ZFast Scanlines
    float pos_y = texCoord.y * params.SourceSize.y;
    float scan_dist = fract(pos_y) - 0.5;
    float Y = scan_dist * scan_dist;
    float scanWeightL = (params.BRIGHTBOOST - params.LOWLUMSCAN * (Y - 1.5 * Y * Y));
    
    // 6. PAS700 Procedural RGB Mask
    float W = floor(params.MASK_W);
    float pos = mod(gl_FragCoord.x, W) / W;
    vec3 mcol = clamp(2.0 - abs(pos * 6.0 - vec3(1.0, 3.0, 5.0)), 0.0, 1.0);
    vec3 mask_rgb = mix(vec3(1.0), mcol, params.MASK_STR);

    // 7. Vignette
    float vignetteDist = length(cc) / params.VIGNETTE_RADIUS;
    float vignette = 1.0 - clamp(vignetteDist * vignetteDist, 0.0, 1.0) * params.VIGNETTE_AMOUNT;
    res *= vignette;

    // 8. Final Blend & Border Mask
    float luma = dot(res, vec3(0.299, 0.587, 0.114));
    float final_scan = mix(scanWeightL, 1.0, smoothstep(0.1, params.SCAN_FADE_POINT, luma));
    vec3 final_rgb = res * final_scan * mask_rgb;
    final_rgb *= borderMask * inBounds;

    FragColor = vec4(clamp(final_rgb, 0.0, 1.0), 1.0);
}
