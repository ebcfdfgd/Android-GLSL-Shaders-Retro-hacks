#version 110

/* 777-LITE-TURBO-V13-TRUE-RGB-W
    - MASK: EXACT CLONE OF CODE 7 (Mathematical Phosphor Logic).
    - FEATURE: Added MASK_W to control RGB Scale (3=Standard, 6=Wide).
    - PERFORMANCE: Branchless mask logic for smoother performance.
*/

#pragma parameter BARREL_DISTORTION "Screen Curve (0=OFF)" 0.15 0.0 1.0 0.02
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.30 1.0 2.5 0.05
#pragma parameter VIG_STR "Vignette Intensity (0=OFF)" 0.35 0.0 2.0 0.05
#pragma parameter SCAN_STR "Scanline Intensity (0=OFF)" 0.30 0.0 1.0 0.05

// --- Code 7 Mathematical Mask Parameters ---
#pragma parameter MASK_DARK "Mask Dark Level" 0.5 0.0 1.0 0.05
#pragma parameter MASK_LIGHT "Mask Light Level" 1.5 0.0 2.0 0.05
#pragma parameter MASK_W "Mask Width (3=RGB)" 3.0 1.0 6.0 1.0

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
precision lowp float;
#endif

varying vec2 uv;
uniform sampler2D Texture;
uniform vec2 TextureSize, InputSize;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION, BRIGHT_BOOST, VIG_STR, SCAN_STR, MASK_DARK, MASK_LIGHT;
#endif

void main() {
    vec2 sc = TextureSize / InputSize;
    vec2 p = (uv * sc) - 0.5;
    vec2 p_curved;
    vec2 p2 = p * p;

    // 1. Geometry (Smart Bypass)
    if (BARREL_DISTORTION > 0.0) {
        p_curved = p * (1.0 + vec2(p2.y * (BARREL_DISTORTION * 0.2), p2.x * (BARREL_DISTORTION * 0.8)));
        p_curved *= (1.0 - 0.1 * BARREL_DISTORTION);
    } else {
        p_curved = p;
    }

    if (abs(p_curved.x) > 0.5 || abs(p_curved.y) > 0.5) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    vec2 final_uv = (p_curved + 0.5) / sc;

vec2 uv_pixels = final_uv * TextureSize;

// 2. فصل الجزء الصحيح (i) والجزء العشري (f)
vec2 i = floor(uv_pixels);
vec2 f = uv_pixels - i;

// 3. تطبيق معادلة Smoothstep (بديل التكعيب - أسرع وأخف)
// المعادلة: f * f * (3.0 - 2.0 * f)
vec2 f_smooth = f * f * (3.0 - 2.0 * f);

// 4. دمج الإحداثيات المنعمة وإرجاعها لمساحة الـ UV
vec2 uv_final = (i + f_smooth) / TextureSize;

// 5. سحب العينة النهائي
vec3 res = texture2D(Texture, uv_final).rgb;

    // 3. Vignette
    if (VIG_STR > 0.0) {
        res *= (1.0 - clamp(p2.x * p2.y * 15.0 * VIG_STR, 0.0, 1.0));
    }

    // 4. Scanlines
    if (SCAN_STR > 0.0) {
        float pixel_y = (p_curved.y + 0.5) * InputSize.y;
    
    // إنشاء موجة السكان لاين (خط لكل بكسل لعبة)
    float scan = sin(pixel_y * 6.283185) * 0.5 + 0.5;
    
    // عملية ضرب مباشر (بدون أوفرلاي)
    // mix(1.0, scan, SCAN_STR) تعني: 1.0 عند قوة صفر، و scan عند القوة الكاملة
    res *= mix(1.0, scan, SCAN_STR);
    }

    // 5. TRUE RGB MASK (EXACT CLONE FROM 7)
    // استخدام المعادلة الرياضية الصافية للتحكم في عرض وشدة الألوان
    vec3 mcol = vec3(0.0);
mcol[int(mod(gl_FragCoord.x, 3.0))] = 1.0;

// 2. تطبيق نظام Dark-Light
// الأجزاء اللي قيمتها 1.0 في mcol هتاخد MASK_LIGHT
// الأجزاء اللي قيمتها 0.0 في mcol هتاخد MASK_DARK
vec3 mask_weight = mix(vec3(MASK_DARK), vec3(MASK_LIGHT), mcol);

// 3. اضرب النتيجة النهائية في بكسل الصورة
res *= mask_weight;

    // 6. FINAL STAGE
    gl_FragColor = vec4(res * BRIGHT_BOOST, 1.0);
}
#endif