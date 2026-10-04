#version 450

/* =====================================================
   PURE MATH CRT - ULTRA LIGHTWEIGHT v4.1 
   (Curved + Sharp PNG Mask Edition)
===================================================== */

// --- PARAMETERS ---

#pragma parameter CURVATURE "CRT Curvature 1:1" 0.15 0.0 1.0 0.01
#pragma parameter VIG_STRENGTH "Vignette Strength" 0.5 0.0 2.0 0.1
#pragma parameter BRIGHTNESS "Brightness Boost" 1.4 1.0 3.0 0.02
#pragma parameter GAMMA "Gamma Curve Depth" 0.4 0.0 2.0 0.05
#pragma parameter SCAN_LINES "Scanline Count" 1080.0 240.0 1440.0 10.0
#pragma parameter SCAN_FADE "Scanline Fade on Brights" 0.8 0.0 1.0 0.05
#pragma parameter MASK_STR "Mask Intensity" 0.7 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width" 6.0 1.0 64.0 1.0
#pragma parameter MASK_H "Mask Height" 2.0 1.0 64.0 1.0

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float CURVATURE;
	float VIG_STRENGTH;
	float BRIGHTNESS;
	float GAMMA;
	float SCAN_LINES;
	float SCAN_FADE;
	float MASK_STR;
	float MASK_W;
	float MASK_H;
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
layout(set = 0, binding = 3) uniform sampler2D SamplerMask1;

void main() {
    // 1. PERFECT CENTERED CURVATURE
    vec2 sc = params.SourceSize.xy / params.SourceSize.xy;
    vec2 p = (uv * sc) - 0.5; 
    
    float r2 = (p.x * p.x) + (p.y * p.y);
    vec2 p_curved = p * (1.0 + r2 * params.CURVATURE * 2.0);
    p_curved = p_curved / (1.0 + params.CURVATURE * 0.6);

    vec2 warped_uv = (p_curved + 0.5) / sc;
    vec2 bounds = step(abs(p_curved), vec2(0.5));
    float edge_mask = bounds.x * bounds.y;

    // --- SMOOTH TEXTURE FETCH (Interpolation) ---
    vec2 Q_p = warped_uv * params.SourceSize.xy;
    vec2 Q_i = floor(Q_p) + 0.50;
    vec2 Q_f = Q_p - Q_i;
    vec2 Q_final = (Q_i + 4.0 * Q_f * Q_f * Q_f) / params.SourceSize.xy;
    vec3 res = texture(Source, Q_final).rgb;

    // Vignette
    float vignette = 1.0 - (r2 * params.VIG_STRENGTH * 2.0);
    res = res * vignette;

    // Apply Brightness
    res = res * params.BRIGHTNESS;

    // 2. SCANLINE BEAM & FADE (Anti-Moiré Clamped)
    float y_pos = warped_uv.y * params.SCAN_LINES;
    float scan_phase = fract(y_pos);
    
    // Smooth calculation with clamp to prevent black-flicker (Moiré)
    float scan_beam = 4.0 * scan_phase * (1.0 - scan_phase);
    scan_beam = clamp(scan_beam, 0.25, 1.0); 
    
    float luma = (res.r + res.g + res.b) * 0.333;
    scan_beam = scan_beam + (1.0 - scan_beam) * luma * params.SCAN_FADE;
    res = res * scan_beam;

    // 3. SHARP PNG MASK
    vec2 mask_size = vec2(floor(params.MASK_W), floor(params.MASK_H));
    vec2 m_uv = (mod(floor(gl_FragCoord.xy), mask_size) + 0.5) / mask_size;
    vec3 mcol = texture(SamplerMask1, m_uv).rgb * 1.5;
    res = mix(res, res * mcol, params.MASK_STR);

    // 4. GAMMA S-CURVE
    vec3 s_curve = res * res * (vec3(3.0) - vec3(2.0) * res);
    res = res * (1.0 - params.GAMMA) + s_curve * params.GAMMA;

    // Apply edge mask
    res = res * edge_mask;

    FragColor = vec4(res, 1.0);
}
