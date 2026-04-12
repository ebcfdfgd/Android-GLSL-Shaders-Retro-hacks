#version 110

/* GBA-REALITY-REMNANT (Final Revision + Black Level - Backported to 110)
    - Parameters with GBA_ prefix.
    - Features: LCD Ghosting, Plastic Grain, Motion Jitter, Regional Profiles.
    - Fixed: Black Level Lift & 5-tap texture sampling.
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

// 0. بروفايلات الألوان والضجيج
#pragma parameter GBA_PROFILE "GBA: Profile [0:Raw 1:mGBA 2:GBC 3:SP 4:GG 5:DMG 6:101]" 1.0 0.0 6.0 1.0
#pragma parameter GBA_GRAIN "GBA: Plastic Grain Strength" 0.15 0.0 0.50 0.05

// 1. الحركة والظلال
#pragma parameter GBA_GHOST "GBA: LCD Ghosting Power" 0.55 0.0 1.0 0.05
#pragma parameter GBA_SPREAD "GBA: Motion Blur Width" 0.7 0.0 2.0 0.05
#pragma parameter GBA_LAG "GBA: Response Lag Jitter" 0.4 0.0 1.5 0.05

// 2. معالجة الصورة
#pragma parameter GBA_BLACK "GBA: Black Level (Lift)" 0.02 0.0 0.20 0.01
#pragma parameter GBA_SAT "GBA: Color Saturation" 1.1 0.0 2.0 0.05
#pragma parameter GBA_CON "GBA: Image Contrast" 1.15 0.5 2.0 0.05
#pragma parameter GBA_GAM "GBA: Gamma Correction" 1.10 0.5 3.0 0.05
#pragma parameter GBA_LUM "GBA: Final Brightness" 1.1 0.5 2.0 0.05

// 3. التنعيم
#pragma parameter GBA_SOFT "GBA: Edge Softening (AA)" 0.3 0.0 1.0 0.05

#ifdef PARAMETER_UNIFORM
uniform float GBA_PROFILE, GBA_GRAIN, GBA_GHOST, GBA_SPREAD, GBA_LAG;
uniform float GBA_BLACK, GBA_SAT, GBA_LUM, GBA_SOFT, GBA_CON, GBA_GAM;
#endif

float pseudo_noise(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec2 ps = 1.0 / TextureSize;
    vec2 uv = vTexCoord;
    float time = float(FrameCount);
    
    // السحبة الأساسية (1/5)
    vec3 col = texture2D(Texture, uv).rgb;

    // [1] الـ Ghosting مع الـ Jitter (سحبتين إضافيتين 3/5)
    if (GBA_GHOST > 0.01) {
        // محاكاة ارتعاش استجابة البكسل القديم
        float toggle = (mod(time, 2.0) > 0.5) ? 1.0 : -1.0;
        float off = (GBA_SPREAD + (GBA_LAG * toggle)) * 0.7;
        vec3 s1 = texture2D(Texture, uv + (ps * off)).rgb;
        vec3 s2 = texture2D(Texture, uv - (ps * off)).rgb;
        col = mix(col, (s1 + s2) * 0.5, GBA_GHOST * 0.65);
    }

    // [2] مصفوفات الألوان المصححة (تعديل الألوان حسب نوع الجهاز)
    if (GBA_PROFILE > 0.5) {
        if (GBA_PROFILE < 1.5)      col *= mat3(0.82, 0.12, 0.01, 0.08, 0.81, 0.08, 0.02, 0.07, 0.91); // 1: mGBA
        else if (GBA_PROFILE < 2.5) col *= mat3(0.70, 0.20, 0.10, 0.15, 0.70, 0.15, 0.15, 0.10, 0.75); // 2: GBC
        else if (GBA_PROFILE < 3.5) { col *= mat3(0.75, 0.15, 0.10, 0.10, 0.75, 0.15, 0.15, 0.20, 0.65); col.b += 0.05; } // 3: SP
        else if (GBA_PROFILE < 4.5) { col *= mat3(0.85, 0.10, 0.05, 0.10, 0.85, 0.10, 0.05, 0.10, 0.85); col += 0.03; } // 4: GG
        else if (GBA_PROFILE < 5.5) { col = mix(vec3(0.05, 0.1, 0.05), vec3(0.60, 0.75, 0.1), dot(col, vec3(0.299, 0.587, 0.114))); } // 5: DMG
        else { col *= mat3(0.88, 0.08, 0.04, 0.06, 0.88, 0.06, 0.04, 0.08, 0.92); } // 6: 101
    }

    // [3] نسيج الضجيج البلاستيكي (Plastic Grain)
    float noise_val = pseudo_noise(uv * TextureSize);
    col = mix(col, col * (0.9 + 0.2 * noise_val), GBA_GRAIN);
    
    // [4] التصحيح اللوني وتطبيق Black Level (لإعطاء مظهر الشاشة المضاءة خارجياً)
    col = max(col, 0.0) * (1.0 - GBA_BLACK) + GBA_BLACK;

    col = pow(max(col, 0.0), vec3(GBA_GAM));
    col = (col - 0.5) * GBA_CON + 0.5;
    col = mix(vec3(dot(col, vec3(0.21, 0.72, 0.07))), col, GBA_SAT) * GBA_LUM;

    // [5] التنعيم النهائي للحواف (Edge Softening - سحبتين إضافيتين 5/5)
    if (GBA_SOFT > 0.01) {
        vec3 sN = (texture2D(Texture, uv - ps * vec2(1.0, 0.0)).rgb + texture2D(Texture, uv + ps * vec2(1.0, 0.0)).rgb) * 0.5;
        col = mix(col, sN, GBA_SOFT * 0.5);
    }

    gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
#endif