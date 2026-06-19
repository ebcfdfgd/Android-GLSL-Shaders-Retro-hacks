#version 110

/* 777-NTSC-MEGA-LITE-CLEAN (ULTIMATE REAL ANALOG NOISE)
    - OPTIMIZED: Pure linear math for Raspberry Pi Zero (60 FPS).
    - ADDED: Real broken cable glitch lines (Horizontal Sync Noise).
*/

#pragma parameter NTSC_BRIGHTNESS "Signal Brightness" 1.0 0.0 2.0 0.05
#pragma parameter SATURATION "Global Saturation" 1.0 0.0 2.0 0.05
#pragma parameter COL_BLEED "Chroma Bleed Strength" 1.5 0.0 5.0 0.05
#pragma parameter rb_power "Rainbow Strength" 0.15 0.0 2.0 0.01
#pragma parameter rb_size "Rainbow Width" 3.0 0.5 10.0 0.1
#pragma parameter rb_detect "Rainbow Detection" 0.30 0.0 1.0 0.01
#pragma parameter rb_speed "Rainbow Crawl Speed" 0.5 0.0 2.0 0.05
#pragma parameter rb_tilt "Rainbow Diagonal Tilt" 0.5 -2.0 2.0 0.1
#pragma parameter de_dither "MD De-Dither Intensity" 1.0 0.0 2.0 0.1
#pragma parameter ntsc_grain "Analog Signal Noise" 0.0 0.0 1.0 0.02
#pragma parameter cable_glitch "Broken Cable Static" 0.0 0.0 1.0 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 vTexCoord;
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform int FrameCount;
varying vec2 vTexCoord;

#ifdef PARAMETER_UNIFORM
uniform float NTSC_BRIGHTNESS, SATURATION, COL_BLEED, rb_power, rb_size, rb_detect, rb_speed, rb_tilt, de_dither, ntsc_grain, cable_glitch;
#endif

const mat3 RGB_to_YIQ = mat3(
    0.299,  0.596,  0.211,
    0.587, -0.274, -0.523,
    0.114, -0.322,  0.312
);

const mat3 YIQ_to_RGB = mat3(
    1.0,    1.0,    1.0,
    1.090, -0.272, -1.106,
    0.322, -0.647,  1.703
);

// دالة المثلث السريعة للـ Rainbow
vec2 triangle_wave(float x) {
    vec2 val = abs(fract(vec2(x * 0.159, x * 0.159 + 0.25)) * 2.0 - 1.0) * 2.0 - 1.0;
    return val;
}

void main() {
    vec2 ps = vec2(1.0 / TextureSize.x, 0.0);
    float time = float(FrameCount);

    // 1. صناعة خطوط تشويش الكابل البايظ (Horizontal Glitch Lines)
    // بنخلي خطوط الـ Y الكبيرة تتداخل مع الزمن لعمل شرط سوداء عشوائية بتتحرك رأساً
    float line_noise = fract(vTexCoord.y * 5.0 + time * 0.13) * fract(vTexCoord.y * 23.0 - time * 0.21);
    
    // تحويل النويز لشرط حادة جداً تشبه قفزات الإشارة التناظرية البايظة
    float static_lines = step(0.88, line_noise) * cable_glitch;

    // 2. سحب الألوان مع حقن التشويش الحقيقي
    vec3 cM = texture2D(Texture, vTexCoord).rgb;
    float d_off = max(de_dither, 1.0);
    vec3 cL = texture2D(Texture, vTexCoord - ps * d_off).rgb;
    vec3 cR = texture2D(Texture, vTexCoord + ps * d_off).rgb;

    vec3 yiqM = RGB_to_YIQ * cM;
    vec3 yiqL = RGB_to_YIQ * cL;
    vec3 yiqR = RGB_to_YIQ * cR;

    float final_y = (de_dither > 0.0) ? mix(yiqM.x, (yiqL.x + yiqR.x) * 0.5, 0.5 * de_dither) : yiqM.x;
    final_y *= NTSC_BRIGHTNESS;

    // تطبيق خطوط التشويش السوداء على الإضاءة (تأثير الكابل المهزوز)
    final_y -= static_lines * 0.4; 

    float fI = yiqM.y;
    float fQ = yiqM.z;

    // حقن خطوط النويز في الألوان برضه عشان تبهت أو تضرب أحمر/أزرق لحظياً زي التلفزيون القديم
    fI -= static_lines * 0.15;
    fQ += static_lines * 0.15;

    if (COL_BLEED > 0.0) {
        vec2 b_off = ps * COL_BLEED * 1.5; 
        vec3 bcL = RGB_to_YIQ * texture2D(Texture, vTexCoord - b_off).rgb;
        vec3 bcR = RGB_to_YIQ * texture2D(Texture, vTexCoord + b_off).rgb;
        fI = mix(fI, (bcL.y + bcR.y) * 0.5, 0.7);
        fQ = mix(fQ, (bcL.z + bcR.z) * 0.5, 0.7);
    }

    if (rb_power > 0.0) {
        float edge = abs(yiqM.x - yiqL.x) + abs(yiqM.x - yiqR.x);
        float mask = clamp((edge - rb_detect) / 0.1, 0.0, 1.0); // بديل سريع جداً لـ smoothstep
        
        float ang = (vTexCoord.x * TextureSize.x / rb_size) + (vTexCoord.y * TextureSize.y * rb_tilt) + (time * rb_speed);
        vec2 wave = triangle_wave(ang);
        
        // الكابل البايظ بيزود الـ Rainbow على الحواف، فبنحقن الـ static_lines هنا برضه!
        fI += wave.x * rb_power * (mask + static_lines * 0.5);
        fQ += wave.y * rb_power * (mask + static_lines * 0.5);
    }

    // النمش الناعم الخفيف جداً (باستخدام دالة موجة كسرية سريعة ومجانية بدون هاش)
    if (ntsc_grain > 0.0) {
        float grain = fract(vTexCoord.x * vTexCoord.y * 951.43 + time * 0.73);
        final_y += (grain - 0.5) * ntsc_grain;
    }

    vec3 res = YIQ_to_RGB * vec3(final_y, fI * SATURATION, fQ * SATURATION);

    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
#endif