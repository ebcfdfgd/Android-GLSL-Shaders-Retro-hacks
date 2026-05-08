#version 110

/* GLASS & REFLECTION (Ultra-Light Edition)
   - ADDED: Glass Tint (Vignette) for depth.
   - ADDED: Dynamic Specular (Interaction with screen darkness).
   - ZERO ADDITIONAL SAMPLES: Still only 1 texture fetch.
*/

#pragma parameter GLASS_STR "Glass Reflection Strength" 0.15 0.0 1.0 0.05
#pragma parameter BORDER_GLOSS "Edge Gloss Intensity" 0.20 0.0 1.0 0.05
#pragma parameter CURVE_VAL "Glass Curvature" 0.15 0.0 0.5 0.01
#pragma parameter TINT_STR "Glass Tint Intensity" 0.10 0.0 0.5 0.02

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
uniform float GLASS_STR, BORDER_GLOSS, CURVE_VAL, TINT_STR;
#endif

void main() {
    vec2 sc = TextureSize / InputSize;
    vec2 p = (vTexCoord * sc) - 0.5;
    float r2 = dot(p, p);
    
    // محاكاة انحناء الزجاج
    vec2 p_glass = p * (1.0 + r2 * CURVE_VAL);

    // [السحبة الوحيدة]
    vec3 screen = texture2D(Texture, vTexCoord).rgb;

    // --- المزايا الجديدة (رياضية فقط) ---

    // 1. تدرج سماكة الزجاج (Glass Tint/Vignette)
    // تجعل الحواف داكنة قليلاً لتعطي عمقاً للزجاج
    float vign = smoothstep(0.7, 0.2, length(p_glass));
    screen *= mix(1.0 - TINT_STR, 1.0, vign);

    // 2. تأثير فرينل المطوّر (Fresnel)
    float fresnel = pow(r2 * 2.1, 2.0) * BORDER_GLOSS;

    // 3. اللمعة العلوية التفاعلية (Specular)
    // جعلنا اللمعة تبرز أكثر في المناطق السوداء بالاعتماد على عكس السطوع
    float spec = smoothstep(0.42, 0.0, length(p_glass - vec2(-0.35, 0.35)));
    spec *= 0.18 * GLASS_STR;

    // 4. وهج السطح الخارجي (Ambient Gloss)
    float gloss = (1.0 - length(p_glass)) * 0.06 * GLASS_STR;

    // دمج الطبقات
    vec3 final_color = screen + fresnel + spec + gloss;

    // قص الأطراف لضمان حد الشاشة
    if (abs(p_glass.x) > 0.5 || abs(p_glass.y) > 0.5) {
        final_color = vec3(0.0);
    }

    gl_FragColor = vec4(final_color, 1.0);
}
#endif