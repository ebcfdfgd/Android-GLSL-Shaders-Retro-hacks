#version 110

/* 
   5-V23-PLASTIC-UPGRADE-CLEANED
   - FEATURE: Fixed Plastic Grain (Luminance-based) from V22.
   - PRESERVED: Clean LCD logic, No AA, and Sharp Ghosting.
   - REMOVED: All Color Profiles, Matrix Remapping, and Saturation.
*/

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 vTexCoord;
uniform mat4 MVPMatrix;
void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord.xy;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 vTexCoord;
uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform int FrameCount;

// البارامترات المصفاة
#pragma parameter GHOST_STR "LCD Ghosting" 0.55 0.0 3.0 0.05
#pragma parameter MOTION_OFS "Motion Spread" 0.7 0.0 3.0 0.05
#pragma parameter RESPONSE_LAG "LCD Lag Jitter" 0.4 0.0 3.0 0.05
#pragma parameter LCD_GRAIN "LCD Plastic Strength" 0.02 0.0 1.0 0.01
#pragma parameter BLACK_LEVEL "Black Level" 0.05 -0.5 0.5 0.01

#ifdef PARAMETER_UNIFORM
uniform float LCD_GRAIN, GHOST_STR, MOTION_OFS, RESPONSE_LAG, BLACK_LEVEL;
#endif

void main() {
    vec2 ps = 1.0 / TextureSize;
    vec2 uv = vTexCoord;
    float time = float(FrameCount);
    vec3 col = texture2D(Texture, uv).rgb;

    // [1] الـ Ghosting & Jitter (المنطق الأصلي للكود 5)
    if (GHOST_STR > 0.0) {
        float toggle = (mod(time, 2.0) > 0.5) ? 1.0 : -1.0;
        float off = (MOTION_OFS + (RESPONSE_LAG * toggle)) * 0.7;
        vec3 s1 = texture2D(Texture, uv + (ps * off)).rgb;
        vec3 s2 = texture2D(Texture, uv - (ps * off)).rgb;
        col = mix(col, (s1 + s2) * 0.5, GHOST_STR * 0.65);
    }

    // [2] حساب السطوع لتأثير البلاستيك فقط (بدون معادلة التشبع)
    float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
    
    // --- إضافة تأثير البلاستيك المطور ---
    // ثابت لا يتأثر بالوقت (Static) ويظهر في المناطق المضيئة فقط
    vec2 pixel_coord = uv * TextureSize;
    float noise = fract(sin(dot(pixel_coord, vec2(12.9898, 78.233))) * 43758.5453);
    float grain_effect = (noise - 0.5) * LCD_GRAIN;
    col += grain_effect * (luma + 0.2); 
    
    // Black Level & Final Clamp
    col = clamp(col - BLACK_LEVEL, 0.0, 1.0);

    gl_FragColor = vec4(col, 1.0);
}
#endif