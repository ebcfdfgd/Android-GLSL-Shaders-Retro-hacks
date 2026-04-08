#version 110

/* ULTIMATE-CRT-BUNDLE-V1
   - Unified Shader: NTSC + Color Adjust + CRT Mask.
   - All features preserved from 3 sources.
   - Performance optimized for v110.
*/

// --- 1. NTSC Parameters ---
#pragma parameter ntsc_res "NTSC: Resolution" 0.0 -1.0 1.0 0.05
#pragma parameter ntsc_sharp "NTSC: Sharpness Boost" 0.1 -1.0 1.0 0.05
#pragma parameter fring "NTSC: Edge Fringing" 0.0 0.0 1.0 0.05
#pragma parameter afacts "NTSC: Artifact Intensity" 0.0 0.0 1.0 0.05
#pragma parameter ntsc_hue "NTSC Color Hue (Cyan Fix)" 0.0 -3.14 3.14 0.05
#pragma parameter COL_BLEED "Chroma Bleed Strength" 1.0 0.0 5.0 0.05
#pragma parameter rb_power "Rainbow Strength" 0.15 0.0 2.0 0.01
#pragma parameter rb_size "Rainbow Width" 3.0 0.5 10.0 0.1
#pragma parameter rb_detect "Rainbow Detection" 0.30 0.0 1.0 0.01
#pragma parameter rb_speed "Rainbow Crawl Speed" 0.5 0.0 2.0 0.05
#pragma parameter rb_tilt "Rainbow Diagonal Tilt" 0.5 -2.0 2.0 0.1
#pragma parameter de_dither "MD De-Dither Intensity" 1.0 0.0 2.0 0.1
#pragma parameter ntsc_grain "Signal Grain (RF Noise)" 0.01 0.0 0.20 0.01
#pragma parameter tv_mist "TV Signal Mist (Blur)" 0.1 0.0 1.5 0.05

// --- 2. Color Adjustment Parameters ---
#pragma parameter CLU_R_GAIN "Red Channel Gain" 1.0 0.0 2.0 0.02
#pragma parameter CLU_G_GAIN "Green Channel Gain" 1.0 0.0 2.0 0.02
#pragma parameter CLU_B_GAIN "Blue Channel Gain" 1.0 0.0 2.0 0.02
#pragma parameter CLU_CONTRAST "CRT Contrast" 1.10 0.5 2.0 0.05
#pragma parameter CLU_SATURATION "CRT Saturation" 1.3 0.0 2.0 0.05
#pragma parameter CLU_GLOW "CRT Glow Strength" 0.15 0.0 1.5 0.05
#pragma parameter CLU_HALATION "CRT Halation Strength" 0.15 0.0 1.0 0.02
#pragma parameter CLU_BLK_D "CRT Black Depth" 0.20 0.0 1.0 0.05

// --- 3. CRT Mask & Geometry Parameters ---
#pragma parameter BARREL_DISTORTION "Screen Curve" 0.15 0.0 0.3 0.01
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.05 1.0 2.5 0.05
#pragma parameter VIG_STR "Vignette Intensity" 0.15 0.0 2.0 0.05
#pragma parameter SCAN_STR "Scanline Intensity" 0.35 0.0 1.0 0.05
#pragma parameter SCAN_SIZE "Scanline Size (Zoom)" 5.0 1.0 10.0 0.5
#pragma parameter MASK_TYPE "Mask Type: 0.Balanced|1.6x4 Custom" 0.0 0.0 1.0 1.0
#pragma parameter MASK_STR "Mask Strength" 0.15 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width (Option 0 only)" 3.0 1.0 10.0 1.0

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv;
varying vec2 vTexCoord;
varying vec2 hue_trig; 
uniform mat4 MVPMatrix;

#ifdef PARAMETER_UNIFORM
uniform float ntsc_hue;
#endif

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    uv = TexCoord;
    vTexCoord = TexCoord;
    hue_trig = vec2(cos(ntsc_hue), sin(ntsc_hue)); // [cite: 47]
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 uv;
varying vec2 vTexCoord;
varying vec2 hue_trig;
uniform sampler2D Texture;
uniform vec2 TextureSize, InputSize;
uniform int FrameCount;

