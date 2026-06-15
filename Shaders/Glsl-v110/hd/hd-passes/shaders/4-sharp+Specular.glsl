#version 110
#pragma parameter SHARPEN_STR "Sharpness" 1.00 0.00 3.00 0.05
#pragma parameter SPECULAR_STR "Micro Specular" 1.00 0.00 3.00 0.05
#pragma parameter RAY_STR " Rays" 0.20 0.00 3.00 0.05
#pragma parameter FLARE_STR "Lens Flare" 0.30 0.00 3.00 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord; attribute vec2 TexCoord; varying vec2 uv; uniform mat4 MVPMatrix;
void main() { uv = TexCoord; gl_Position = MVPMatrix * VertexCoord; }
#elif defined(FRAGMENT)
precision highp float;
varying vec2 uv; uniform sampler2D Texture; uniform vec2 TextureSize;
uniform float SHARPEN_STR, SPECULAR_STR, RAY_STR, FLARE_STR;
float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

void main() {
    vec3 col = texture2D(Texture, uv).rgb;
    float lc = lum(col);
    col += pow(max(lc-0.65, 0.0), 4.0) * SPECULAR_STR;
    col += max(lum(texture2D(Texture, mix(uv, vec2(0.5, 0.2), 0.05)).rgb)-0.6, 0.0) * RAY_STR;
    col += max(lum(texture2D(Texture, 1.0-uv).rgb)-0.75, 0.0) * FLARE_STR;
    gl_FragColor = vec4(col, 1.0);
}
#endif