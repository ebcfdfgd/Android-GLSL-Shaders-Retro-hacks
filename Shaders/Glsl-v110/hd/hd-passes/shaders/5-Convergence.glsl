#version 110

// 3 بارميترز فقط للتحكم في الإزاحة الأفقية لكل قناة
#pragma parameter R_SHIFT "Red Shift" 0.5 -2.0 2.0 0.05
#pragma parameter G_SHIFT "Green Shift" 0.0 -2.0 2.0 0.05
#pragma parameter B_SHIFT "Blue Shift" -0.5 -2.0 2.0 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord; attribute vec2 TexCoord; varying vec2 uv; uniform mat4 MVPMatrix;
void main() { uv = TexCoord; gl_Position = MVPMatrix * VertexCoord; }

#elif defined(FRAGMENT)
precision highp float;
varying vec2 uv;
uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform float R_SHIFT, G_SHIFT, B_SHIFT;

void main() {
    vec2 px = 1.0 / TextureSize;
    
    // سحب القنوات مع تطبيق الإزاحة الأفقية فقط (الأكثر شيوعاً واحترافية)
    float r = texture2D(Texture, uv + vec2(R_SHIFT, 0.0) * px).r;
    float g = texture2D(Texture, uv + vec2(G_SHIFT, 0.0) * px).g;
    float b = texture2D(Texture, uv + vec2(B_SHIFT, 0.0) * px).b;
    
    gl_FragColor = vec4(r, g, b, 1.0);
}
#endif