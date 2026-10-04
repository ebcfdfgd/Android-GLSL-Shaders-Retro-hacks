#version 450

/* ULTIMATE-TURBO-HYBRID (V20-QUILEZ-PURE-FLAT)
    - INTEGRATED: Quilez Scaling for organic clarity.
    - SCANLINES: Zfast Pixel-Sync with Smart Fade.
    - MASK: Exact manual PNG texture control.
*/

#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.25 0.5 2.0 0.05
#pragma parameter MASK_STR "Mask Intensity (0=OFF)" 0.45 0.0 1.0 0.05
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
    // 1. Quilez Scaling (سحب اللون فائق النقاء بدلاً من السحب الخطي)
    vec2 q_p = TEX0 * params.SourceSize.xy;
    vec2 q_i = floor(q_p) + 0.5;
    vec2 q_f = q_p - q_i;
    vec2 final_uv = (q_i + 4.0 * q_f * q_f * q_f) / params.SourceSize.xy;

    vec3 res = texture(Source, final_uv).rgb;

    // 2. Zfast Pixel-Sync Scanlines
    float pos_y = TEX0.y * params.SourceSize.y;
    float dist = fract(pos_y) - 0.5;
    float Y = dist * dist;
    float YY = Y * Y;

    float scanWeightL = (params.BRIGHT_BOOST - params.LOWLUMSCAN * (Y - 1.5 * YY));

    float luma = dot(res, vec3(0.299, 0.587, 0.114));
    float final_scan = mix(scanWeightL, 1.0, smoothstep(0.1, params.SCAN_FADE_POINT, luma));
    res *= final_scan;

    // 3. Sharp PNG Mask System
    vec2 mask_size = vec2(floor(params.MASK_W), floor(params.MASK_H));
    vec2 repeated_coord = mod(floor(gl_FragCoord.xy), mask_size);
    vec2 m_uv = (repeated_coord + 0.5) / mask_size;
    
    vec3 mcol = texture(SamplerMask1, m_uv).rgb * 1.5;
    res = mix(res, res * mcol, params.MASK_STR);

    // 4. Final Stage
    FragColor = vec4(clamp(res * params.BRIGHT_BOOST, 0.0, 1.0), 1.0);
}
