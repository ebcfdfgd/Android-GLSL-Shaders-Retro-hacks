#version 110

/* GLASS & REFLECTION PASS (Rocket Edition)
   - Simulated curved glass specular.
   - Fresnel-based edge reflection.
   - Subtle static light bloom.
*/

#pragma parameter GLASS_STR "Glass Reflection Strength" 0.15 0.0 1.0 0.05
#pragma parameter BORDER_GLOSS "Edge Gloss Intensity" 0.20 0.0 1.0 0.05
#pragma parameter CURVE_VAL "Glass Curvature" 0.15 0.0 0.5 0.01

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

varying vec2 vTexCoord;
uniform sampler2D Texture;
uniform vec2 TextureSize, InputSize;

#ifdef PARAMETER_UNIFORM
uniform float GLASS_STR, BORDER_GLOSS, CURVE_VAL;
#endif

void main() {
    // إحداثيات منحنية لمحاكاة سطح الزجاج
    vec2 sc = TextureSize / InputSize;
    vec2 p = (vTexCoord * sc) - 0.5;
    
    // محاكاة الانحناء الفيزيائي للزجاج
    float r2 = dot(p, p);
    vec2 p_glass = p * (1.0 + r2 * CURVE_VAL);

    // جلب الصورة الأصلية (التي تحت الزجاج)
    vec3 screen = texture2D(Texture, vTexCoord).rgb;

    // 1. تأثير فرينل (Fresnel): زيادة اللمعة عند الحواف
    float fresnel = pow(r2 * 2.2, 2.0) * BORDER_GLOSS;

    // 2. لمعة الضوء العلوية (Specular Highlight)
    // بقعة ضوء افتراضية في الزاوية العلوية اليسرى
    float spec = smoothstep(0.4, 0.0, length(p_glass - vec2(-0.35, 0.35)));
    spec *= 0.15 * GLASS_STR;

    // 3. وهج خفيف "Static Bloom" (يوحي بوجود ضوء خارجي)
    float gloss = (1.0 - length(p_glass)) * 0.05 * GLASS_STR;

    // دمج الطبقات: الصورة الأصلية + الفرينل + اللمعة + الوهج
    vec3 final_color = screen + fresnel + spec + gloss;

    // قص الأطراف لضمان عدم ظهور الانعكاس خارج حدود الشاشة المنحنية
    if (abs(p_glass.x) > 0.5 || abs(p_glass.y) > 0.5) {
        final_color = vec4(0.0, 0.0, 0.0, 1.0).rgb;
    }

    gl_FragColor = vec4(final_color, 1.0);
}
#endif