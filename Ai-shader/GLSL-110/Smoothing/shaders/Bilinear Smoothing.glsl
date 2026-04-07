#version 110

/* xBR-Bilinear-Wonder: Remake Engine (Backported to 110)
   - محرك تنعيم ثنائي (Bilinear) يدوي عالي الدقة.
   - تحويل الحواف لرسومات Vector (Wonder Style) ناعمة.
   - حماية كاملة من الشاشة السوداء وتوافق تام مع أجهزة أندرويد.
*/

// --- PARAMETERS ---
#pragma parameter B_SMOOTH "Bilinear Smoothing" 2.7 0.0 3.0 0.1
#pragma parameter W_SMOOTH "Wonder Power" 10.0 1.0 10.0 0.5
#pragma parameter EDGE_SHARP "Edge Sharp" 2.0 0.0 2.0 0.1

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 TEX0;
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    TEX0 = TexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 TEX0;
uniform sampler2D Texture;
uniform vec2 TextureSize;

#ifdef PARAMETER_UNIFORM
uniform float B_SMOOTH, W_SMOOTH, EDGE_SHARP;
#endif

void main() {
    vec2 pos = TEX0.xy;
    vec2 texel = 1.0 / TextureSize;
    
    // --- محرك الـ Bilinear اليدوي (Manual Bilinear Engine) ---
    // حساب الكسور لتحديد موضع البكسل بين الجيران الأربعة
    vec2 f = fract(pos * TextureSize - 0.5);
    
    // سحب العينات الأربعة المحيطة بالبكسل
    vec3 t00 = texture2D(Texture, pos + vec2(-0.5, -0.5) * texel).rgb;
    vec3 t10 = texture2D(Texture, pos + vec2( 0.5, -0.5) * texel).rgb;
    vec3 t01 = texture2D(Texture, pos + vec2(-0.5,  0.5) * texel).rgb;
    vec3 t11 = texture2D(Texture, pos + vec2( 0.5,  0.5) * texel).rgb;
    
    // عملية الدمج الخطي (Linear Interpolation)
    vec3 bilinear = mix(mix(t00, t10, f.x), mix(t01, t11, f.x), f.y);
    
    // --- محرك الـ Wonder Vector (النعومة المائية) ---
    vec3 c = texture2D(Texture, pos).rgb;
    
    // حساب قوة الحافة بناءً على الفرق اللوني بين الأقطار
    float edge = distance(t00, t11) + distance(t10, t01);
    
    // دمج الصورة الأصلية مع التنعيم بناءً على قوة الحواف
    vec3 wonder = mix(c, bilinear, clamp(edge * W_SMOOTH, 0.0, 1.0));
    
    // دمج النعومة والحدة النهائية (Final Synthesis)
    vec3 final = mix(c, wonder, B_SMOOTH * 0.33); // تقليل المعامل ليتناسب مع 110
    
    // إضافة حدة للأطراف المتباينة لمنع الضبابية الزائدة
    vec3 sharp = final + (final - bilinear) * (EDGE_SHARP * 0.5);
    final = mix(final, sharp, 0.1);

    gl_FragColor = vec4(clamp(final, 0.0, 1.0), 1.0);
}
#endif