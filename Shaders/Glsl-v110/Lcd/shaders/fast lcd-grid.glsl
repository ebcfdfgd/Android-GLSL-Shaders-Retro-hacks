#version 110

/* ULTIMATE-LCD-ACCURACY (PRINCE - DUAL GRID CONTROL - Backported to 110)
   - NEW: Independent Vertical and Horizontal Grid Control.
   - Precise Subpixel Geometry for Mobile Screens.
   - Optimized: High-precision calculation for Mali/Adreno GPUs.
*/

// --- PARAMETERS ---
#pragma parameter GRID_WIDTH "LCD Grid Width (Vertical)" 0.4 0.0 1.0 0.05
#pragma parameter GRID_HEIGHT "LCD Grid Height (Horizontal)" 0.4 0.0 1.0 0.05
#pragma parameter SUBPIX_STR "Subpixel Strength" 0.6 0.0 1.0 0.05
#pragma parameter BRIGHTNESS_LCD "LCD Brightness" 1.1 1.0 2.0 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec4 TexCoord;
varying vec2 vTexCoord;
varying vec2 pix_coord;

uniform mat4 MVPMatrix;
uniform vec2 TextureSize;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord.xy;
    // حساب إحداثيات البكسل لتحديد موقع الشبكة بدقة
    pix_coord = vTexCoord * TextureSize;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 vTexCoord;
varying vec2 pix_coord;
uniform sampler2D Texture;

#ifdef PARAMETER_UNIFORM
uniform float GRID_WIDTH, GRID_HEIGHT, SUBPIX_STR, BRIGHTNESS_LCD;
#endif

void main() {
    // 1. سحب اللون الأساسي
    vec3 color = texture2D(Texture, vTexCoord).rgb;

    // 2. حساب المسافة داخل البكسل (Sub-pixel positioning)
    vec2 subpix_pos = fract(pix_coord);
    
    // --- [ التحكم المنفصل في الشبكة ] ---
    // تحديد حدود الخطوط الرأسية (grid_x) والأفقية (grid_y)
    // استخدام smoothstep لضمان نعومة الخطوط ومنع تكسر الحواف (Aliasing)
    float grid_x = smoothstep(0.5 - GRID_WIDTH * 0.5, 0.5 + GRID_WIDTH * 0.5, abs(subpix_pos.x - 0.5));
    float grid_y = smoothstep(0.5 - GRID_HEIGHT * 0.5, 0.5 + GRID_HEIGHT * 0.5, abs(subpix_pos.y - 0.5));
    
    // دمج الخطوط لإنشاء "الشبكة السوداء" التي تفصل بين البكسلات
    float mask = 1.0 - max(grid_x, grid_y);

    // 3. محاكاة الـ Subpixel (توزيع الألوان داخل البكسل الواحد)
    // تحويل موقع X إلى نطاق 3 أجزاء (أحمر، أخضر، أزرق)
    float x_offset = subpix_pos.x * 3.0;
    vec3 weights;
    
    // حساب كثافة كل لون فرعي بناءً على موقعه الأفقي
    weights.r = clamp(1.0 - abs(x_offset - 0.5), 0.0, 1.0);
    weights.g = clamp(1.0 - abs(x_offset - 1.5), 0.0, 1.0) * 0.88;
    weights.b = clamp(1.0 - abs(x_offset - 2.5), 0.0, 1.0) * 1.05;
    
    // دمج قوة الـ Subpixel مع اللون الأصلي
    vec3 subpixel = mix(vec3(1.0), weights * 1.5, SUBPIX_STR);

    // 4. تجميع التأثيرات النهائية
    color *= mask;         // تطبيق شبكة الـ LCD
    color *= subpixel;     // تطبيق ألوان البكسلات الفرعية
    color *= BRIGHTNESS_LCD; // تعويض فقدان السطوع الناتج عن الشبكة

    gl_FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
#endif