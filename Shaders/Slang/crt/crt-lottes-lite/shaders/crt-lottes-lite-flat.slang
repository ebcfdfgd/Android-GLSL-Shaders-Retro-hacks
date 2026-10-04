#version 450

/* 777-LITE-TURBO-V4-QUILEZ-FLAT-LOTTES + PAS700 MASK
    - INTEGRATED: Quilez Scaling for perfect pixel reconstruction.
    - SCANLINES: Lottes Scanline model (Flat Projection).
    - MASK: PAS700 Procedural Aperture Grille.
    - OPTIMIZED: 100% Branchless (No 'if' conditions).
*/

#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.20 1.0 2.0 0.01
#pragma parameter hardScan "Lottes Scan Hardness" -8.0 -20.0 0.0 1.0
#pragma parameter SCAN_STR "Scanline Intensity" 0.40 0.0 1.0 0.05
#pragma parameter MASK_STR "Mask Strength" 0.20 0.0 1.0 0.05
#pragma parameter MASK_W "PAS700 Mask Width" 6.0 1.0 16.0 1.0

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float BRIGHT_BOOST;
	float hardScan;
	float SCAN_STR;
	float MASK_STR;
	float MASK_W;
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
    // 1. Quilez Scaling (سحب بكسلات دقيق جداً للمنظور المسطح)
    vec2 q_p = uv * params.SourceSize.xy;
    vec2 q_i = floor(q_p) + 0.5;
    vec2 q_f = q_p - q_i;
    vec2 q_final = (q_i + 4.0 * q_f * q_f * q_f) / params.SourceSize.xy;
    
    vec3 res = texture(Source, q_final).rgb;

    // 2. Lottes Scanlines
    float dst = fract(uv.y * params.SourceSize.y) - 0.5;
    float scanline = exp2(params.hardScan * dst * dst);
    res = mix(res, res * scanline, params.SCAN_STR);

    // 3. RGB Mask (PAS700 - Branchless)
    float W = floor(params.MASK_W);
    float pos = mod(gl_FragCoord.x, W) / W;
    vec3 mcol = clamp(2.0 - abs(pos * 6.0 - vec3(1.0, 3.0, 5.0)), 0.0, 1.0);
    res = mix(res, res * mcol, params.MASK_STR);

    // 4. Final Polish
    res *= params.BRIGHT_BOOST;

    FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
