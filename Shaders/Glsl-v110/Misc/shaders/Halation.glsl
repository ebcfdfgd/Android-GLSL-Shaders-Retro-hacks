#version 110

/* STANDALONE-FAST-HALATION */

#pragma parameter HALATION_STR "Halation Intensity" 0.4 0.0 2.0 0.05
#pragma parameter HALATION_THR "Halation Threshold" 0.6 0.0 1.0 0.05

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
uniform float HALATION_STR, HALATION_THR;
#endif

float luma(vec3 c) {
    return dot(c, vec3(0.299, 0.587, 0.114));
}

void main() {
    vec2 px = 1.0 / TextureSize;
    vec3 base = texture2D(Texture, uv).rgb;

    // Fast Halation calculation using nearby samples
    vec3 halo_sample = texture2D(Texture, uv + px).rgb + texture2D(Texture, uv - px).rgb;
    halo_sample *= 0.5;

    // Threshold and masking based on luminance
    float haloLuma = luma(halo_sample);
    float haloMask = smoothstep(HALATION_THR - 0.1, HALATION_THR + 0.1, haloLuma);
    
    // Apply warm reddish-orange/golden tint characteristic of film halation
    vec3 halo_color = halo_sample * vec3(1.3, 0.8, 0.5) * haloMask;

    vec3 final_color = base + halo_color * HALATION_STR;

    gl_FragColor = vec4(final_color, 1.0);
}
#endif