#version 110

#pragma parameter SGPT_BLEND_LEVEL "Blend Level" 1.0 0.0 1.0 0.05

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
precision mediump float;
#endif

varying vec2 uv;
uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform float SGPT_BLEND_LEVEL;

const vec3 Y = vec3(0.299, 0.587, 0.114);

void main() {
    vec2 dx = vec2(1.0 / TextureSize.x, 0.0);

    // [1] قراءة البكسلات (3 سحبات)
    vec3 C = texture2D(Texture, uv).rgb;
    vec3 L = texture2D(Texture, uv - dx).rgb;
    vec3 R = texture2D(Texture, uv + dx).rgb;

    // [2] حساب الفروقات (بدون كونتراست)
    vec3 diffL = C - L;
    vec3 diffR = C - R;
    
    // تحديد أي جانب هو "الأقرب" أو الأقل حدة للدمج معه
    float wL = dot(abs(diffL), Y);
    float wR = dot(abs(diffR), Y);

    // [3] الدمج المباشر (Direct Blend)
    // ندمج بناءً على الـ SGPT_BLEND_LEVEL مباشرة دون حسابات إضافية
    vec3 color = (wR < wL) ? (C - 0.5 * SGPT_BLEND_LEVEL * diffR) 
                           : (C - 0.5 * SGPT_BLEND_LEVEL * diffL);

    // [4] Clamp نهائي لحماية الألوان من الخروج عن النطاق
    gl_FragColor = vec4(clamp(color, min(C, min(L, R)), max(C, max(L, R))), 1.0);
}
#endif