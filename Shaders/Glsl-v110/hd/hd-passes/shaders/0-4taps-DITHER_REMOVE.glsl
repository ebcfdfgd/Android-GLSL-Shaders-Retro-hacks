#version 110

#pragma parameter dither_str "Dither Removal Strength" 1.0 0.0 2.0 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord; attribute vec4 TexCoord; varying vec2 texCoord; uniform mat4 MVPMatrix;
void main() { gl_Position = MVPMatrix * VertexCoord; texCoord = TexCoord.xy; }

#elif defined(FRAGMENT)
precision mediump float;
varying vec2 texCoord; uniform sampler2D Texture; uniform vec2 TextureSize;
uniform float dither_str;

void main() {
    vec2 px = 1.0 / TextureSize;
    
    // [1] 4-WAY SAMPLING (سحب البكسل المركزي والمحيط الأربعة: يمين، شمال، فوق، تحت)
    vec3 center = texture2D(Texture, texCoord).rgb;
    vec3 col_r  = texture2D(Texture, texCoord + vec2(px.x, 0.0)).rgb; // يمين
    vec3 col_l  = texture2D(Texture, texCoord - vec2(px.x, 0.0)).rgb; // شمال
    vec3 col_u  = texture2D(Texture, texCoord + vec2(0.0, px.y)).rgb; // فوق
    vec3 col_d  = texture2D(Texture, texCoord - vec2(0.0, px.y)).rgb; // تحت
    
    // [2] OMNIDIRECTIONAL BLUR (دمج خماسي الأبعاد يدمج الألوان بالتساوي في كل الاتجاهات)
    vec3 dither_blur = (center + col_r + col_l + col_u + col_d) * 0.2;
    
    // [3] دمج التأثير بسلاسة بناءً على قوة السلايدر
    vec3 res = mix(center, dither_blur, dither_str);
    
    gl_FragColor = vec4(res, 1.0);
}
#endif