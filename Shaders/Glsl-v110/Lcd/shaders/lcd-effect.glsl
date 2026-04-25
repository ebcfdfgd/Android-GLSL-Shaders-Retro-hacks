#version 110

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

// 0. بروفايلات الألوان والضجيج
#pragma parameter PROFILE "Color Profile: 0:Off, 1:mGBA, 2:GBC, 3:SP, 4:GG, 5:GBG, 6:101" 0.0 0.0 6.0 1.0
#pragma parameter LCD_GRAIN "LCD Plastic Grain" 0.15 0.0 2.0 0.05

// 1. الحركة والظلال
#pragma parameter GHOST_STR "LCD Ghosting" 0.55 0.0 3.0 0.05
#pragma parameter MOTION_OFS "Motion Spread" 0.7 0.0 3.0 0.05
#pragma parameter RESPONSE_LAG "LCD Lag Jitter" 0.4 0.0 3.0 0.05

// 2. معالجة الصورة
#pragma parameter SATURATION "Saturation" 1.0 0.0 2.0 0.05
#pragma parameter BLACK_LEVEL "Black Level" 0.05 -0.5 0.5 0.01

// 3. التنعيم
#pragma parameter EDGE_SOFT "Edge Softening (AA)" 0.3 0.0 1.0 0.05

uniform float PROFILE, LCD_GRAIN, GHOST_STR, MOTION_OFS, RESPONSE_LAG;
uniform float SATURATION, EDGE_SOFT, BLACK_LEVEL;

float pseudo_noise(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec2 ps = 1.0 / TextureSize;
    vec2 uv = vTexCoord;
    float time = float(FrameCount);
    vec3 col = texture2D(Texture, uv).rgb;

    // [1] الـ Ghosting
    if (GHOST_STR > 0.0) {
        float toggle = (mod(time, 2.0) > 0.5) ? 1.0 : -1.0;
        float off = (MOTION_OFS + (RESPONSE_LAG * toggle)) * 0.7;
        vec3 s1 = texture2D(Texture, uv + (ps * off)).rgb;
        vec3 s2 = texture2D(Texture, uv - (ps * off)).rgb;
        col = mix(col, (s1 + s2) * 0.5, GHOST_STR * 0.65);
    }

    // [2] مصفوفات الألوان
    if (PROFILE > 0.5) {
        if (PROFILE < 1.5)      col *= mat3(0.84, 0.16, 0.0, 0.08, 0.76, 0.16, 0.08, 0.08, 0.84); // mGBA Profile
        else if (PROFILE < 2.5) col *= mat3(0.70, 0.20, 0.10, 0.15, 0.70, 0.15, 0.15, 0.10, 0.75); // GBC
        else if (PROFILE < 3.5) { col *= mat3(0.75, 0.15, 0.10, 0.10, 0.75, 0.15, 0.15, 0.20, 0.65); col.b += 0.05; } // SP
        else if (PROFILE < 4.5) { col *= mat3(0.85, 0.10, 0.05, 0.10, 0.85, 0.10, 0.05, 0.10, 0.85); col += 0.03; } // GG
        else if (PROFILE < 5.5) { col = mix(vec3(0.05, 0.1, 0.05), vec3(0.6, 0.75, 0.1), dot(col, vec3(0.299, 0.587, 0.114))); } // GBG
        else { col *= mat3(0.90, 0.05, 0.05, 0.05, 0.90, 0.05, 0.05, 0.05, 0.95); } // 101
    }

    // [3] الضجيج والتنعيم واللون النهائي
    float noise = pseudo_noise(uv * TextureSize);
    col = mix(col, col * (0.9 + 0.2 * noise), LCD_GRAIN);
    
    // تطبيق الـ Saturation
    col = mix(vec3(dot(col, vec3(0.21, 0.72, 0.07))), col, SATURATION);
    
    // تطبيق الـ Black Level
    col = clamp(col - BLACK_LEVEL, 0.0, 1.0);

    // التنعيم النهائي
    vec3 sN = (texture2D(Texture, uv - ps * vec2(1.0, 0.0)).rgb + texture2D(Texture, uv + ps * vec2(1.0, 0.0)).rgb) * 0.5;
    col = mix(col, sN, EDGE_SOFT * 0.5);

    gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
#endif