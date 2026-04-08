// --- NTSC MEGA LITE + CHROMA (Rainbow Tilt + Motion + De-Dither + Grain) ---
// Optimized for Android - Moved Hue Trigs to Vertex for Maximum Speed
// Integrated Features from 1002: Resolution, Sharpness, Fringing, Artifacts

#version 110

// --- المضاف من 1002 ---
#pragma parameter ntsc_res "NTSC: Resolution" 0.0 -1.0 1.0 0.05
#pragma parameter ntsc_sharp "NTSC: Sharpness Boost" 0.1 -1.0 1.0 0.05
#pragma parameter fring "NTSC: Edge Fringing" 0.0 0.0 1.0 0.05
#pragma parameter afacts "NTSC: Artifact Intensity" 0.0 0.0 1.0 0.05

// --- البارميترات الأصلية ---
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

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 vTexCoord;
varying vec2 hue_trig; 
uniform mat4 MVPMatrix;

#ifdef PARAMETER_UNIFORM
uniform float ntsc_hue;
#endif

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord;
    hue_trig = vec2(cos(ntsc_hue), sin(ntsc_hue));
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform int FrameCount;
varying vec2 vTexCoord;
varying vec2 hue_trig;

#ifdef PARAMETER_UNIFORM
uniform float ntsc_res, ntsc_sharp, fring, afacts;
uniform float ntsc_hue, COL_BLEED, rb_power, rb_size, rb_detect, rb_speed, rb_tilt, de_dither, ntsc_grain, tv_mist;
#endif

float noise(vec2 co) {
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

mat3 RGBtoYIQ = mat3(0.2989, 0.5870, 0.1140, 0.5959, -0.2744, -0.3216, 0.2115, -0.5229, 0.3114);
mat3 YIQtoRGB = mat3(1.0, 0.956, 0.6210, 1.0, -0.2720, -0.6474, 1.0, -1.1060, 1.7046);

void main() {
    // استخدام ntsc_res للتحكم في حجم البكسل الافتراضي
    float res_step = 1.0 - (ntsc_res * 0.5);
    vec2 ps = vec2(res_step / TextureSize.x, 1.0 / TextureSize.y);
    float time = float(FrameCount);
    
    // --- 1. FETCHES ---
    vec3 col_m = texture2D(Texture, vTexCoord).rgb;
    vec3 col_l = texture2D(Texture, vTexCoord - vec2(ps.x * de_dither, 0.0)).rgb;
    vec3 col_r = texture2D(Texture, vTexCoord + vec2(ps.x * de_dither, 0.0)).rgb;
    
    float bleed_offset = ps.x * COL_BLEED * 2.0;
    vec3 col_chrL = texture2D(Texture, vTexCoord - vec2(bleed_offset, 0.0)).rgb;
    vec3 col_chrR = texture2D(Texture, vTexCoord + vec2(bleed_offset, 0.0)).rgb;

    // --- 2. DE-DITHER & LUMA ANALYSIS ---
    vec3 col = mix(col_m, (col_l + col_r) * 0.5, 0.4);
    vec3 yiq = col * RGBtoYIQ;
    float lumaL = (col_l * RGBtoYIQ).r;
    float lumaR = (col_r * RGBtoYIQ).r;

    // --- 3. CHROMA & FRINGING (دمج fring و afacts) ---
    vec2 chrL = (col_chrL * RGBtoYIQ).gb;
    vec2 chrR = (col_chrR * RGBtoYIQ).gb;
    vec2 mixed_chroma = mix(yiq.gb, (chrL + chrR) * 0.5, 0.5);

    // --- 4. RAINBOW & ARTIFACTS ---
    float edge = abs(yiq.r - lumaL) + abs(yiq.r - lumaR);
    float rb_mask = smoothstep(rb_detect, rb_detect + 0.2, edge);
    
    float angle = (vTexCoord.x * TextureSize.x / rb_size) + (vTexCoord.y * TextureSize.y * rb_tilt) + (time * rb_speed) + ntsc_hue; 
    
    // إضافة تأثير afacts لزيادة قوة الرينبو
    float total_rb = rb_power + (afacts * 0.5);
    float rainbowI = sin(angle) * total_rb * rb_mask;
    float rainbowQ = cos(angle) * total_rb * rb_mask;

    // --- 5. FINAL LUMA (دمج ntsc_sharp) ---
    float y = yiq.r;
    y += (yiq.r - lumaL) * (ntsc_sharp * 0.6); // تعزيز الحواف
    float final_y = mix(y, (lumaL + y + lumaR) * 0.333, tv_mist);
    final_y += (noise(vTexCoord + mod(time, 60.0)) - 0.5) * ntsc_grain;

    // --- 6. HUE SHIFT & FRINGING ---
    float cosA = hue_trig.x;
    float sinA = hue_trig.y;
    
    // دمج تأثير الـ fringing اللوني عند الحواف
    float fI = mixed_chroma.x + rainbowI + (yiq.r - lumaR) * fring * 0.3;
    float fQ = mixed_chroma.y + rainbowQ - (yiq.r - lumaL) * fring * 0.3;
    
    float hueI = fI * cosA - fQ * sinA;
    float hueQ = fI * sinA + fQ * cosA;

    vec3 final_rgb = vec3(final_y, hueI, hueQ) * YIQtoRGB;

    gl_FragColor = vec4(clamp(final_rgb, 0.0, 1.0), 1.0);
}
#endif