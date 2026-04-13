// --- NTSC MEGA LITE + CHROMA (Rainbow Tilt + Persistence + De-Dither) ---
// Optimized for Android - Zero Value = Feature Disabled

#version 110

#pragma parameter ntsc_hue "NTSC Color Hue (Cyan Fix)" 0.0 -3.14 3.14 0.05
#pragma parameter COL_BLEED "Chroma Bleed Strength" 1.5 0.0 5.0 0.05
#pragma parameter red_persistence "Red Persistence (Right Smear)" 1.0 0.0 5.0 0.05
#pragma parameter rb_power "Rainbow Strength" 0.10 0.0 2.0 0.01
#pragma parameter rb_size "Rainbow Width" 5.0 0.5 10.0 0.1
#pragma parameter rb_detect "Rainbow Detection" 0.25 0.0 1.0 0.01
#pragma parameter rb_speed "Rainbow Crawl Speed (0=OFF)" 0.05 0.0 2.0 0.05
#pragma parameter rb_tilt "Rainbow Diagonal Tilt" 0.0 -2.0 2.0 0.1
#pragma parameter de_dither "MD De-Dither Intensity" 1.0 0.0 2.0 0.1
#pragma parameter ntsc_grain "Signal Grain (RF Noise)" 0.0 0.0 0.20 0.01
#pragma parameter tv_mist "TV Signal Mist (Blur)" 0.0 0.0 1.5 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 vTexCoord;
varying vec2 hue_trig; 
uniform mat4 MVPMatrix;

#ifdef PARAMETER_UNIFORM
uniform float ntsc_hue;
#else
#define ntsc_hue 0.0
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
uniform float ntsc_hue, COL_BLEED, red_persistence, rb_power, rb_size, rb_detect, rb_speed, rb_tilt, de_dither, ntsc_grain, tv_mist;
#else
#define COL_BLEED 1.0
#define red_persistence 1.0
#define rb_power 0.15
#define rb_size 3.0
#define rb_detect 0.30
#define rb_speed 0.5
#define rb_tilt 0.5
#define de_dither 1.0
#define ntsc_grain 0.01
#define tv_mist 0.1
#endif

float noise(vec2 co) {
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

mat3 RGBtoYIQ = mat3(0.2989, 0.5870, 0.1140, 0.5959, -0.2744, -0.3216, 0.2115, -0.5229, 0.3114);
mat3 YIQtoRGB = mat3(1.0, 0.956, 0.6210, 1.0, -0.2720, -0.6474, 1.0, -1.1060, 1.7046);

void main() {
    vec2 ps = vec2(1.0 / TextureSize.x, 1.0 / TextureSize.y);
    float time = float(FrameCount);

    // --- 1. SMART FETCHES ---
    vec3 col_m = texture2D(Texture, vTexCoord).rgb;
    
    vec3 cL = col_m;
    vec3 cR = col_m;
    if (de_dither > 0.0) {
        cL = texture2D(Texture, vTexCoord - vec2(ps.x * de_dither, 0.0)).rgb;
        cR = texture2D(Texture, vTexCoord + vec2(ps.x * de_dither, 0.0)).rgb;
    }

    vec3 col = (de_dither > 0.0) ? mix(col_m, (cL + cR) * 0.5, 0.4) : col_m;
    vec3 yiq = col * RGBtoYIQ;
    float lumaL = (cL * RGBtoYIQ).r;
    float lumaR = (cR * RGBtoYIQ).r;

    // --- 2. CHROMA BLEED & RED PERSISTENCE ---
    vec2 mixed_chroma = yiq.gb;
    if (COL_BLEED > 0.0 || red_persistence > 0.0) {
        float bleed_offset = ps.x * COL_BLEED * 2.0;
        vec2 chrL = (texture2D(Texture, vTexCoord - vec2(bleed_offset, 0.0)).rgb * RGBtoYIQ).gb;
        vec2 chrR = (texture2D(Texture, vTexCoord + vec2(bleed_offset, 0.0)).rgb * RGBtoYIQ).gb;
        
        // تطبيق دمج الكروما العام
        mixed_chroma = mix(yiq.gb, (chrL + chrR) * 0.5, 0.5);

        // إضافة سيلان الأحمر (Logic 1010): سحب "I" من اليسار لليمين
        if (red_persistence > 0.0) {
            float i_smear = mix(yiq.g, chrL.x, 0.4 * red_persistence);
            mixed_chroma.x = mix(mixed_chroma.x, i_smear, 0.5);
        }
    }

    // --- 3. RAINBOW GENERATION ---
    float rainbowI = 0.0;
    float rainbowQ = 0.0;
    if (rb_speed > 0.0 && rb_power > 0.0) {
        float edge = abs(yiq.r - lumaL) + abs(yiq.r - lumaR);
        float rb_mask = smoothstep(rb_detect, rb_detect + 0.2, edge);
        float angle = (vTexCoord.x * TextureSize.x / rb_size) + (vTexCoord.y * TextureSize.y * rb_tilt) + (time * rb_speed); 
        rainbowI = sin(angle) * rb_power * rb_mask;
        rainbowQ = cos(angle) * rb_power * rb_mask;
    }

    // --- 4. GRAIN & FINAL LUMA ---
    float final_y = (tv_mist > 0.0) ? mix(yiq.r, (lumaL + yiq.r + lumaR) * 0.333, tv_mist) : yiq.r;
    
    if (ntsc_grain > 0.0) {
        final_y += (noise(vTexCoord + mod(time, 60.0)) - 0.5) * ntsc_grain;
    }

    // --- 5. HUE SHIFT & ASSEMBLY ---
    float fI = mixed_chroma.x + rainbowI;
    float fQ = mixed_chroma.y + rainbowQ;
    
    // الدوران باستخدام الـ Pre-calculated trig من الـ Vertex
    float hueI = fI * hue_trig.x - fQ * hue_trig.y;
    float hueQ = fI * hue_trig.y + fQ * hue_trig.x;

    vec3 final_rgb = vec3(final_y, hueI, hueQ) * YIQtoRGB;

    gl_FragColor = vec4(clamp(final_rgb, 0.0, 1.0), 1.0);
}
#endif