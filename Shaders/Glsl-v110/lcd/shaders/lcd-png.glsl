#version 110

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 vTexCoord, screen_scale;
uniform mat4 MVPMatrix;
uniform vec2 TextureSize, InputSize;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord.xy;
    // نفس المنطق بالضبط:
    screen_scale = TextureSize / InputSize;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 vTexCoord, screen_scale;
uniform sampler2D Texture; // صورة اللعبة
uniform sampler2D overlay; // صورة الماسك (Overlay)
uniform vec2 OutputSize;   // أبعاد الشاشة الحقيقية

// --- Parameters ---
#pragma parameter MASK_STR "Mask Strength" 0.5 0.0 1.0 0.05
#pragma parameter LUTWidth "Mask Width (px)" 6.0 1.0 1024.0 1.0
#pragma parameter LUTHeight "Mask Height (px)" 6.0 1.0 1024.0 1.0
#pragma parameter GBA_BRIGHT_BST "Final Brightness Boost" 1.0 1.0 2.0 0.05

#ifdef PARAMETER_UNIFORM
uniform float MASK_STR, LUTWidth, LUTHeight, GBA_BRIGHT_BST;
#endif

void main() {
    // 1. سحب لون اللعبة الخام
    vec3 col = texture2D(Texture, vTexCoord).rgb;

    // 2. حساب إحداثيات الماسك (مطابقة تماماً لمنطق LIGHT-ULTIMATE)
    // حساب mP بناءً على إحداثيات الشاشة و الـ scale
    vec2 mP = vTexCoord * screen_scale;
    
    // حساب maskUV بنفس طريقة توزيع الـ LUT في الشيدر الثاني
    vec2 maskUV = vec2(fract(mP.x * OutputSize.x / LUTWidth), 
                       fract(mP.y * OutputSize.y / LUTHeight));

    // 3. سحب لون الماسك
    vec3 maskCol = texture2D(overlay, maskUV).rgb;

    // 4. الدمج (Mix)
    vec3 final_grid = mix(vec3(1.0), maskCol, MASK_STR);

    // 5. النتيجة النهائية
    gl_FragColor = vec4(clamp(col * final_grid * GBA_BRIGHT_BST, 0.0, 1.0), 1.0);
}
#endif