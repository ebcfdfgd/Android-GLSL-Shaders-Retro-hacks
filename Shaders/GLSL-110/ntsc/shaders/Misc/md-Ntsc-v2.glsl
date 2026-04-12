#version 110

/* NTSC-MEGA-LITE-00-ADAPTIVE
    - Feature: High-Speed Blargg-inspired Luma Sensing.
    - Performance: Vertex-precalculated Hue Trigs.
    - Smart Logic: Adaptive Texture Sampling based on parameter activity.
*/

#pragma parameter ntsc_hue "NTSC Color Hue (Cyan Fix)" 0.0 -3.14 3.14 0.05
#pragma parameter COL_BLEED "Chroma Bleed Strength" 2.0 0.0 20.0 0.05
#pragma parameter rb_power "Rainbow Strength" 0.2 0.0 2.0 0.05
#pragma parameter rb_size "Rainbow Width" 5.0 0.5 10.0 0.1
#pragma parameter rb_slant "Rainbow Tilt/Rotation" 0.0 -2.0 2.0 0.05
#pragma parameter rb_speed "Rainbow Cycle Speed" 0.03 0.0 1.0 0.01
#pragma parameter rb_detect "Rainbow Detection (Auto Offset)" 0.35 0.0 1.0 0.01
#pragma parameter de_dither "MD De-Dither (Sonic Water)" 0.50 0.0 2.0 0.1
#pragma parameter NOISE_STR "Analog Signal Noise" 0.01 0.0 0.5 0.01
#pragma parameter tv_mist "TV Signal Mist (Blur)" 0.4 0.0 1.5 0.05
#pragma parameter JITTER "Signal Jitter (Shake)" 0.02 0.0 5.5 0.01
#pragma parameter MD_SHARP "Luma Sharpness" 0.2 0.0 2.0 0.05

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
    // توفير المعالجة: حساب الـ Hue مرة واحدة في الـ Vertex
    hue_trig = vec2(cos(ntsc_hue), sin(ntsc_hue));
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision mediump float;
#endif

uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform int FrameCount;
varying vec2 vTexCoord;
varying vec2 hue_trig;

#ifdef PARAMETER_UNIFORM
uniform float ntsc_hue, COL_BLEED, rb_power, rb_size, rb_slant, rb_speed, rb_detect;
uniform float de_dither, NOISE_STR, tv_mist, JITTER, MD_SHARP;
#endif

const mat3 RGBtoYIQ = mat3(0.299, 0.596, 0.211, 0.587, -0.274, -0.523, 0.114, -0.322, 0.312);
const mat3 YIQtoRGB = mat3(1.0, 1.0, 1.0, 0.956, -0.272, -1.106, 0.621, -0.647, 1.703);

float rand(vec2 co){ return fract(sin(dot(co.xy ,vec2(12.98, 78.23))) * 437.5); }

void main() {
    vec2 ps = vec2(1.0 / TextureSize.x, 1.0 / TextureSize.y);
    float time = float(FrameCount);
    vec2 uv = vTexCoord;

    // [0] JITTER
    uv.x += (rand(vec2(time, uv.y)) - 0.5) * JITTER * ps.x;

    // [1] SMART FETCHES & AUTO-SENSING
    vec3 main_col = texture2D(Texture, uv).rgb;
    vec3 cL = texture2D(Texture, uv - ps).rgb;
    vec3 cR = texture2D(Texture, uv + ps).rgb;

    // حساب اللمعان لاكتشاف الترددات العالية (الديزر)
    float lC = dot(main_col, vec3(0.299, 0.587, 0.114));
    float lL = dot(cL, vec3(0.299, 0.587, 0.114));
    float lR = dot(cR, vec3(0.299, 0.587, 0.114));

    // القناع التلقائي: يتحسس نمط الديزر ويفصله عن الأسطح الصافية
    float auto_diff = abs(lC - (lL + lR) * 0.5);
    float smart_mask = smoothstep(0.01, 0.4 - (rb_detect * 0.3), auto_diff);

    // [2] DE-DITHER & SIGNAL
    // تطبيق التنعيم فقط في الأماكن التي يكتشف فيها الديزر
    vec3 col = mix(main_col, (cL + main_col + cR) * 0.333, de_dither * 0.5 * smart_mask);
    vec3 res = col * RGBtoYIQ;

    // [3] DYNAMIC CHROMA BLEED
    // النزيف اللوني يتبع القناع الذكي ليحافظ على حدة القوائم (UI)
    float bleed_off = ps.x * COL_BLEED * smart_mask;
    vec2 chrL = (texture2D(Texture, uv - vec2(bleed_off, 0.0)).rgb * RGBtoYIQ).gb;
    vec2 chrR = (texture2D(Texture, uv + vec2(bleed_off, 0.0)).rgb * RGBtoYIQ).gb;
    vec2 mixed_chroma = mix(res.gb, (chrL + res.gb + chrR) * 0.333, smart_mask);

    // [4] RAINBOW GENERATION
    float angle = (uv.x * TextureSize.x / rb_size) + (uv.y * TextureSize.y * rb_slant) + (time * rb_speed);
    float rainbowI = sin(angle) * rb_power * smart_mask;
    float rainbowQ = cos(angle) * rb_power * smart_mask;

    // [5] MIST & SHARPNESS
    float final_y = mix(res.r, (lL + lC + lR) * 0.333, tv_mist * smart_mask);
    final_y += (lC - lL) * MD_SHARP; 
    
    if(NOISE_STR > 0.0) final_y += (rand(uv + time * 0.01) - 0.5) * NOISE_STR;

    // [6] FINAL ASSEMBLY (Using Vertex Hue)
    float fI = mixed_chroma.x + rainbowI;
    float fQ = mixed_chroma.y + rainbowQ;
    
    float hueI = fI * hue_trig.y - fQ * hue_trig.x; // تم تعديل ترتيب التدوير للدقة
    float hueQ = fI * hue_trig.x + fQ * hue_trig.y;

    vec3 final_rgb = vec3(final_y, hueI, hueQ) * YIQtoRGB;

    gl_FragColor = vec4(clamp(final_rgb, 0.0, 1.0), 1.0);
}
#endif