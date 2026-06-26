#version 110
#pragma parameter AO_STR "Cavity AO" 1.20 0.00 4.00 0.05
#pragma parameter RIM_STR "Rim Light" 1.10 0.00 3.00 0.05
#pragma parameter OUTLINE_STR "Outline" 0.30 0.00 3.00 0.05
#pragma parameter TILTSHIFT_STR "TiltShift" 0.00 0.00 1.00 0.01

#if defined(VERTEX)
attribute vec4 VertexCoord; attribute vec2 TexCoord; varying vec2 uv; uniform mat4 MVPMatrix;
void main() { uv = TexCoord; gl_Position = MVPMatrix * VertexCoord; }
#elif defined(FRAGMENT)
precision highp float;
varying vec2 uv; uniform sampler2D Texture; uniform vec2 TextureSize;
uniform float AO_STR, RIM_STR, OUTLINE_STR, TILTSHIFT_STR;
float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

void main() {
    vec2 px = 1.0 / TextureSize;
    vec3 C = texture2D(Texture, uv).rgb;
    vec3 L = texture2D(Texture, uv-vec2(px.x,0.0)).rgb; vec3 R = texture2D(Texture, uv+vec2(px.x,0.0)).rgb;
    vec3 U = texture2D(Texture, uv-vec2(0.0,px.y)).rgb; vec3 D = texture2D(Texture, uv+vec2(0.0,px.y)).rgb;
    float lc = lum(C); float edge = abs(lum(R)-lum(L)) + abs(lum(D)-lum(U));
    vec3 col = C;
    col = mix(col, vec3(0.0), smoothstep(0.1, 0.35, edge) * OUTLINE_STR);
    col += smoothstep(0.1, 0.45, edge) * RIM_STR * 0.2;
    col = mix(col, (L+R+U+D)*0.25, smoothstep(0.0, 0.45, abs(uv.y-0.5)) * TILTSHIFT_STR);
    gl_FragColor = vec4(col, 1.0);
}
#endif