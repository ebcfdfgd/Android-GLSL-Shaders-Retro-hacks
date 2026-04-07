#version 110

/*
    Chroma Bleed Only Shader (3-Taps - Backported to 110)
    - Pure Signal Smear: Melts colors horizontally while keeping Luma sharp.
    - Optimized: Uses only 3 YIQ transformations.
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

// البارامتر الوحيد للتحكم في عرض تسييح الألوان
#pragma parameter COL_BLEED "Chroma Spread (Bleed)" 3.0 0.0 20.0 0.1

#ifdef PARAMETER_UNIFORM
uniform float COL_BLEED;
#endif

// مصفوفات التحويل لنظام YIQ (مصوبة لتوافق GLSL 110 Column-Major)
const mat3 RGBtoYIQ = mat3(0.2989, 0.5959, 0.2115, 0.5870, -0.2744, -0.5229, 0.1140, -0.3216, 0.3114);
const mat3 YIQtoRGB = mat3(1.0, 1.0, 1.0, 0.956, -0.2720, -1.1060, 0.6210, -0.6474, 1.7046);

void main() {
    vec2 invSize = 1.0 / TextureSize;
    vec2 uv = vTexCoord;

    // 1. سحب البكسل المركز وتحويله لـ YIQ
    vec3 main_rgb = texture2D(Texture, uv).rgb;
    vec3 yiq = main_rgb * RGBtoYIQ;

    // 2. حساب مسافة الإزاحة (Bleed Offset)
    float b_off = invSize.x * COL_BLEED;

    // 3. سحب عينات الأطراف (اليسار واليمين) وتحويل قنوات اللون فقط
    // نضرب في المصفوفة مباشرة للحصول على قيم YIQ لكل عينة
    vec3 yiqL = texture2D(Texture, uv - vec2(b_off, 0.0)).rgb * RGBtoYIQ;
    vec3 yiqR = texture2D(Texture, uv + vec2(b_off, 0.0)).rgb * RGBtoYIQ;

    // 4. دمج قنوات الألوان (I و Q) فقط
    // نأخذ متوسط قنوات اللون من العينات الثلاث (المركز + اليسار + اليمين)
    vec2 chroma_melted = (yiq.gb + yiqL.gb + yiqR.gb) * 0.3333;

    // 5. إعادة التجميع (Final Assembly)
    // نستخدم Y (السطوع) من البكسل الأصلي لتبقى الحواف حادة
    // ونستخدم الكروما المذابة (chroma_melted) لإعطاء تأثير النزيف
    vec3 final_yiq = vec3(yiq.r, chroma_melted.x, chroma_melted.y);

    // 6. التحويل العكسي لـ RGB للتمرير للشاشة
    vec3 final_rgb = final_yiq * YIQtoRGB;

    gl_FragColor = vec4(clamp(final_rgb, 0.0, 1.0), 1.0);
}
#endif