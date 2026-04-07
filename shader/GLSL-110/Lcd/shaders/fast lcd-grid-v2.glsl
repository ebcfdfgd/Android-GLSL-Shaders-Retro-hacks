#version 110

/* FAST-LCD-FINAL-V2 (Backported to 110)
    - Optimized: Replaced texelFetch with texture2D for Mali/Adreno compatibility.
    - Feature: High-fidelity Subpixel Brush (S-Curve).
    - Fixed: Loading issues on older GLES 2.0 devices.
*/

// --- PARAMETERS ---
#pragma parameter RSUBPIX_R  "Red Sub: R" 1.0 0.0 1.0 0.01
#pragma parameter GSUBPIX_G  "Green Sub: G" 1.0 0.0 1.0 0.01
#pragma parameter BSUBPIX_B  "Blue Sub: B" 1.0 0.0 1.0 0.01
#pragma parameter gain       "LCD Gain" 1.0 0.5 2.0 0.05
#pragma parameter gamma      "LCD Input Gamma" 3.0 0.5 5.0 0.1
#pragma parameter outgamma   "LCD Output Gamma" 2.2 0.5 5.0 0.1
#pragma parameter blacklevel "Black level" 0.05 0.0 0.5 0.01
#pragma parameter BGR        "BGR Mode" 0 0 1 1

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec4 TexCoord;
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
uniform vec2 TextureSize, OutputSize, InputSize;

#ifdef PARAMETER_UNIFORM
uniform float RSUBPIX_R, GSUBPIX_G, BSUBPIX_B, gain, gamma, outgamma, blacklevel, BGR;
#endif

// دالة التنعيم (الفرشاة الرياضية) لمحاكاة تداخل البكسلات
vec3 S(vec3 x, float dx, float d) {
    vec3 h = clamp((x + dx * 0.5) / d, -1.0, 1.0);
    vec3 l = clamp((x - dx * 0.5) / d, -1.0, 1.0);
    // تقريب تكاملي لمنع الـ Aliasing (التكسر)
    return d * (h * (1.0 - 0.333 * h * h) - l * (1.0 - 0.333 * l * l)) / dx;
}

void main() {
    vec2 ps = 1.0 / TextureSize;
    // حساب الإحداثيات الصحيحة لأخذ العينات يدوياً (بديل texelFetch)
    vec2 pos = vTexCoord / ps - 0.5;
    vec2 fp = floor(pos);
    vec2 uv00 = (fp + 0.5) * ps;
    
    // سحب العينات الأربع المحيطة للبثق الفرعي (Interpolation)
    vec3 g = vec3(gamma);
    vec3 c00 = pow(max(gain * texture2D(Texture, uv00).rgb + blacklevel, 0.0), g);
    vec3 c10 = pow(max(gain * texture2D(Texture, uv00 + vec2(ps.x, 0.0)).rgb + blacklevel, 0.0), g);
    vec3 c01 = pow(max(gain * texture2D(Texture, uv00 + vec2(0.0, ps.y)).rgb + blacklevel, 0.0), g);
    vec3 c11 = pow(max(gain * texture2D(Texture, uv00 + ps).rgb + blacklevel, 0.0), g);

    // حساب إزاحة الـ Subpixel (العرض الرأسي مقسم لـ 3)
    float sx = (pos.x - fp.x) * 3.0;
    float rx = (InputSize.x / OutputSize.x) * 3.0;
    float sy = (pos.y - fp.y);
    float ry = (InputSize.y / OutputSize.y);

    // فرشاة التلوين (Left and Right Phosphors)
    vec3 lc = S(vec3(sx + 1.0, sx, sx - 1.0), rx, 1.5);
    vec3 rc = S(vec3(sx - 2.0, sx - 3.0, sx - 4.0), rx, 1.5);
    
    // دعم وضع BGR لشاشات معينة
    if (BGR > 0.5) {
        lc = lc.bgr;
        rc = rc.bgr;
    }

    // حساب وزن الإضاءة الرأسية (Scanline feel for LCD)
    float tw = S(vec3(sy), ry, 0.63).x;
    float bw = S(vec3(sy - 1.0), ry, 0.63).x;

    // الدمج النهائي للعينات مع توزيع الـ Subpixels
    vec3 res = (c00 * lc * tw) + (c10 * rc * tw) + (c01 * lc * bw) + (c11 * rc * bw);
    
    // تصحيح الـ Gamma النهائي للإخراج
    gl_FragColor = vec4(pow(max(res, 0.0), vec3(1.0 / outgamma)), 1.0);
}
#endif