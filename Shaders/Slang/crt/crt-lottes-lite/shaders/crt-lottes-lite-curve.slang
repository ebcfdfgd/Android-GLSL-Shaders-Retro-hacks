#version 450

/* 777-LITE-TURBO-V4-QUILEZ-LOTTES + PAS700 MASK
    - INTEGRATED: Quilez Scaling (Organic Pixel Reconstruction).
    - SCANLINES: Lottes Scanline model.
    - MASK: PAS700 Procedural Aperture Grille.
    - PERFORMANCE: Branchless math.
*/

#pragma parameter BARREL_DISTORTION "Screen Curve" 0.15 0.0 1.0 0.02
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.20 1.0 2.0 0.01
#pragma parameter VIG_STR "Vignette Intensity" 0.15 0.0 2.0 0.05
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
	float BARREL_DISTORTION;
	float BRIGHT_BOOST;
	float VIG_STR;
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
layout(location = 1) out vec2 screen_scale;

void main() {
    uv = TexCoord;
    screen_scale = params.SourceSize.xy / params.SourceSize.xy; 
    gl_Position = global.MVP * Position;
}

#pragma stage fragment
layout(location = 0) in vec2 uv;
layout(location = 1) in vec2 screen_scale;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main() {
    // 1. Coordinates & Curve
    vec2 p = (uv * screen_scale) - 0.5;
    float r2 = dot(p, p);
    vec2 p_curved = p * (1.0 + r2 * vec2(params.BARREL_DISTORTION * 0.2, params.BARREL_DISTORTION * 0.8));
    
    // 2. Quilez Scaling (Integrated)
    vec2 tex_uv = (p_curved + 0.5) / screen_scale;
    vec2 q_p = tex_uv * params.SourceSize.xy;
    vec2 q_i = floor(q_p) + 0.5;
    vec2 q_f = q_p - q_i;
    vec2 q_final = (q_i + 4.0 * q_f * q_f * q_f) / params.SourceSize.xy;
    
    vec3 res = texture(Source, q_final).rgb;

    // 3. Branchless Bounds Check
    vec2 bounds = step(abs(p_curved), vec2(0.5));
    float check = bounds.x * bounds.y;

    // 4. LOTTES SCANLINES
    float dst = fract(tex_uv.y * params.SourceSize.y) - 0.5;
    float scanline = exp2(params.hardScan * dst * dst);
    res = mix(res, res * scanline, params.SCAN_STR);

    // 5. RGB Mask (PAS700)
    if (params.MASK_STR > 0.01) {
        float W = floor(params.MASK_W);
        float pos = mod(gl_FragCoord.x, W) / W;
        vec3 mcol = clamp(2.0 - abs(pos * 6.0 - vec3(1.0, 3.0, 5.0)), 0.0, 1.0);
        res = mix(res, res * mcol, params.MASK_STR);
    }

    // 6. Final Polish
    res *= params.BRIGHT_BOOST;
    res *= (1.0 - r2 * params.VIG_STR);

    FragColor = vec4(res * check, 1.0);
}
