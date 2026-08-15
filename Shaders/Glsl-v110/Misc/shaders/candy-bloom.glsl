// Candy Bloom - Adapted for #version 110

#pragma parameter GlowLevel "Glow Level" 1.15 1.0 1.5 0.05
#pragma parameter GlowTightness "Glow Tightness" 0.75 0.0 2.0 0.05

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
precision highp float;
#endif

varying vec2 uv;
uniform sampler2D Texture;
uniform vec2 TextureSize, InputSize;

#ifdef PARAMETER_UNIFORM
uniform float GlowLevel, GlowTightness;
#else
#define GlowLevel 1.25
#define GlowTightness 0.75
#endif

void main() {
    // جلب اللون من النسيج
    vec3 Picture = texture2D(Texture, uv).rgb;

    // حساب الإضاءة (Luminance) بناءً على معايير YIQ
    float YIQLuminance = dot(vec3(0.3, 0.6, 0.1), Picture);
    
    // دمج التأثير بناءً على سطوع البكسل
    vec3 res = mix(Picture * GlowTightness, Picture * GlowLevel, YIQLuminance);

    gl_FragColor = vec4(res, 1.0);
}
#endif