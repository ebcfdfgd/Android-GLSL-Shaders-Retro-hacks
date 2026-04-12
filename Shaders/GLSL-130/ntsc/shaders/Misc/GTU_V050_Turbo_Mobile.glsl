#version 130

/* --- GTU v0.50 SHARP EDITION (MOBILE OPTIMIZED - v130) ---
   - Sharpness Fix: Original Pixel Restoration
   - Updated: Modern Syntax (in/out/texture)
   - Optimized: Efficient YIQ Reconstruction
*/

#pragma parameter signalResolution "Signal Sharpness (Luma)" 512.0 16.0 1024.0 16.0
#pragma parameter signalResolutionI "Chroma Sharpness I" 128.0 16.0 1024.0 16.0
#pragma parameter signalResolutionQ "Chroma Sharpness Q" 64.0 16.0 1024.0 16.0
#pragma parameter tvVerticalResolution "TV Vertical lines" 480.0 16.0 1024.0 16.0
#pragma parameter blackLevel "Black Level" 0.0 -0.20 0.20 0.01
#pragma parameter contrast "Contrast" 1.0 0.5 1.5 0.01

#if defined(VERTEX)
in vec4 VertexCoord;
in vec2 TexCoord;
out vec2 vTexCoord;
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord;
}

#elif defined(FRAGMENT)
precision highp float;

in vec2 vTexCoord;
out vec4 FragColor;

uniform sampler2D Texture;
uniform vec2 TextureSize;

#ifdef PARAMETER_UNIFORM
uniform float signalResolution, signalResolutionI, signalResolutionQ, tvVerticalResolution, blackLevel, contrast;
#endif

// مصفوفات التحويل الثابتة
const mat3 RGB_to_YIQ = mat3(0.299, 0.587, 0.114, 0.596, -0.274, -0.322, 0.211, -0.523, 0.311);
const mat3 YIQ_to_RGB = mat3(1.0, 0.956, 0.621, 1.0, -0.272, -0.647, 1.0, -1.106, 1.703);

// دالة العينات المحسنة للحفاظ على حدة البكسل الأصلي
vec3 get_signal_sample(vec2 uv, float res) {
    float offset = 1.0 / (res * 2.0); 
    vec3 center = texture(Texture, uv).rgb;
    vec3 side1  = texture(Texture, uv + vec2(offset, 0.0)).rgb;
    vec3 side2  = texture(Texture, uv - vec2(offset, 0.0)).rgb;
    // دمج البكسل الأصلي بنسبة 60% لضمان الحدة (Sharpness)
    return mix(center, (side1 + side2) * 0.5, 0.4);
}

void main() {
    // 1. معالجة الإشارة (Process Signal)
    // تحويل كل عينة إلى فضاء YIQ بشكل منفصل بناءً على الدقة المطلوبة
    vec3 sampleY = get_signal_sample(vTexCoord, signalResolution) * RGB_to_YIQ;
    vec3 sampleI = get_signal_sample(vTexCoord, signalResolutionI) * RGB_to_YIQ;
    vec3 sampleQ = get_signal_sample(vTexCoord, signalResolutionQ) * RGB_to_YIQ;

    // 2. إعادة بناء الإشارة (Reconstruct)
    vec3 yiq;
    yiq.x = sampleY.x; // Luma
    yiq.y = sampleI.y; // Chroma I
    yiq.z = sampleQ.z; // Chroma Q

    // 3. التحويل العكسي وضبط المستويات
    vec3 rgb = clamp(yiq * YIQ_to_RGB, 0.0, 1.0);
    rgb = (rgb - vec3(blackLevel)) * contrast;

    // 4. خطوط المسح النظيفة (Clean Scanlines)
    // تصميم خطوط مسح لا تؤثر على حدة التفاصيل الأفقية
    float vertical_pos = vTexCoord.y * tvVerticalResolution;
    float scanline = abs(sin(vertical_pos * 3.14159265));
    rgb *= mix(1.0, 0.90, scanline);

    FragColor = vec4(rgb, 1.0);
}
#endif