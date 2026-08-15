#version 110

// --- RetroArch Menu Parameters ---
#pragma parameter MW_OUTLINE_STR "Ink Outline Strength" 0.2 0.0 3.0 0.1
#pragma parameter MW_WHITE_PROTECT "White Protection Threshold" 0.75 0.5 1.0 0.02
#pragma parameter MW_CONTRAST "Monochrome Contrast" 1.2 0.5 3.0 0.1
#pragma parameter MW_THRESHOLD "B&W Threshold" 0.4 0.1 0.9 0.05
#pragma parameter MW_RED_SENS "Red Detection Threshold" 0.5 0.1 0.8 0.05

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

#ifdef PARAMETER_UNIFORM
uniform float MW_OUTLINE_STR;
uniform float MW_WHITE_PROTECT;
uniform float MW_CONTRAST;
uniform float MW_THRESHOLD;
uniform float MW_RED_SENS;
#else
#define MW_OUTLINE_STR 1.2
#define MW_WHITE_PROTECT 0.85
#define MW_CONTRAST 1.5
#define MW_THRESHOLD 0.45
#define MW_RED_SENS 0.35
#endif

const vec3 Y = vec3(0.299, 0.587, 0.114);

float getLuma(vec3 col) {
    return dot(col, Y);
}

// Optimized 4-Neighbor Edge Detection (4 fetches here + 1 in main = 5 total fetches)
float detectSobelEdge(sampler2D tex, vec2 coords, vec2 px) {
    float top    = getLuma(texture2D(tex, coords + px * vec2( 0.0, -1.0)).rgb);
    float left   = getLuma(texture2D(tex, coords + px * vec2(-1.0,  0.0)).rgb);
    float right  = getLuma(texture2D(tex, coords + px * vec2( 1.0,  0.0)).rgb);
    float bottom = getLuma(texture2D(tex, coords + px * vec2( 0.0,  1.0)).rgb);

    float gx = 2.0 * (right - left);
    float gy = 2.0 * (bottom - top);

    return sqrt(gx * gx + gy * gy);
}

// Red Isolation Heuristic
float isolateRed(vec3 col) {
    float maxOther = max(col.g, col.b);
    float redDiff = col.r - maxOther;
    float isRed = smoothstep(MW_RED_SENS - 0.1, MW_RED_SENS + 0.1, redDiff);
    
    float maxC = max(col.r, maxOther);
    float minC = min(col.r, min(col.g, col.b));
    float sat = (maxC > 0.0) ? (maxC - minC) / maxC : 0.0;
    
    return isRed * smoothstep(0.25, 0.5, sat);
}

void main() {
    vec2 px = 1.0 / TextureSize;
    vec3 scene = texture2D(Texture, uv).rgb;
    float luma = getLuma(scene);

    // 1. Raw Edge Calculation (4 fetches inside detectSobelEdge)
    float rawEdge = detectSobelEdge(Texture, uv, px) * MW_OUTLINE_STR;

    // 2. White Details Protection Mask
    // Suppresses black ink lines over pure/near-white pixels (eyes, HUD, score)
    float whiteMask = smoothstep(MW_WHITE_PROTECT - 0.1, MW_WHITE_PROTECT + 0.05, luma);
    float protectedEdge = rawEdge * (1.0 - whiteMask);
    protectedEdge = clamp(protectedEdge, 0.0, 1.0);

    // 3. High-Contrast B&W Scene
    float bw = smoothstep(MW_THRESHOLD - (0.5 / MW_CONTRAST), MW_THRESHOLD + (0.5 / MW_CONTRAST), luma);
    vec3 bwColor = vec3(bw);

    // 4. Apply Protected Outline
    vec3 inkedBW = mix(bwColor, vec3(0.0), protectedEdge);

    // Force strict clean white for elements exceeding white protection threshold
    if (luma >= MW_WHITE_PROTECT) {
        inkedBW = vec3(1.0);
    }

    // 5. Isolated Red Pass
    float redMask = isolateRed(scene);
    vec3 pureRed = vec3(scene.r * 1.3, scene.g * 0.05, scene.b * 0.05);

    vec3 finalColor = mix(inkedBW, pureRed, redMask);

    gl_FragColor = vec4(clamp(finalColor, 0.0, 1.0), 1.0);
}
#endif