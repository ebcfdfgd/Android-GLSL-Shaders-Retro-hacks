#version 110

/* 
   5-PURE-CLEAN
   - REMOVED: All Plastic Grain logic and parameters.
   - PRESERVED: Sharp Pixels, Motion Jitter & Ghosting.
   - STATUS: 100% Raw Pixel Purity.
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
#pragma parameter PROFILE "LCD Profile: 0:Off, 1:GBA, 2:GBC, 3:DMG-Green, 4:Modern-101" 0.0 0.0 4.0 1.0
#pragma parameter GHOST_STR "LCD Ghosting" 0.55 0.0 3.0 0.05
#pragma parameter MOTION_OFS "Motion Spread" 0.7 0.0 3.0 0.05
#pragma parameter RESPONSE_LAG "LCD Lag Jitter" 0.4 0.0 3.0 0.05
#pragma parameter SATURATION "Saturation" 1.0 0.0 2.0 0.05
#pragma parameter BLACK_LEVEL "Black Level" 0.05 -0.5 0.5 0.01

#ifdef PARAMETER_UNIFORM
uniform float PROFILE, GHOST_STR, MOTION_OFS, RESPONSE_LAG, SATURATION, BLACK_LEVEL;
#endif

void main() {
    vec2 ps = 1.0 / TextureSize;
    vec2 uv = vTexCoord;
    float time = float(FrameCount);
    vec3 col = texture2D(Texture, uv).rgb;

    // [1] الـ Ghosting & Jitter (منطق الحركة النقي)
    if (GHOST_STR > 0.0) {
        float toggle = (mod(time, 2.0) > 0.5) ? 1.0 : -1.0;
        float off = (MOTION_OFS + (RESPONSE_LAG * toggle)) * 0.7;
        vec3 s1 = texture2D(Texture, uv + (ps * off)).rgb;
        vec3 s2 = texture2D(Texture, uv - (ps * off)).rgb;
        col = mix(col, (s1 + s2) * 0.5, GHOST_STR * 0.65);
    }

    // [2] مصفوفات الألوان المتميزة
    if (PROFILE > 0.5) {
        if (PROFILE < 1.5)      col = col * mat3(0.84, 0.08, 0.08, 0.16, 0.76, 0.08, 0.00, 0.16, 0.84); // GBA
        else if (PROFILE < 2.5) col = col * mat3(0.70, 0.15, 0.15, 0.20, 0.70, 0.10, 0.10, 0.15, 0.75); // GBC
        else if (PROFILE < 3.5) { col = mix(vec3(0.05, 0.1, 0.05), vec3(0.6, 0.75, 0.1), dot(col, vec3(0.299, 0.587, 0.114))); } // DMG
        else                    col = col * mat3(0.90, 0.05, 0.05, 0.05, 0.90, 0.05, 0.05, 0.05, 0.95); // 101
    }

    // [3] المعالجة النهائية
    float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
    col = mix(vec3(luma), col, SATURATION);
    
    // Black Level & Final Clamp (تم حذف البلاستيك نهائياً من هنا)
    col = clamp(col - BLACK_LEVEL, 0.0, 1.0);

    gl_FragColor = vec4(col, 1.0);
}
#endif