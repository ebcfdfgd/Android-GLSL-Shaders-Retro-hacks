#version 110

/* SUPER-ULTIMATE-PASS (Turbo Bright Edition)
   - Fixed: Brightness logic to prevent darkening.
   - Balanced: Contrast and Linear space transition.
*/

// --- 1. NTSC & RAINBOW PARAMETERS ---
#pragma parameter ntsc_hue "NTSC Color Hue" 0.0 -3.14 3.14 0.05
#pragma parameter COL_BLEED "Chroma Bleed Strength" 1.3 0.0 5.0 0.05
#pragma parameter rb_power "Rainbow Strength" 0.10 0.0 2.0 0.01
#pragma parameter rb_size "Rainbow Width" 4.5 0.5 10.0 0.1
#pragma parameter rb_detect "Rainbow Detection" 0.40 0.0 1.0 0.01
#pragma parameter rb_speed "Rainbow Crawl Speed" 0.1 0.0 2.0 0.05
#pragma parameter rb_tilt "Rainbow Diagonal Tilt" 0.0 -2.0 2.0 0.1
#pragma parameter de_dither "MD De-Dither Intensity" 1.0 0.0 2.0 0.1
#pragma parameter ntsc_grain "Signal Grain (RF Noise)" 0.0 0.0 0.20 0.01
#pragma parameter tv_mist "TV Signal Mist (Blur)" 0.1 0.0 1.5 0.05

// --- 2. COLOR PRO-E PARAMETERS ---
#pragma parameter CLU_R_GAIN "Red Channel Gain" 1.0 0.0 2.0 0.02
#pragma parameter CLU_G_GAIN "Green Channel Gain" 1.0 0.0 2.0 0.02
#pragma parameter CLU_B_GAIN "Blue Channel Gain" 1.0 0.0 2.0 0.02
#pragma parameter CLU_CONTRAST "CRT Contrast" 1.0 0.5 2.0 0.05
#pragma parameter CLU_SATURATION "CRT Saturation" 1.3 0.0 2.0 0.05
#pragma parameter CLU_BRIGHT "CRT Brightness" 1.0 0.5 2.5 0.05
#pragma parameter CLU_GLOW "CRT Glow Strength" 0.15 0.0 1.5 0.05
#pragma parameter CLU_HALATION "CRT Halation Strength" 0.15 0.0 1.0 0.02
#pragma parameter CLU_BLK_D "CRT Black Depth" 0.10 0.0 1.0 0.05

// --- 3. SCREEN & MASK PARAMETERS ---
#pragma parameter BARREL_DISTORTION "Screen Curve" 0.15 0.0 0.3 0.01
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.15 1.0 2.5 0.05
#pragma parameter VIG_STR "Vignette Intensity" 0.15 0.0 2.0 0.05
#pragma parameter SCAN_STR "Scanline Intensity" 0.35 0.0 1.0 0.05
#pragma parameter SCAN_SIZE "Scanline Size" 5.0 1.0 10.0 0.5
#pragma parameter MASK_STR "Mask Strength" 0.1 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width" 3.0 1.0 10.0 1.0

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 vTexCoord;
varying float time;
uniform mat4 MVPMatrix;
uniform int FrameCount;
void main() {
   gl_Position = MVPMatrix * VertexCoord;
   vTexCoord = TexCoord;
   time = float(FrameCount);
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif
uniform sampler2D Texture;
uniform vec2 TextureSize, InputSize;
varying vec2 vTexCoord;
varying float time;

#ifdef PARAMETER_UNIFORM
uniform float ntsc_hue, COL_BLEED, rb_power, rb_size, rb_detect, rb_speed, rb_tilt, de_dither, ntsc_grain, tv_mist;
uniform float CLU_R_GAIN, CLU_G_GAIN, CLU_B_GAIN, CLU_CONTRAST, CLU_SATURATION, CLU_BRIGHT, CLU_GLOW, CLU_HALATION, CLU_BLK_D;
uniform float BARREL_DISTORTION, BRIGHT_BOOST, VIG_STR, SCAN_STR, SCAN_SIZE, MASK_STR, MASK_W;
#endif

float rand(vec2 co) { return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453); }

