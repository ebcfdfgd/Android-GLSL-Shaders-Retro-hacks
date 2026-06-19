#version 110

#pragma parameter TEXTURE_TAPS "Texture Fetches (1 to 100)" 1.0 1.0 100.0 1.0
#pragma parameter MATH_MODE "Math Function (0=Poly, 1=Pow, 2=Sin, 3=Exp, 4=Exp2)" 0.0 0.0 4.0 1.0
#pragma parameter ITERATIONS "Math Apply Count (1 to 100)" 1.0 1.0 100.0 1.0

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
uniform float TEXTURE_TAPS;
uniform float MATH_MODE;
uniform float ITERATIONS;
#else
#define TEXTURE_TAPS 1.0
#define MATH_MODE 0.0
#define ITERATIONS 1.0
#endif

void main() {
    // 1. Force Cache Misses: Create a pseudo-random offset based on pixel coord and index
    int tap_count = int(TEXTURE_TAPS);
    vec3 accumulated_color = vec3(0.0);
    
    for(int i = 0; i < 100; i++) {
        if (i >= tap_count) break;
        
        // Random-like offset that forces the GPU to jump around memory (No locality)
        float seed = float(i) * 12.9898 + dot(uv, vec2(78.233, 151.718));
        vec2 random_offset = vec2(sin(seed), cos(seed)) * 0.01;
        accumulated_color += texture2D(Texture, uv + random_offset).rgb;
    }
    
    vec3 res = accumulated_color / float(tap_count);
    float luma = dot(res, vec3(0.299, 0.587, 0.114));

    // 2. Prevent Loop Unrolling & Constant Folding
    int math_count = int(ITERATIONS);
    for(int i = 0; i < 100; i++) {
        if (i >= math_count) break;
        
        // Force dependency: The next iteration MUST wait for the previous calculation
        // We incorporate 'luma' and 'float(i)' into the math to ensure it changes every loop
        float mix_factor = luma * float(i) * 0.01;
        
        if (MATH_MODE < 0.5) {
            res = res * (1.92 - 0.92 * res) + mix_factor * 0.01;
        } 
        else if (MATH_MODE < 1.5) {
            res = pow(res, vec3(2.2)) + mix_factor * 0.01;
        } 
        else if (MATH_MODE < 2.5) {
            res = sin(res * 1.57 + mix_factor) + mix_factor * 0.01;
        }
        else if (MATH_MODE < 3.5) {
            res = exp(res + mix_factor) * 0.99; 
        }
        else {
            res = exp2(res + mix_factor) * 0.99;
        }
    }

    gl_FragColor = vec4(res, 1.0);
}
#endif