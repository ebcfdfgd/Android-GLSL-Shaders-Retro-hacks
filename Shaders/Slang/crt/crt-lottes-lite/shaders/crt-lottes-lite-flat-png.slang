#version 450

/* ULTIMATE-TURBO-HYBRID (V19-QUILEZ-FLAT-EDITION)
    - INTEGRATED: Quilez Scaling (Organic Pixel Reconstruction).
    - OPTIMIZED: 100% Branchless (No 'if' conditions).
    - SCANLINES: Lottes Scanline model (Flat Projection).
*/

// --- 1. Parameters ---

#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 2.5 0.05
#pragma parameter MASK_STR "Mask Intensity" 0.45 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width" 6.0 1.0 64.0 1.0
#pragma parameter MASK_H "Mask Height" 2.0 1.0 64.0 1.0
#pragma parameter hardScan "Lottes Scan Hardness" -8.0 -20.0 0.0 1.0
#pragma parameter SCAN_STR "Scanline Intensity" 0.40 0.0 1.0 0.05

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
	float hardScan;
	float SCAN_STR;
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
    // 1. Quilez Scaling (التكبير العضوي فائق النقاء للمنظور المسطح)
    vec2 q_p = TEX0 * params.SourceSize.xy;
    vec2 q_i = floor(q_p) + 0.5;
    vec2 q_f = q_p - q_i;
    vec2 q_final = (q_i + 4.0 * q_f * q_f * q_f) / params.SourceSize.xy;
    
    vec3 res = texture(Source, q_final).rgb;

    // 2. Lottes Scanlines
    float dst = fract(TEX0.y * params.SourceSize.y) - 0.5;
    float scanline = exp2(params.hardScan * dst * dst);
    res = mix(res, res * scanline, params.SCAN_STR);

    // 3. Sharp PNG Mask System
    vec2 mask_size = vec2(floor(params.MASK_W), floor(params.MASK_H));
    vec2 m_uv = (mod(floor(gl_FragCoord.xy), mask_size) + 0.5) / mask_size;
    vec3 mcol = texture(SamplerMask1, m_uv).rgb * 1.5;
    res = mix(res, res * mcol, params.MASK_STR);

    // 4. Final Output
    FragColor = vec4(clamp(res * params.BRIGHT_BOOST, 0.0, 1.0), 1.0);
}
