#version 110

#pragma parameter SGPT_BLEND_LEVEL "Blend Level" 1.0 0.0 1.0 0.05
#pragma parameter ENABLE_MONO "Monochrome / B&W Mode (0=Off, 1=On)" 0.0 0.0 1.0 1.0
#pragma parameter COLOR_SATURATION "Color Saturation (Cartoon Pop)" 1.5 0.0 3.0 0.05
#pragma parameter LINE_THRESHOLD "Line Art Threshold" 0.15 0.0 1.0 0.01
#pragma parameter WHITE_PROTECT "White Protection Threshold" 0.80 0.5 1.0 0.01
#pragma parameter LINE_SMOOTHNESS "Line Smoothness (Vector Anti-aliasing)" 0.05 0.0 1.0 0.05
#pragma parameter EDGE_CONTRAST "Edge Contrast Multiplier" 1.0 0.5 2.0 0.1
#pragma parameter OUTLINE_STRENGTH "Outline Strength" 1.0 0.0 3.0 0.05
#pragma parameter COLOR_LEVELS "Color Reduction Levels (0 = Off)" 0.0 0.0 32.0 1.0
#pragma parameter scanline_amount "Scanline Amount" 0.12 0.0 0.5 0.02
#pragma parameter scanline_scale "Scanline Density" 1.0 1.0 4.0 0.5

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
precision mediump float;
#endif

varying vec2 uv;
uniform sampler2D Texture;
uniform vec2 TextureSize;

uniform float SGPT_BLEND_LEVEL;
uniform float ENABLE_MONO;
uniform float COLOR_SATURATION;
uniform float LINE_THRESHOLD;
uniform float WHITE_PROTECT;
uniform float LINE_SMOOTHNESS;
uniform float EDGE_CONTRAST;
uniform float OUTLINE_STRENGTH;
uniform float COLOR_LEVELS;
uniform float scanline_amount;
uniform float scanline_scale;

const vec3 Y = vec3(0.299, 0.587, 0.114);

// Scanline Pattern Generator
float scanlinePattern(vec2 fragCoord, float scale) {
    float line =
        sin(
            fragCoord.y / scale *
            3.14159
        );

    return line * 0.5 + 0.5;
}

void main() {
    vec2 dx = vec2(1.0 / TextureSize.x, 0.0);
    vec2 dy = vec2(0.0, 1.0 / TextureSize.y);

    // [1] Fetch center pixel
    vec3 C = texture2D(Texture, uv).rgb;

    // [2] White Protection to keep pure/near white untouched automatically
    float maxChannel = max(C.r, max(C.g, C.b));
    if (maxChannel >= WHITE_PROTECT) {
        gl_FragColor = vec4(C, 1.0);
        return;
    }

    // Fetch surrounding textures
    vec3 L = texture2D(Texture, uv - dx).rgb;
    vec3 R = texture2D(Texture, uv + dx).rgb;
    vec3 U = texture2D(Texture, uv - dy).rgb;
    vec3 D = texture2D(Texture, uv + dy).rgb;

    // [3] SGPT Blend Logic
    vec3 diffL = C - L;
    vec3 diffR = C - R;

    float wL = dot(abs(diffL), Y);
    float wR = dot(abs(diffR), Y);
    
    vec3 color = (wR < wL) ? (C - 0.5 * SGPT_BLEND_LEVEL * diffR) 
                         : (C - 0.5 * SGPT_BLEND_LEVEL * diffL);
                         
    color = clamp(color, min(C, min(L, R)), max(C, max(L, R)));

    // [4] Color Processing (Monochrome or Cartoon Saturation Pop)
    if (ENABLE_MONO > 0.5) {
        color = vec3(dot(color, Y));
    } else {
        float lumaVal = dot(color, Y);
        color = mix(vec3(lumaVal), color, COLOR_SATURATION);
    }

    // [5] Color Reduction (Posterization / Ink Tones in Mono)
    if (COLOR_LEVELS > 1.0) {
        color = floor(color * COLOR_LEVELS + 0.5) / COLOR_LEVELS;
    }

    // [6] Advanced Line Art Features
    float lumaL = dot(L, Y);
    float lumaR = dot(R, Y);
    float lumaU = dot(U, Y);
    float lumaD = dot(D, Y);
    
    float edge = (abs(lumaL - lumaR) + abs(lumaU - lumaD)) * EDGE_CONTRAST;
    
    float line = smoothstep(LINE_THRESHOLD - LINE_SMOOTHNESS, LINE_THRESHOLD + LINE_SMOOTHNESS, edge);

    // [7] Apply Outline Strength
    line = clamp(line * OUTLINE_STRENGTH, 0.0, 1.0);

    // [8] Final Compositing
    vec3 finalColor = mix(color, vec3(0.0), line);

    // [9] Scanlines
    float scan =
        scanlinePattern(
            uv * TextureSize,
            scanline_scale
        );

    finalColor *= mix(
        1.0,
        scan,
        scanline_amount
    );

    gl_FragColor = vec4(clamp(finalColor, 0.0, 1.0), 1.0);
}
#endif