#ifdef PARAMETER_UNIFORM
// NTSC
uniform float ntsc_res, ntsc_sharp, fring, afacts, COL_BLEED, rb_power, rb_size, rb_detect, rb_speed, rb_tilt, de_dither, ntsc_grain, tv_mist;
// Color Adjustment
uniform float CLU_R_GAIN, CLU_G_GAIN, CLU_B_GAIN, CLU_CONTRAST, CLU_SATURATION, CLU_GLOW, CLU_HALATION, CLU_BLK_D;
// CRT Mask
uniform float BARREL_DISTORTION, BRIGHT_BOOST, VIG_STR, SCAN_STR, SCAN_SIZE, MASK_STR, MASK_W, MASK_TYPE;
#endif

// Noise helper [cite: 50]
float noise(vec2 co) {
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

mat3 RGBtoYIQ = mat3(0.2989, 0.5870, 0.1140, 0.5959, -0.2744, -0.3216, 0.2115, -0.5229, 0.3114); // [cite: 51]
mat3 YIQtoRGB = mat3(1.0, 0.956, 0.6210, 1.0, -0.2720, -0.6474, 1.0, -1.1060, 1.7046); // [cite: 52]

void main() {
    // --- PART 1: GEOMETRY (Curve) --- [cite: 8]
    vec2 sc = TextureSize / InputSize;
    vec2 p = (uv * sc) - 0.5;
    float ky = BARREL_DISTORTION * 0.8; 
    vec2 p_curved;
    p_curved.x = p.x * (1.0 + (p.y * p.y) * (BARREL_DISTORTION * 0.2));
    p_curved.y = p.y * (1.0 + (p.x * p.x) * ky);
    p_curved *= (1.0 - 0.1 * BARREL_DISTORTION);

    if (abs(p_curved.x) > 0.5 || abs(p_curved.y) > 0.5) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }
    vec2 final_uv = (p_curved + 0.5) / sc;

    // --- PART 2: NTSC PROCESSING --- [cite: 44, 53]
    float res_step = 1.0 - (ntsc_res * 0.5);
    vec2 ps = vec2(res_step / TextureSize.x, 1.0 / TextureSize.y);
    float time = float(FrameCount);

    vec3 col_m = texture2D(Texture, final_uv).rgb;
    vec3 col_l = texture2D(Texture, final_uv - vec2(ps.x * de_dither, 0.0)).rgb;
    vec3 col_r = texture2D(Texture, final_uv + vec2(ps.x * de_dither, 0.0)).rgb;
    float bleed_offset = ps.x * COL_BLEED * 2.0;
    vec3 col_chrL = texture2D(Texture, final_uv - vec2(bleed_offset, 0.0)).rgb;
    vec3 col_chrR = texture2D(Texture, final_uv + vec2(bleed_offset, 0.0)).rgb;

    vec3 col = mix(col_m, (col_l + col_r) * 0.5, 0.4);
    vec3 yiq = col * RGBtoYIQ;
    float lumaL = (col_l * RGBtoYIQ).r;
    float lumaR = (col_r * RGBtoYIQ).r;
    vec2 chrL = (col_chrL * RGBtoYIQ).gb;
    vec2 chrR = (col_chrR * RGBtoYIQ).gb;
    vec2 mixed_chroma = mix(yiq.gb, (chrL + chrR) * 0.5, 0.5);

    float edge = abs(yiq.r - lumaL) + abs(yiq.r - lumaR);
    float rb_mask = smoothstep(rb_detect, rb_detect + 0.2, edge);
    float angle = (final_uv.x * TextureSize.x / rb_size) + (final_uv.y * TextureSize.y * rb_tilt) + (time * rb_speed);
    float total_rb = rb_power + (afacts * 0.5);
    float rainbowI = sin(angle) * total_rb * rb_mask;
    float rainbowQ = cos(angle) * total_rb * rb_mask;

    float y = yiq.r + (yiq.r - lumaL) * (ntsc_sharp * 0.6);
    float final_y = mix(y, (lumaL + y + lumaR) * 0.333, tv_mist);
    final_y += (noise(final_uv + mod(time, 60.0)) - 0.5) * ntsc_grain;

    float fI = mixed_chroma.x + rainbowI + (yiq.r - lumaR) * fring * 0.3;
    float fQ = mixed_chroma.y + rainbowQ - (yiq.r - lumaL) * fring * 0.3;
    float hueI = fI * hue_trig.x - fQ * hue_trig.y;
    float hueQ = fI * hue_trig.y + fQ * hue_trig.x;
    vec3 ntsc_res_rgb = vec3(final_y, hueI, hueQ) * YIQtoRGB;

    // --- PART 3: COLOR ADJUSTMENT (CLU) --- [cite: 36, 41]
    vec3 clu_res = ntsc_res_rgb * ntsc_res_rgb; // Linearize
    clu_res *= vec3(CLU_R_GAIN, CLU_G_GAIN, CLU_B_GAIN);
    clu_res = (clu_res - 0.5) * CLU_CONTRAST + 0.5;
    float clu_luma = dot(clu_res, vec3(0.25, 0.5, 0.25));
    clu_res = mix(vec3(clu_luma), clu_res, CLU_SATURATION);
    clu_res *= (1.0 - CLU_BLK_D * (1.0 - clu_luma));
    
    vec3 glow_mask = pow(max(clu_res, 0.0), vec3(4.0));
    clu_res += glow_mask * (CLU_GLOW + glow_mask * CLU_HALATION);

    // --- PART 4: CRT MASK & FINAL TOUCHES --- [cite: 13, 14, 16]
    clu_res *= BRIGHT_BOOST;
    clu_res *= (1.0 - dot(p_curved, p_curved) * VIG_STR); // Vignette

    float scanline = sin(gl_FragCoord.y * (6.28318 / SCAN_SIZE)) * 0.5 + 0.5;
    clu_res *= mix(1.0, scanline, SCAN_STR);

    vec3 mcol = vec3(1.0);
    if (MASK_TYPE < 0.5) {
        float W = floor(MASK_W);
        float pos = mod(gl_FragCoord.x, W);
        mcol.r = clamp(2.0 - abs((pos / W) * 6.0 - 1.0), 0.6, 1.6);
        mcol.g = clamp(2.0 - abs((pos / W) * 6.0 - 3.0), 0.6, 1.6);
        mcol.b = clamp(2.0 - abs((pos / W) * 6.0 - 5.0), 0.6, 1.6);
    } else {
        int px = int(mod(gl_FragCoord.x, 6.0));
        int py = int(mod(gl_FragCoord.y, 4.0));
        mcol = vec3(0.0);
        if (py == 0 || py == 2) {
            if (mod(float(px), 3.0) < 1.0) mcol = vec3(1.0, 0.0, 0.0);
            else if (mod(float(px), 3.0) < 2.0) mcol = vec3(0.0, 1.0, 0.0);
            else mcol = vec3(0.0, 0.0, 1.0);
        } else if (py == 1) {
            if (px >= 3) {
                if (px == 3) mcol = vec3(1.0, 0.0, 0.0);
                else if (px == 4) mcol = vec3(0.0, 1.0, 0.0);
                else mcol = vec3(0.0, 0.0, 1.0);
            }
        } else if (py == 3) {
            if (px < 3) {
                if (px == 0) mcol = vec3(1.0, 0.0, 0.0);
                else if (px == 1) mcol = vec3(0.0, 1.0, 0.0);
                else mcol = vec3(0.0, 0.0, 1.0);
            }
        }
        mcol *= 1.8;
    }

    clu_res = mix(clu_res, clu_res * mcol, MASK_STR);

    // Final Gamma Output [cite: 43]
    gl_FragColor = vec4(sqrt(max(clu_res, 0.0)), 1.0);
}
#endif