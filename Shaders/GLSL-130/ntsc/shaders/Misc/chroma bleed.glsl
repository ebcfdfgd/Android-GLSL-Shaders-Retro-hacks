#version 130

/*
    Chroma Bleed Only Shader (3-Taps)
    بناءً على طلبك: تم حذف كل شيء والإبقاء على تسييح الألوان فقط
*/

#if defined(VERTEX)
in vec4 VertexCoord;
in vec2 TexCoord;
out vec2 vTexCoord;
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord.xy;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

in vec2 vTexCoord;
out vec4 FragColor;

uniform sampler2D Texture;
uniform vec2 TextureSize;

// البارامتر الوحيد المتبقي للتحكم في قوة التسييح
#pragma parameter COL_BLEED "Chroma Spread (Bleed)" 3.0 0.0 20.0 0.1
uniform float COL_BLEED;

// مصفوفات التحويل الثابتة لنظام YIQ
const mat3 RGBtoYIQ = mat3(0.2989, 0.5870, 0.1140, 0.5959, -0.2744, -0.3216, 0.2115, -0.5229, 0.3114);
const mat3 YIQtoRGB = mat3(1.0, 0.956, 0.6210, 1.0, -0.2720, -0.6474, 1.0, -1.1060, 1.7046);

void main() {
    vec2 ps = vec2(1.0 / TextureSize.x, 1.0 / TextureSize.y);
    vec2 uv = vTexCoord;

    // 1. سحب البكسل الأساسي وتحويله لـ YIQ
    vec3 main_rgb = texture(Texture, uv).rgb;
    vec3 yiq = main_rgb * RGBtoYIQ;

    // 2. حساب إزاحة الكروما (Bleed)
    float b_off = ps.x * COL_BLEED;

    // 3. سحب عينة من اليسار وعينة من اليمين (للألوان فقط)
    vec2 chrL = (texture(Texture, uv - vec2(b_off, 0.0)).rgb * RGBtoYIQ).gb;
    vec2 chrR = (texture(Texture, uv + vec2(b_off, 0.0)).rgb * RGBtoYIQ).gb;

    // 4. دمج قنوات الألوان (I و Q) - هذا هو الـ Chroma Bleed
    // نستخدم المتوسط الحسابي لـ 3 سحبات (المركز + اليسار + اليمين)
    vec2 chroma_melted = (yiq.gb + chrL + chrR) * 0.333;

    // 5. إعادة التجميع: نأخذ الـ Luma (السطوع) الأصلي ونضع معه الألوان المذابة
    // yiq.r (الإضاءة) لم تتأثر لتبقى الصورة حادة
    vec3 final_yiq = vec3(yiq.r, chroma_melted.x, chroma_melted.y);

    // 6. التحويل النهائي لـ RGB
    vec3 final_rgb = final_yiq * YIQtoRGB;

    FragColor = vec4(clamp(final_rgb, 0.0, 1.0), 1.0);
}
#endif