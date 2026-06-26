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
    
    // سحب البكسل الحالي والمجاور لليمين فقط
    vec3 center = texture2D(Texture, texCoord).rgb;
    vec3 neighbor = texture2D(Texture, texCoord + vec2(px.x, 0.0)).rgb;
    
    // دمج بسيط بناءً على قوة الديثر
    vec3 res = mix(center, (center + neighbor) * 0.5, dither_str);
    
    gl_FragColor = vec4(res, 1.0);
}
#endif