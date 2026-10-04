#version 450

/* =====================================================
   PURE MATH CRT - ULTRA LIGHTWEIGHT v4.1 
   (Curved + Sharp PNG Mask Edition + good-crt-curve Geometry)
===================================================== */

// --- PARAMETERS ---

#pragma parameter CRT_WARP        "Curvature Amount"        0.10  0.0  0.5  0.01
#pragma parameter CRT_BORDER      "Border Sharpness"        0.02  0.001 0.1  0.001
#pragma parameter VIGNETTE_AMOUNT "Vignette Strength"      0.35  0.0  1.0  0.05
#pragma parameter VIGNETTE_RADIUS "Vignette Radius"        0.9   0.3  1.5  0.05
#pragma parameter BRIGHTNESS      "Brightness Boost"        1.4   1.0  3.0  0.02
#pragma parameter GAMMA           "Gamma Curve Depth"       0.4   0.0  2.0  0.05
#pragma parameter SCAN_LINES      "Scanline Count"          1080.0 240.0 1440.0 10.0
#pragma parameter SCAN_FADE       "Scanline Fade on Brights" 0.8  0.0  1.0  0.05
#pragma parameter MASK_STR        "Mask Intensity"          0.7   0.0  1.0  0.05
#pragma parameter MASK_W          "Mask Width"              6.0   1.0  64.0 1.0
#pragma parameter MASK_H          "Mask Height"             2.0   1.0  64.0 1.0

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
    // 1. Texture Atlas Fix & Coordinate Mapping (from good-crt-curve)
    vec2 frameScale = params.SourceSize.xy / params.SourceSize.xy;
    vec2 framePos = uv / frameScale;

    // 2. CRT Barrel Warp (from good-crt-curve)
    vec2 cc = framePos - 0.5;
    float dist = dot(cc, cc) * params.CRT_WARP;
    vec2 warpedFramePos = framePos + cc * dist;

    // 3. Black Bounds & Smooth Border Mask (from good-crt-curve)
    vec2 edgeDist = min(warpedFramePos, 1.0 - warpedFramePos);
    float inBounds = step(0.0, min(edgeDist.x, edgeDist.y));
    float borderMask = smoothstep(0.0, params.CRT_BORDER, min(edgeDist.x, edgeDist.y));

    vec2 warped_uv = warpedFramePos * frameScale;

    // --- SMOOTH TEXTURE FETCH (Interpolation) ---
    vec2 Q_p = warped_uv * params.SourceSize.xy;
    vec2 Q_i = floor(Q_p) + 0.50;
    vec2 Q_f = Q_p - Q_i;
    vec2 Q_final = (Q_i + 4.0 * Q_f * Q_f * Q_f) / params.SourceSize.xy;
    vec3 res = texture(Source, Q_final).rgb;

    // 4. Vignette (from good-crt-curve)
    float vignetteDist = length(cc) / params.VIGNETTE_RADIUS;
    float vignette = 1.0 - clamp(vignetteDist * vignetteDist, 0.0, 1.0) * params.VIGNETTE_AMOUNT;
    res = res * vignette;

    // Apply Brightness
    res = res * params.BRIGHTNESS;

    // 5. SCANLINE BEAM & FADE (Anti-Moiré Clamped)
    float y_pos = warped_uv.y * params.SCAN_LINES;
    float scan_phase = fract(y_pos);
    
    float scan_beam = 4.0 * scan_phase * (1.0 - scan_phase);
    scan_beam = clamp(scan_beam, 0.25, 1.0); 
    
    float luma = (res.r + res.g + res.b) * 0.333;
    scan_beam = scan_beam + (1.0 - scan_beam) * luma * params.SCAN_FADE;
    res = res * scan_beam;

    // 6. SHARP PNG MASK
    vec2 mask_size = vec2(floor(params.MASK_W), floor(params.MASK_H));
    vec2 m_uv = (mod(floor(gl_FragCoord.xy), mask_size) + 0.5) / mask_size;
    vec3 mcol = texture(SamplerMask1, m_uv).rgb * 1.5;
    res = mix(res, res * mcol, params.MASK_STR);

    // 7. GAMMA S-CURVE
    vec3 s_curve = res * res * (vec3(3.0) - vec3(2.0) * res);
    res = res * (1.0 - params.GAMMA) + s_curve * params.GAMMA;

    // Apply smooth bounds and border mask
    res = res * borderMask * inBounds;

    FragColor = vec4(res, 1.0);
}
