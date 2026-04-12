#version 130

/* NTSC MEGA LITE + RAINBOW (Version 130 Build)
   - Feature: Chroma Bleed (00 Logic)
   - Feature: Rainbow Tilt & Speed Control
   - Feature: Signal Jitter & De-Dither
   - Optimized: Modern Syntax (in/out/texture)
*/

// --- الإعدادات المحدثة (بدون جوست) ---
#pragma parameter ntsc_hue "NTSC Color Hue (Cyan Fix)" 0.0 -3.14 3.14 0.05
#pragma parameter COL_BLEED "Chroma Bleed Strength" 2.0 0.0 20.0 0.05
#pragma parameter rb_power "Rainbow Strength" 0.2 0.0 2.0 0.05
#pragma parameter rb_size "Rainbow Width" 5.0 0.5 10.0 0.1
#pragma parameter rb_slant "Rainbow Tilt/Rotation" 0.0 -2.0 2.0 0.05
#pragma parameter rb_speed "Rainbow Cycle Speed" 0.03 0.0 1.0 0.01
#pragma parameter rb_detect "Rainbow Detection" 0.35 0.0 1.0 0.01
#pragma parameter de_dither "MD De-Dither (Sonic Water)" 0.50 0.0 2.0 0.1
#pragma parameter NOISE_STR "Analog Signal Noise" 0.01 0.0 0.5 0.01
#pragma parameter tv_mist "TV Signal Mist (Blur)" 0.4 0.0 1.5 0.05
#pragma parameter JITTER "Signal Jitter (Shake)" 0.02 0.0 5.5 0.01
#pragma parameter MD_SHARP "Luma Sharpness" 0.2 0.0 2.0 0.05

#if defined(VERTEX)
in vec4 VertexCoord;
in vec2 TexCoord;
out vec2 vTexCoord;
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord;
}

#elif defined(FRAGMENT)
precision mediump float;

in vec2 vTexCoord;
out vec4 FragColor;

uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform int FrameCount;

#ifdef PARAMETER_UNIFORM
uniform float ntsc_hue, COL_BLEED, rb_power, rb_size, rb_slant, rb_speed, rb_detect;
uniform float de_dither, NOISE_STR, tv_mist, JITTER, MD_SHARP;
#endif

// مصفوفات التحويل الثابتة (YIQ <-> RGB)
const mat3 RGBtoYIQ = mat3(0.299, 0.596, 0.211, 0.587, -0.274, -0.523, 0.114, -0.322, 0.312);
const mat3 YIQtoRGB = mat3(1.0, 1.0, 1.0, 0.956, -0.272, -1.106, 0.621, -0.647, 1.703);

float rand(vec2 co){ return fract(sin(dot(co.xy ,vec2(12.98, 78.23))) * 437.5); }

void main() {
    vec2 ps = vec2(1.0 / TextureSize.x, 1.0 / TextureSize.y);
    float time = float(FrameCount);

    // --- 0. JITTER ---
    vec2 uv = vTexCoord;
    uv.x += (rand(vec2(time, uv.y)) - 0.5) * JITTER * ps.x;

    float bleed = ps.x * COL_BLEED;

    // --- 1. SIGNAL PROCESSING & DE-DITHER ---
    vec3 main_col = texture(Texture, uv).rgb;
    vec3 cL_raw = texture(Texture, uv - vec2(ps.x * de_dither, 0.0)).rgb;
    vec3 cR_raw = texture(Texture, uv + vec2(ps.x * de_dither, 0.0)).rgb;
    
    // دمج الـ De-Dither فقط
    vec3 col = mix(main_col, (cL_raw + cR_raw) * 0.5, 0.4);

    // --- 2. CHROMA BLEED ---
    vec3 res  = RGBtoYIQ * col;
    vec3 resL = RGBtoYIQ * texture(Texture, uv - vec2(bleed, 0.0)).rgb;
    vec3 resR = RGBtoYIQ * texture(Texture, uv + vec2(bleed, 0.0)).rgb;

    // خلط الكروما الثلاثي لتعزيز تأثير الإشارة التناظرية
    vec2 mixed_chroma = (res.gb + resL.gb + resR.gb) / 3.0;

    // --- 3. RAINBOW ---
    float lC = res.r;
    float lL = resL.r;
    float lR = resR.r;
    float diff = abs(lC - lL) + abs(lC - lR);
    float rb_mask = smoothstep(rb_detect, rb_detect + 0.1, diff);

    float angle = (uv.x * TextureSize.x / rb_size) + (uv.y * TextureSize.y * rb_slant) + (time * rb_speed);
    float rainbowI = sin(angle) * rb_power * rb_mask;
    float rainbowQ = cos(angle) * rb_power * rb_mask;

    // --- 4. MIST, SHARPNESS & NOISE ---
    float final_y = mix(res.r, (lL + lC + lR) / 3.0, tv_mist);
    final_y += (lC - lL) * MD_SHARP; 
    if(NOISE_STR > 0.0) final_y += (rand(uv + time * 0.01) - 0.5) * NOISE_STR;

    // --- 5. HUE SHIFT & ASSEMBLY ---
    float cosA = cos(ntsc_hue);
    float sinA = sin(ntsc_hue);
    
    float fI = mixed_chroma.x + rainbowI;
    float fQ = mixed_chroma.y + rainbowQ;
    
    float hueI = fI * cosA - fQ * sinA;
    float hueQ = fI * sinA + fQ * cosA;

    // التحويل النهائي من YIQ إلى RGB
    vec3 final_rgb = YIQtoRGB * vec3(final_y, hueI, hueQ);

    FragColor = vec4(clamp(final_rgb, 0.0, 1.0), 1.0);
}
#endif