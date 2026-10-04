#version 450

/* 777-TURBO-ZFAST-QUILEZ-EDITION + PAS700 MASK
    - INTEGRATED: Quilez Scaling + ZFast Scanlines.
    - MASK: PAS700 Procedural Aperture Grille.
    - PERFORMANCE: 100% Branchless Fast Pipeline.
*/

#pragma parameter BARREL_DISTORTION "Curve 0 Strength" 0.15 0.0 1.0 0.02
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
	float BARREL_DISTORTION;
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
    // 1. Coordinates & Curve
    vec2 sc = params.SourceSize.xy / params.SourceSize.xy;
    vec2 p = (uv * sc) - 0.5;
    float r2 = dot(p, p);
    vec2 p_curved = p * (1.0 + r2 * vec2(params.BARREL_DISTORTION * 0.2, params.BARREL_DISTORTION * 0.8));

    // Branchless Bounds Check
    vec2 bounds = step(abs(p_curved), vec2(0.5));
    float check = bounds.x * bounds.y;
    
    // 2. Quilez Scaling Algorithm
    vec2 texCoord = (p_curved + 0.5) / sc;
    vec2 q_p = texCoord * params.SourceSize.xy;
    vec2 q_i = floor(q_p) + 0.5;
    vec2 q_f = q_p - q_i;
    vec2 q_final = (q_i + 4.0 * q_f * q_f * q_f) / params.SourceSize.xy;
    
    vec3 res = texture(Source, q_final).rgb;
    res *= check;

    // 3. ZFast Scanlines
    float pos_y = texCoord.y * params.SourceSize.y;
    float dist = fract(pos_y) - 0.5;
    float Y = dist * dist;
    float scanWeightL = (params.BRIGHTBOOST - params.LOWLUMSCAN * (Y - 1.5 * Y * Y));
    
    // 4. PAS700 Procedural RGB Mask
    float W = floor(params.MASK_W);
    float pos = mod(gl_FragCoord.x, W) / W;
    vec3 mcol = clamp(2.0 - abs(pos * 6.0 - vec3(1.0, 3.0, 5.0)), 0.0, 1.0);
    vec3 mask_rgb = mix(vec3(1.0), mcol, params.MASK_STR);

    // 5. Final Blend
    float luma = dot(res, vec3(0.299, 0.587, 0.114));
    float final_scan = mix(scanWeightL, 1.0, smoothstep(0.1, params.SCAN_FADE_POINT, luma));
    vec3 final_rgb = res * final_scan * mask_rgb;

    FragColor = vec4(clamp(final_rgb, 0.0, 1.0), 1.0);
}
