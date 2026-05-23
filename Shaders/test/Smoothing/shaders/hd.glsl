#version 130

/* xBR-Modern-Masterpiece-Wonder-Logic-Cinematic
   - Cinematic Color Grading (ألوان سينمائية)
   - Wonder Pop (تجسيم بدون سواد)
   - Rim Isolation (فصل الحواف)
   - ACES Tone Mapping (محاكاة محركات الريندر الحديثة)
*/

#pragma parameter W_SMOOTH "Wonder Smoothness" 12.0 1.0 20.0 0.5
#pragma parameter DITHER_STR "Dither Removal" 0.5 0.0 1.0 0.05
#pragma parameter SHADOW_STR "Deep Shadow Strength" 0.0 0.0 1.5 0.05
#pragma parameter GLOW_STR "Bloom Glow Power" 0.3 0.0 1.0 0.05
#pragma parameter SHARP_STR "Edge Sharpness" 0.5 0.0 1.0 0.05
#pragma parameter CHROMA_STR "Chromatic Aberration" 0.0015 0.0 0.01 0.0005
#pragma parameter CONTRAST_STR "Color Contrast" 1.15 1.0 1.5 0.05
#pragma parameter SATURATION_STR "Color Saturation" 1.2 1.0 2.0 0.05
#pragma parameter VIGNETTE_STR "Vignette Strength" 0.15 0.0 0.5 0.01
#pragma parameter RIM_STR "Dynamic Rim Light" 0.40 0.0 1.5 0.05

// --- إعدادات السينما المضافة ---
#pragma parameter C_WARMTH "Cinematic Warmth" 0.05 -0.20 0.20 0.01
#pragma parameter C_TINT "Shadow Tint (Blue-ish)" 0.03 0.0 0.20 0.01

#if defined(VERTEX)
#if __VERSION__ >= 130
#define COMPAT_VARYING out
#define COMPAT_ATTRIBUTE in
#else
#define COMPAT_VARYING varying
#define COMPAT_ATTRIBUTE attribute
#endif
COMPAT_ATTRIBUTE vec4 VertexCoord, TexCoord;
COMPAT_VARYING vec4 TEX0;
uniform mat4 MVPMatrix;
void main() {
    gl_Position = MVPMatrix * VertexCoord;
    TEX0.xy = TexCoord.xy;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif
#if __VERSION__ >= 130
#define COMPAT_VARYING in
#define COMPAT_TEXTURE texture
out vec4 FragColor;
#else
#define COMPAT_VARYING varying
#define FragColor gl_FragColor
#define COMPAT_TEXTURE texture2D
#endif

uniform vec2 TextureSize;
uniform sampler2D Texture;
COMPAT_VARYING vec4 TEX0;

#ifdef PARAMETER_UNIFORM
uniform float W_SMOOTH, DITHER_STR, SHADOW_STR, GLOW_STR, SHARP_STR, CHROMA_STR, CONTRAST_STR, SATURATION_STR, VIGNETTE_STR, RIM_STR;
uniform float C_WARMTH, C_TINT;
#endif

// دالة تصحيح الألوان السينمائية (ACES Tone Mapping خفيف)
vec3 ACESToneMapping(vec3 x) {
    float a = 2.51;
    float b = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;
    return clamp((x*(a*x+b))/(x*(c*x+d)+e), 0.0, 1.0);
}

void main() {
    vec2 pos = TEX0.xy;
    vec2 t = 1.0 / TextureSize;
    
    // سحب العينات مع Chromatic Aberration
    float r_ch = COMPAT_TEXTURE(Texture, pos + vec2(CHROMA_STR, 0.0)).r;
    float g_ch = COMPAT_TEXTURE(Texture, pos).g;
    float b_ch = COMPAT_TEXTURE(Texture, pos - vec2(CHROMA_STR, 0.0)).b;
    vec3 c = vec3(r_ch, g_ch, b_ch);

    vec3 n = COMPAT_TEXTURE(Texture, pos + vec2(0, -t.y)).rgb;
    vec3 s = COMPAT_TEXTURE(Texture, pos + vec2(0, t.y)).rgb;
    vec3 w = COMPAT_TEXTURE(Texture, pos + vec2(-t.x, 0)).rgb;
    vec3 e = COMPAT_TEXTURE(Texture, pos + vec2(t.x, 0)).rgb;

    // --- 1. Wonder Smooth Engine ---
    vec3 dither_clean = mix(c, (n + s + w + e) * 0.25, DITHER_STR);
    vec3 avg = (n + s + w + e + dither_clean) * 0.2;
    float edge = distance(dither_clean, avg);
    vec3 smooth_res = mix(dither_clean, avg, clamp(edge * W_SMOOTH, 0.0, 1.0));

    // --- 2. Smart Edge Sharpness ---
    vec3 sharp_res = smooth_res + (smooth_res - avg) * SHARP_STR;

    // --- 3. Wonder Depth Logic ---
    float diff = distance(n, s) + distance(w, e);
    float rim_glow = clamp(diff, 0.0, 1.0) * RIM_STR;
    vec3 shadowed = sharp_res * (1.0 - (1.0 - smoothstep(0.0, 0.5, diff)) * SHADOW_STR * 0.2);
    vec3 rim_res = shadowed + (shadowed * rim_glow);

    // --- 4. محرك الألوان السينمائي المطور ---
    // تطبيق الـ Bloom أولاً
    vec3 bloomed = rim_res + (rim_res * rim_res * GLOW_STR);
    
    // تصحيح الألوان (ACES) ليعطي مظهر الـ CG
    vec3 cine_color = ACESToneMapping(bloomed * CONTRAST_STR);

    // إضافة الـ Warmth (للإضاءة الفاتحة) والـ Tint (للظلال)
    float luma = dot(cine_color, vec3(0.299, 0.587, 0.114));
    cine_color.r += C_WARMTH * luma;
    cine_color.b += C_TINT * (1.0 - luma);

    // Saturation
    vec3 saturated = mix(vec3(luma), cine_color, SATURATION_STR);

    // Vignette
    float dist = distance(pos, vec2(0.5, 0.5));
    vec3 final = saturated * (1.0 - dist * VIGNETTE_STR);

    FragColor = vec4(clamp(final, 0.0, 1.0), 1.0);
}
#endif