void main() {
    vec2 sc = TextureSize / InputSize;
    vec2 p = (vTexCoord * sc) - 0.5;
    vec2 p_curved;
    p_curved.x = p.x * (1.0 + (p.y * p.y) * (BARREL_DISTORTION * 0.2));
    p_curved.y = p.y * (1.0 + (p.x * p.x) * (BARREL_DISTORTION * 0.8));
    p_curved *= (1.0 - 0.1 * BARREL_DISTORTION);
    vec2 uv = (p_curved + 0.5) / sc;

    if (abs(p_curved.x) > 0.5 || abs(p_curved.y) > 0.5) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0); return;
    }

    vec2 ps = 1.0 / TextureSize;
    float bleed = ps.x * COL_BLEED * 2.0;

    vec3 col_m = texture2D(Texture, uv).rgb;
    vec3 col_l = texture2D(Texture, uv - vec2(ps.x * de_dither, 0.0)).rgb;
    vec3 col_r = texture2D(Texture, uv + vec2(ps.x * de_dither, 0.0)).rgb;
    vec3 col_chrL = texture2D(Texture, uv - vec2(bleed, 0.0)).rgb;
    vec3 col_chrR = texture2D(Texture, uv + vec2(bleed, 0.0)).rgb;

    mat3 RGBtoYIQ = mat3(0.2989, 0.5870, 0.1140, 0.5959, -0.2744, -0.3216, 0.2115, -0.5229, 0.3114);
    mat3 YIQtoRGB = mat3(1.0, 0.956, 0.6210, 1.0, -0.2720, -0.6474, 1.0, -1.1060, 1.7046);
    
    vec3 yiq = mix(col_m, (col_l + col_r) * 0.5, 0.4 * tv_mist) * RGBtoYIQ;
    yiq.gb = mix(yiq.gb, ((col_chrL * RGBtoYIQ).gb + (col_chrR * RGBtoYIQ).gb) * 0.5, 0.5);

    float edge = abs(yiq.r - (col_l * RGBtoYIQ).r) + abs(yiq.r - (col_r * RGBtoYIQ).r);
    float angle = (uv.x * TextureSize.x / rb_size) + (uv.y * TextureSize.y * rb_tilt) + (time * rb_speed) + ntsc_hue;
    yiq.gb += vec2(sin(angle), cos(angle)) * rb_power * smoothstep(rb_detect, rb_detect + 0.2, edge);

    vec3 res = max(yiq * YIQtoRGB, 0.0);
    res += (rand(uv * time) - 0.5) * ntsc_grain;

    // --- تصحيح محرك الإضاءة (Corrected Brightness Logic) ---
    res = pow(res, vec3(2.2)); // تحويل أدق للـ Linear
    res *= vec3(CLU_R_GAIN, CLU_G_GAIN, CLU_B_GAIN);
    
    // التباين أولاً ثم السطوع لضمان عدم الغمق
    res = (res - 0.5) * CLU_CONTRAST + 0.5;
    res *= CLU_BRIGHT; 

    float luma = dot(res, vec3(0.299, 0.587, 0.114));
    res = mix(vec3(luma), res, CLU_SATURATION);
    
    // Glow & Halation
    float glow_map = smoothstep(0.4, 0.9, luma);
    res += res * glow_map * CLU_GLOW;
    res += vec3(CLU_HALATION * glow_map, 0.0, 0.0);
    res = max(res - CLU_BLK_D * 0.05, 0.0);
    
    res = pow(max(res, 0.0), vec3(1.0/2.2)); // إرجاع الـ Gamma

    // النهائية
    res *= BRIGHT_BOOST;
    res *= (1.0 - dot(p_curved, p_curved) * VIG_STR);

    float scanline = sin(uv.y * TextureSize.y * SCAN_SIZE) * 0.5 + 0.5;
    res *= mix(1.0, scanline, SCAN_STR);
    
    float mask = mod(gl_FragCoord.x, MASK_W);
    if (mask < MASK_W/3.0) res.rb *= (1.0 - MASK_STR);
    else if (mask < (MASK_W/3.0)*2.0) res.gb *= (1.0 - MASK_STR);
    else res.rg *= (1.0 - MASK_STR);

    gl_FragColor = vec4(res, 1.0);
}
#endif