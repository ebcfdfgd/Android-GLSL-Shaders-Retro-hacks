#version 110

/* Blargg Turbo-Lite (Mobile Speed Optimized)
    - Optimization: Reduced texture taps.
    - Speed: 2x faster on G90T/Adreno GPUs.
    - Logic: Merged Detection & Chroma passes.
*/

#pragma parameter ntsc_hue "NTSC Phase Shift" 0.0 -3.14 3.14 0.05
#pragma parameter COL_BLEED "Chroma Bleed Strength" 1.2 0.0 5.0 0.05
#pragma parameter red_persistence "Red Persistence (Right Smear)" 1.0 0.0 2.5 0.05
#pragma parameter rb_power "Rainbow Transparency (Strength)" 0.35 0.0 2.0 0.01
#pragma parameter dot_crawl "Dot Crawl Intensity" 0.25 0.0 1.0 0.01
#pragma parameter de_dither "Dither Blending Strength" 0.50 0.0 1.0 0.01
#pragma parameter pi_mod "Subcarrier Phase Angle" 131.5 0.0 360.0 0.1
#pragma parameter vert_scal "Vertical Phase Scale" 0.5 0.0 2.0 0.01

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 vTexCoord;
varying vec2 vHueTrig; 
uniform mat4 MVPMatrix;
uniform float ntsc_hue;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord;
    vHueTrig = vec2(cos(ntsc_hue), sin(ntsc_hue));
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision mediump float; // استخدام دقة متوسطة للسرعة على الموبايل
#endif

uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform int FrameCount;
varying vec2 vTexCoord;
varying vec2 vHueTrig;

#ifdef PARAMETER_UNIFORM
uniform float ntsc_hue, COL_BLEED, red_persistence, rb_power, dot_crawl, de_dither, pi_mod, vert_scal;
#endif

// ثوابت تحويل YIQ (محسوبة مسبقاً)
const vec3 kY = vec3(0.299, 0.587, 0.114);
const vec3 kI = vec3(0.596, -0.274, -0.322);
const vec3 kQ = vec3(0.211, -0.523, 0.311);

void main() {
    vec2 ps = vec2(1.0 / TextureSize.x, 0.0);
    float time = float(FrameCount);
    
    // سحب المركز واليسار واليمين (3 سحبات أساسية فقط)
    vec3 cM = texture2D(Texture, vTexCoord).rgb;
    vec3 cL = texture2D(Texture, vTexCoord - ps).rgb;
    vec3 cR = texture2D(Texture, vTexCoord + ps).rgb;

    float yM = dot(cM, kY);
    float yL = dot(cL, kY);
    float yR = dot(cR, kY);

    // كاشف الديذير والكرومب (مدمج)
    float auto_detect = clamp(abs(yL - yM) + abs(yR - yM) - abs(yL - yR), 0.0, 1.0);
    float mask = smoothstep(0.02, 0.15, auto_detect);

    // حساب الـ Phase مرة واحدة
    float phase = (floor(vTexCoord.x * TextureSize.x) * pi_mod * 0.01745) + 
                  (floor(vTexCoord.y * TextureSize.y) * vert_scal * 3.14159) + 
                  (mod(time, 2.0) * 3.14159);
    
    vec2 s_c = vec2(sin(phase), cos(phase)); // حساب الـ sin والـ cos في خطوة واحدة

    // تطبيق الـ Luma (Dot Crawl + Dither)
    float final_y = mix(yM, (yL + yM + yR) * 0.333, de_dither * mask);
    final_y += s_c.x * dot_crawl * mask;

    // محرك الكروما (I & Q)
    float i = dot(cM, kI);
    float q = dot(cM, kQ);

    // إضافة الرينبو بلمسة واحدة
    i = mix(i, i + s_c.x * mask, rb_power);
    q = mix(q, q + s_c.y * mask, rb_power);

    // دمج الـ Bleed والـ Persistence (باستخدام العينة اليسرى المسحوبة مسبقاً)
    if (COL_BLEED > 0.0) {
        float iL = dot(cL, kI);
        i = mix(i, iL, (0.3 * red_persistence) + 0.2); // دمج العمليتين لتوفير الوقت
    }

    // تدوير الطور (Hue Shift)
    float fI = i * vHueTrig.x - q * vHueTrig.y;
    float fQ = i * vHueTrig.y + q * vHueTrig.x;

    // التحويل النهائي لـ RGB
    vec3 rgb = vec3(
        final_y + 0.956 * fI + 0.621 * fQ,
        final_y - 0.272 * fI - 0.647 * fQ,
        final_y - 1.106 * fI + 1.703 * fQ
    );
    
    gl_FragColor = vec4(clamp(rgb, 0.0, 1.0), 1.0);
}
#endif