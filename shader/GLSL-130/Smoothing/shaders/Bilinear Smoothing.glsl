#version 130

/* xBR-Bilinear-Wonder: Remake Engine
   - دمج التنعيم الثنائي (Bilinear) يدوياً
   - تحويل الحواف لرسومات Vector (Wonder Style)
   - حماية كاملة من الشاشة السوداء واللاق
*/

#pragma parameter B_SMOOTH "Bilinear Smoothing" 2.7 0.0 3.0 0.1
#pragma parameter W_SMOOTH "Wonder Power" 10.0 1.0 10.0 0.5
#pragma parameter EDGE_SHARP "Edge Sharp" 2.0 0.0 2.0 0.1

#if defined(VERTEX)
#if __VERSION__ >= 130
#define COMPAT_VARYING out
#define COMPAT_ATTRIBUTE in
#else
#define COMPAT_VARYING varying
#define COMPAT_ATTRIBUTE attribute
#endif
COMPAT_ATTRIBUTE vec4 VertexCoord;
COMPAT_ATTRIBUTE vec4 TexCoord;
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
uniform float B_SMOOTH, W_SMOOTH, EDGE_SHARP;
#endif

void main() {
    vec2 pos = TEX0.xy;
    vec2 texel = 1.0 / TextureSize;
    
    // --- محرك الـ Bilinear اليدوي ---
    vec2 f = fract(pos * TextureSize - 0.5);
    vec3 t00 = COMPAT_TEXTURE(Texture, pos + vec2(-0.5, -0.5) * texel).rgb;
    vec3 t10 = COMPAT_TEXTURE(Texture, pos + vec2( 0.5, -0.5) * texel).rgb;
    vec3 t01 = COMPAT_TEXTURE(Texture, pos + vec2(-0.5,  0.5) * texel).rgb;
    vec3 t11 = COMPAT_TEXTURE(Texture, pos + vec2( 0.5,  0.5) * texel).rgb;
    
    vec3 bilinear = mix(mix(t00, t10, f.x), mix(t01, t11, f.x), f.y);
    
    // --- محرك الـ Wonder Vector (النعومة المائية) ---
    vec3 c = COMPAT_TEXTURE(Texture, pos).rgb;
    float edge = distance(t00, t11) + distance(t10, t01);
    
    vec3 wonder = mix(c, bilinear, clamp(edge * W_SMOOTH, 0.0, 1.0));
    
    // دمج النعومة والحدة النهائية
    vec3 final = mix(c, wonder, B_SMOOTH);
    vec3 sharp = final + (final - bilinear) * EDGE_SHARP;
    final = mix(final, sharp, 0.1);

    FragColor = vec4(clamp(final, 0.0, 1.0), 1.0);
}
#endif