#version 110

/* NTSC-RGB-CONVERGENCE-WITH-BLOOM */

#pragma parameter R_OFF_X "Red Offset X" 1.0 -3.0 3.0 0.05
#pragma parameter R_OFF_Y "Red Offset Y" 0.5 -3.0 3.0 0.05
#pragma parameter G_OFF_X "Green Offset X" -1.0 -3.0 3.0 0.05
#pragma parameter G_OFF_Y "Green Offset Y" -0.5 -3.0 3.0 0.05
#pragma parameter B_OFF_X "Blue Offset X" 0.0 -3.0 3.0 0.05
#pragma parameter B_OFF_Y "Blue Offset Y" 1.0 -3.0 3.0 0.05
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
uniform float R_OFF_X, R_OFF_Y, G_OFF_X, G_OFF_Y, B_OFF_X, B_OFF_Y, BLOOM_STR, BLOOM_THR;
#endif

void main() {
    vec2 px = 1.0 / TextureSize;
    
    // Separate 3-channel RGB Sampling
    float r = texture2D(Texture, uv + vec2(R_OFF_X, R_OFF_Y) * px).r;
    float g = texture2D(Texture, uv + vec2(G_OFF_X, G_OFF_Y) * px).g;
    float b = texture2D(Texture, uv + vec2(B_OFF_X, B_OFF_Y) * px).b;
    vec3 res = vec3(r, g, b);

    // Fast Bloom Calculation
    vec3 bloom = texture2D(Texture, uv + px).rgb + texture2D(Texture, uv - px).rgb;
    bloom *= 0.5;
    vec3 bloom_final = max(bloom - BLOOM_THR, 0.0) * BLOOM_STR;

    gl_FragColor = vec4(res + bloom_final, 1.0);
}
#endif