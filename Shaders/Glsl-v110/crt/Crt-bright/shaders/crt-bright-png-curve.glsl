#version 110

/* ULTIMATE-TURBO-HYBRID (V22-PNG-DYNAMIC-MASK)
    - INTEGRATED: Sharp PNG texture dimension input from Code 1.
    - CONTROL: Dynamic Mask Intensity (Dark/Bright scenes) retained from Code 2.
    - GEOMETRY: Ultra-fast Curve 20 (r2-based).
    - SPEED: 100% Branchless Mask & Border system.
*/

#pragma parameter BARREL_DISTORTION "Curve 0 Strength" 0.15 0.0 1.0 0.02
#pragma parameter SCAN_LOW "Scanline Intensity (Dark Scenes)" 0.8 0.0 1.0 0.05
#pragma parameter SCAN_HIGH "Scanline Intensity (Bright Scenes)" 0.3 0.0 1.0 0.05
#pragma parameter MASK_LOW "Mask Intensity (Dark Scenes)" 0.5 0.0 1.0 0.05
#pragma parameter MASK_HIGH "Mask Intensity (Bright Scenes)" 0.2 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width (Texture Pixels)" 6.0 1.0 64.0 1.0
#pragma parameter MASK_H "Mask Height (Texture Pixels)" 2.0 1.0 64.0 1.0
#pragma parameter GAMMA_BOOST "Gamma Brightness Boost" 0.0 -1.0 1.0 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv;
uniform mat4 MVPMatrix;

void main() {
    uv = TexCoord;
    gl_Position = MVPMatrix * VertexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 uv;
uniform sampler2D Texture, SamplerMask1;
uniform vec2 TextureSize;
uniform vec2 InputSize;
uniform vec2 OutputSize;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION;
uniform float SCAN_LOW;
uniform float SCAN_HIGH;
uniform float MASK_LOW;
uniform float MASK_HIGH;
uniform float MASK_W;
uniform float MASK_H;
uniform float GAMMA_BOOST;
#else
#define BARREL_DISTORTION 0.15
#define SCAN_LOW 0.8
#define SCAN_HIGH 0.3
#define MASK_LOW 0.5
#define MASK_HIGH 0.2
#define MASK_W 6.0
#define MASK_H 2.0
#define GAMMA_BOOST 1.0
#endif

#define TAU 6.283185307179586

void main() {
    vec2 sc = TextureSize / InputSize;
    vec2 p = (uv * sc) - 0.5;

    // 1. كيرف 20 الفائق (حساب نصف القطر المربع ومعادلة الانحناء البرميلي السريعة)
    float r2 = dot(p, p);
    vec2 p_curved = p * (1.0 + r2 * vec2(BARREL_DISTORTION * 0.2, BARREL_DISTORTION * 0.8));

    vec2 texCoord = (p_curved + 0.5) / sc;

    // فحص الحدود الرقمي الخالي من الشروط (Branchless) لقص الحواف السوداء
    vec2 bounds = step(abs(p_curved), vec2(0.5));

    vec3 res = texture2D(Texture, texCoord).rgb;
    res *= bounds.x * bounds.y;

    // حساب السطوع الحالي للمشهد (Luminance) لربط القوة الديناميكية
    float l = max(max(res.r, res.g), res.b);

    float infl = mix(SCAN_LOW, SCAN_HIGH, l);
    float infl2 = mix(MASK_LOW, MASK_HIGH, l); // حساب قوة ماسك الـ PNG ديناميكياً

    // 2. حساب وتطبيق خطوط المسح المستقيمة (Scanlines)
    float scan = infl * sin((uv.y * TextureSize.y - 0.25) * TAU);
    res += res * scan;
    
    // 3. نظام ماسك الـ PNG الحاد (Sharp PNG-Only Mask System) من الكود الأول
    vec2 mask_size = vec2(floor(MASK_W), floor(MASK_H));
    vec2 pixel_coord = floor(gl_FragCoord.xy);
    vec2 repeated_coord = mod(pixel_coord, mask_size);
    vec2 m_uv = (repeated_coord + 0.5) / mask_size;
    
    // سحب عينة قناع البنج وضربها في معدل إضاءة معزز
    vec3 mcol = texture2D(SamplerMask1, m_uv).rgb * 1.5;
    
    // دمج قناع الـ PNG بالصورة بالاعتماد على القوة الديناميكية الذكية (infl2)
    res = mix(res, res * mcol, infl2);

    // 4. تصحيح الجاما النهائي (Gamma Correction)
    res = mix(res, sqrt(res), GAMMA_BOOST);

    gl_FragColor = vec4(res, 1.0);
}
#endif