#version 110

/* 777-CRT-ANALOG-MASTER (PERFECT COMPOSITE YIQ PASS)
    - FEATURES: 2-Tap Dither Blur + 2-Tap FULL YIQ Chroma Bleed.
    - LOGIC: Pure NTSC YIQ separation. Luma (Y) stays sharp, while BOTH Chroma channels (I, Q) bleed uniformly.
*/

// Custom Analog Parameters
#pragma parameter CHROMA_BLEED_X "Composite YIQ Shift" 2.5 0.0 7.0 0.1
#pragma parameter BLUR_TAPS "Dither Blur Spread" 1.0 0.0 5.0 0.1

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv;
varying vec2 p_pos; 
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    uv = TexCoord;
    p_pos = TexCoord - 0.5; 
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

uniform sampler2D Texture;
varying vec2 uv, p_pos;

#ifdef PARAMETER_UNIFORM
uniform float CHROMA_BLEED_X, BLUR_TAPS;
#else
#define CHROMA_BLEED_X 2.5
#define BLUR_TAPS 1.0
#endif

// مصفوفاتك الأصلية الصحيحة والمظبوطة بنظام GLSL Column-Major
const mat3 RGB_to_YIQ = mat3(
    0.299,  0.596,  0.211,
    0.587, -0.274, -0.523,
    0.114, -0.322,  0.312
);

const mat3 YIQ_to_RGB = mat3(
    1.0,    1.0,    1.0,
    0.956, -0.272, -1.106,
    0.621, -0.647,  1.703
);

void main() {
    vec2 coord = uv;
    vec2 dx = vec2(1.0 / 256.0, 0.0); 

    vec2 blurX = dx * BLUR_TAPS;
    vec2 bleedX = dx * CHROMA_BLEED_X;

    // --- Tap 1 & 2: الـ Dither Blur المركزي (للحفاظ على حدة الـ Luma Y) ---
    vec3 baseRGB = texture2D(Texture, coord).rgb;
    vec3 blurRGB = texture2D(Texture, coord + blurX).rgb;
    vec3 ditheredRGB = mix(baseRGB, blurRGB, 0.5);
    
    // استخراج اللوما الحادة (Y) من خلطة الديزر المركزية
    vec3 mainYIQ = RGB_to_YIQ * ditheredRGB;
    float Y = mainYIQ.x; 

    // --- Tap 3 & 4: سحبات الكروما الجانبية (يمين وشمال) ---
    vec3 chromaLeftRGB  = texture2D(Texture, coord - bleedX).rgb;
    vec3 chromaRightRGB = texture2D(Texture, coord + bleedX).rgb;
    
    vec3 yiqLeft  = RGB_to_YIQ * chromaLeftRGB;
    vec3 yiqRight = RGB_to_YIQ * chromaRightRGB;

    // الإصلاح الجوهري: دمج السحبات يمين وشمال لقناتي الألوان معاً (I و Q)
    // هذا يضمن أن جميع الألوان (أصفر، أخضر، أزرق، أحمر) تسيل وتتداخل بالتساوي
    float bleedI = mix(yiqLeft.y, yiqRight.y, 0.5);
    float bleedQ = mix(yiqLeft.z, yiqRight.z, 0.5);

    // دمج الكروما المسيلة مع الكروما المركزية لإنتاج مظهر الكومبوزيت التناظري الناعم
    float I = mix(mainYIQ.y, bleedI, 0.5);
    float Q = mix(mainYIQ.z, bleedQ, 0.5);

    // إعادة تجميع الإشارة التناظرية الكاملة (لوما حادة + كروما مسيلة وموزعة بالكامل)
    vec3 finalYIQ = vec3(Y, I, Q);

    // تحويل الإشارة الصافية النهائية إلى RGB لتغذية الشاشة
    vec3 finalRGB = YIQ_to_RGB * finalYIQ;

    gl_FragColor = vec4(clamp(finalRGB, 0.0, 1.0), 1.0);
}
#endif