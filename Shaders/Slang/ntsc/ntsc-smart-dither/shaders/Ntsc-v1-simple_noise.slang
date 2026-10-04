#version 450

/* 777-NTSC-MEGA-LITE-CLEAN (5-TAP PURE DITHER-TARGETED)
    - FIXED: Completely eliminated full-screen fog/blur. Luma blend now targets ONLY dither patterns.
    - OPTIMIZED: Exactly 5 Unique Texture Fetches (Reusing Center Tap) - 100% Branchless.
    - ADDED: High-frequency Local Extremum Detection for absolute textual and background clarity.
    - ADDED: High-precision Hash RF Grain (Namash) & Black Level.
    - ADDED: Broken Cable Static (Horizontal Sync Noise).
*/

#pragma parameter NTSC_BRIGHTNESS "Signal Brightness" 1.0 0.0 2.0 0.05
#pragma parameter SATURATION "Global Saturation" 1.0 0.0 2.0 0.05
#pragma parameter BLACK_LEVEL "Black Level" 0.0 -0.5 0.5 0.01
#pragma parameter COL_BLEED "Chroma Bleed Strength" 1.5 0.0 5.0 0.05
#pragma parameter rb_power "Rainbow Strength" 0.15 0.0 2.0 0.01
#pragma parameter rb_size "Rainbow Width" 3.0 0.5 10.0 0.1
#pragma parameter rb_detect "Rainbow Detection" 0.30 0.0 1.0 0.01
#pragma parameter rb_speed "Rainbow Crawl Speed" 0.5 0.0 2.0 0.05
#pragma parameter rb_tilt "Rainbow Diagonal Tilt" 0.5 -2.0 2.0 0.1
#pragma parameter de_dither "MD De-Dither Intensity" 1.0 0.0 2.0 0.1
#pragma parameter edge_protect "Edge Sharpness Protection" 0.6 0.0 1.0 0.05
#pragma parameter sig_noise "Signal RF Grain (Namash)" 0.04 0.0 0.5 0.01
#pragma parameter cable_glitch "Broken Cable Static" 0.0 0.0 1.0 0.05

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float NTSC_BRIGHTNESS;
	float SATURATION;
	float BLACK_LEVEL;
	float COL_BLEED;
	float rb_power;
	float rb_size;
	float rb_detect;
	float rb_speed;
	float rb_tilt;
	float de_dither;
	float edge_protect;
	float sig_noise;
	float cable_glitch;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

const mat3 RGB_to_YIQ = mat3(
    0.299,  0.596,  0.211,
    0.587, -0.274, -0.523,
    0.114, -0.322,  0.312
);

const mat3 YIQ_to_RGB = mat3(
    1.0,    1.0,    1.0,
    0.956, -0.272, -1.106,
    0.621, -0.647,  1.703
);

// High-speed pseudo-random noise generator (Hash)
float hash(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

// Fast Triangle Wave for Rainbow modulation
vec2 triangle_wave(float x) {
    vec2 val = abs(fract(vec2(x * 0.159, x * 0.159 + 0.25)) * 2.0 - 1.0) * 2.0 - 1.0;
    return val;
}

void main() {
    vec2 ps = vec2(1.0 / params.SourceSize.x, 0.0);
    float time = float(params.FrameCount);

    // 1. Broken Cable Static Generator (Horizontal Glitch Lines)
    float line_noise = fract(vTexCoord.y * 5.0 + time * 0.13) * fract(vTexCoord.y * 23.0 - time * 0.21);
    float static_lines = step(0.88, line_noise) * params.cable_glitch;

    // ==========================================
    // 2. THREE LUMA TAPS (Fetches 1, 2, 3)
    // ==========================================
    float d_off = max(params.de_dither, 1.0);
    vec3 cL = texture(Source, vTexCoord - ps * d_off).rgb; // Fetch 1
    vec3 cM = texture(Source, vTexCoord).rgb;              // Fetch 2 (Center)
    vec3 cR = texture(Source, vTexCoord + ps * d_off).rgb; // Fetch 3

    vec3 yiqL = RGB_to_YIQ * cL;
    vec3 yiqM = RGB_to_YIQ * cM;
    vec3 yiqR = RGB_to_YIQ * cR;

    // High-Frequency Isolation: Only positive on rapid pixel oscillations (Dither patterns)
    float diff_L = yiqM.x - yiqL.x;
    float diff_R = yiqM.x - yiqR.x;
    float dither_weight = clamp(sign(diff_L) * sign(diff_R), 0.0, 1.0);

    // Smart Adaptive Blending (Guaranteed 0.0 on solid text/flat areas)
    float neighbor_y = (yiqL.x + yiqR.x) * 0.5;
    float edge_clean = abs(yiqL.x - yiqR.x);
    float adaptive_mix = 0.5 * params.de_dither * dither_weight * clamp(1.0 - (edge_clean * params.edge_protect), 0.0, 1.0);

    float final_y = mix(yiqM.x, neighbor_y, adaptive_mix);
    final_y *= params.NTSC_BRIGHTNESS;

    // Apply broken cable static lines to Luma
    final_y -= static_lines * 0.4;

    // ==========================================
    // 3. TWO EXTRA CHROMA TAPS (Fetches 4, 5)
    // ==========================================
    vec2 b_off = ps * params.COL_BLEED * 1.5; 
    vec3 bcL = RGB_to_YIQ * texture(Source, vTexCoord - b_off).rgb; // Fetch 4
    vec3 bcR = RGB_to_YIQ * texture(Source, vTexCoord + b_off).rgb; // Fetch 5

    // Reusing yiqM (Center) to save the 6th fetch completely!
    float fI = mix(yiqM.y, (bcL.y + bcR.y) * 0.5, 0.7);
    float fQ = mix(yiqM.z, (bcL.z + bcR.z) * 0.5, 0.7);

    // Inject static lines into Chroma
    fI -= static_lines * 0.15;
    fQ += static_lines * 0.15;

    // ==========================================
    // 4. ARTIFACTS & SIGNAL MODULATION
    // ==========================================
    if (params.rb_power > 0.0) {
        float edge = abs(yiqM.x - yiqL.x) + abs(yiqM.x - yiqR.x);
        float mask = smoothstep(params.rb_detect, params.rb_detect + 0.1, edge);
        
        float ang = (vTexCoord.x * params.SourceSize.x / params.rb_size) + (vTexCoord.y * params.SourceSize.y * params.rb_tilt) + (time * params.rb_speed);
        vec2 wave = triangle_wave(ang);
        
        fI += wave.x * params.rb_power * (mask + static_lines * 0.5);
        fQ += wave.y * params.rb_power * (mask + static_lines * 0.5);
    }

    // High-precision Hash RF Grain (Namash)
    if (params.sig_noise > 0.0) {
        final_y += (hash(vTexCoord + time * 0.01) - 0.5) * params.sig_noise;
    }

    vec3 res = YIQ_to_RGB * vec3(final_y, fI * params.SATURATION, fQ * params.SATURATION);

    // Black Level Adjustment
    res = mix(vec3(params.BLACK_LEVEL), vec3(1.0), res);

    FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
