#version 110

#pragma parameter ia_overscan_percent_x "Horizontal Overscan %" 0.0 -25.0 25.0 1.0
#pragma parameter ia_overscan_percent_y "Vertical Overscan %" 0.0 -25.0 25.0 1.0

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec4 TexCoord;
varying vec2 vTexCoord;
varying vec2 vMin, vMax;
uniform mat4 MVPMatrix;
uniform vec2 InputSize;
uniform vec2 TextureSize;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord.xy;
    
    // حساب نطاق الصورة الفعلي داخل الـ Atlas
    vec2 sizeRatio = InputSize / TextureSize;
    vMin = (TexCoord.xy / InputSize) * 0.0; // نقطة البداية
    vMax = sizeRatio; // نقطة النهاية (عرض وطول اللعبة الحقيقي)
}

#elif defined(FRAGMENT)
precision highp float;
varying vec2 vTexCoord;
varying vec2 vMin, vMax;
uniform sampler2D Texture;
uniform float ia_overscan_percent_x;
uniform float ia_overscan_percent_y;

void main() {
    // 1. حساب المركز
    vec2 center = (vMin + vMax) * 0.5;
    
    // 2. تطبيق الـ Overscan (مع قلب الإشارة ليعمل التصغير بشكل صحيح)
    vec2 scale = 1.0 - vec2(ia_overscan_percent_x, ia_overscan_percent_y) / 100.0;
    vec2 uv = center + (vTexCoord - center) / scale;
    
    // 3. منع ظهور بقية الـ Atlas (الـ Clamp)
    // نتأكد أن الإحداثيات داخل حدود اللعبة فقط
    float mask = step(vMin.x, uv.x) * step(uv.x, vMax.x) * step(vMin.y, uv.y) * step(uv.y, vMax.y);
    
    vec3 res = texture2D(Texture, uv).rgb;
    gl_FragColor = vec4(res * mask, 1.0);
}
#endif