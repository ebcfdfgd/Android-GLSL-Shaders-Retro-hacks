#version 110

// --- Parameters ---
#pragma parameter GEOM_SMOOTH "Geometry Smoothing" 0.30 0.00 1.00 0.05
#pragma parameter JITTER_STRENGTH "Jitter Stabilization" 0.50 0.00 1.00 0.05
#pragma parameter AA_STRENGTH "Anti-Aliasing" 0.50 0.00 1.00 0.05

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
precision highp float;
varying vec2 uv;
uniform sampler2D Texture;
uniform sampler2D Prev; // الفريم السابق للتثبيت الزمني
uniform vec2 TextureSize;
uniform float GEOM_SMOOTH, JITTER_STRENGTH, AA_STRENGTH;

float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

void main() {
    vec2 px = 1.0 / TextureSize;
    vec3 col = texture2D(Texture, uv).rgb;
    
    // 1. أخذ عينات للمحيط لتحسين المضلعات وتنعيم الحواف
    vec3 L = texture2D(Texture, uv - vec2(px.x, 0.0)).rgb;
    vec3 R = texture2D(Texture, uv + vec2(px.x, 0.0)).rgb;
    vec3 U = texture2D(Texture, uv - vec2(0.0, px.y)).rgb;
    vec3 D = texture2D(Texture, uv + vec2(0.0, px.y)).rgb;
    
    // 2. هندسة تنعيم المضلعات (Smart Blur)
    float luma = lum(col);
    vec3 blur = (L + R + U + D) * 0.25;
    float edge = abs(luma - lum(blur));
    col = mix(col, blur, GEOM_SMOOTH * (1.0 - edge));
    
    // 3. إزالة السلم (Spatial AA)
    vec3 aa = mix(col, blur, AA_STRENGTH * edge);
    
    // 4. تثبيت الاهتزاز (Temporal Stabilization)
    // هذا الجزء يعتمد على الصورة السابقة (Prev) لتقليل الاهتزاز
    vec3 prevCol = texture2D(Prev, uv).rgb;
    vec3 finalCol = mix(aa, prevCol, JITTER_STRENGTH * 0.5);
    
    gl_FragColor = vec4(finalCol, 1.0);
}
#endif