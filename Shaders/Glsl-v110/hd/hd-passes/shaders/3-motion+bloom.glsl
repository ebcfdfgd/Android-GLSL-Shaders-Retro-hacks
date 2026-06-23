#version 110
#pragma parameter MOTION_BLUR "Motion Blur" 0.00 0.00 1.00 0.01
#pragma parameter BLOOM_STR "Bloom" 0.50 0.00 3.00 0.05
#pragma parameter SOFT_BLOOM "Soft Bloom" 0.75 0.00 3.00 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord; attribute vec2 TexCoord; varying vec2 uv; uniform mat4 MVPMatrix;
void main() { uv = TexCoord; gl_Position = MVPMatrix * VertexCoord; }
#elif defined(FRAGMENT)
precision highp float;
varying vec2 uv; uniform sampler2D Texture; uniform vec2 TextureSize;
uniform float MOTION_BLUR, BLOOM_STR, SOFT_BLOOM;
float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

void main() {
    vec2 px = 1.0 / TextureSize;
    vec3 col = texture2D(Texture, uv).rgb;
    vec3 blur = texture2D(Texture, uv + px * 2.0).rgb;
    col += max(lum(blur) - SOFT_BLOOM, 0.0) * BLOOM_STR;
    col = mix(col, blur, MOTION_BLUR * 0.3);
    gl_FragColor = vec4(col, 1.0);
}
#endif