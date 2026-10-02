#version 110

/* STANDALONE-FAST-BLOOM (4 DIRECTIONS) */

#pragma parameter BLOOM_STR "Bloom Intensity" 0.3 0.0 1.0 0.05
#pragma parameter BLOOM_THR "Bloom Threshold" 0.6 0.0 1.0 0.05
#pragma parameter BLOOM_RADIUS "Bloom Radius" 1.0 1.0 10.0 0.5

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
uniform float BLOOM_STR, BLOOM_THR, BLOOM_RADIUS;
#endif

void main() {
    // Offset for 4 directions (Right, Left, Up, Down) based on Bloom Radius
    vec2 px = (1.0 / TextureSize) * BLOOM_RADIUS;
    vec3 base = texture2D(Texture, uv).rgb;

    // Fast 4-Direction Bloom Calculation
    vec3 bloom = texture2D(Texture, uv + vec2(px.x, 0.0)).rgb + 
                 texture2D(Texture, uv - vec2(px.x, 0.0)).rgb + 
                 texture2D(Texture, uv + vec2(0.0, px.y)).rgb + 
                 texture2D(Texture, uv - vec2(0.0, px.y)).rgb;
    bloom *= 0.25;
    vec3 bloom_final = max(bloom - BLOOM_THR, 0.0) * BLOOM_STR;

    gl_FragColor = vec4(base + bloom_final, 1.0);
}
#endif