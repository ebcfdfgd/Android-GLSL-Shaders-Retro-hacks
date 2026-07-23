#version 110

/* STANDALONE-FAST-BLOOM */

#pragma parameter BLOOM_STR "Bloom Intensity" 0.3 0.0 1.0 0.05
#pragma parameter BLOOM_THR "Bloom Threshold" 0.6 0.0 1.0 0.05

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
uniform vec2 TextureSize;
#ifdef PARAMETER_UNIFORM
uniform float BLOOM_STR, BLOOM_THR;
#endif

void main() {
    vec2 px = 1.0 / TextureSize;
    vec3 base = texture2D(Texture, uv).rgb;

    // Fast Bloom Calculation
    vec3 bloom = texture2D(Texture, uv + px).rgb + texture2D(Texture, uv - px).rgb;
    bloom *= 0.5;
    vec3 bloom_final = max(bloom - BLOOM_THR, 0.0) * BLOOM_STR;

    gl_FragColor = vec4(base + bloom_final, 1.0);
}
#endif