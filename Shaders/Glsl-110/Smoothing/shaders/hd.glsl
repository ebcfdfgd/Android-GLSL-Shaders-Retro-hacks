#version 110

/* ULTIMATE SONIC 2026 (Zero-Load Hybrid Edition)
    - PERFORMANCE: Skip heavy math (pow, distance) if features are disabled.
    - OPTIMIZED: Replaced branching with flat logic for Mali/Adreno.
    - NEW: Adaptive Vignette & Skin Protection Bypass.
*/

// --- Parameters ---
#pragma parameter CHROMA_STR "Chroma: Strength (0=OFF)" 0.12 0.0 0.50 0.02
#pragma parameter LENS_DIST "Chroma: Lens Distortion" 0.10 0.0 0.50 0.02
#pragma parameter NTSC_STR "Dither: Eraser Strength" 0.65 0.0 1.0 0.05
#pragma parameter EDGE_SHINE "Light: Edge Specular" 0.45 0.0 1.0 0.05
#pragma parameter SHARP_EDGE "Detail: Modern Sharpen" 0.45 0.0 1.0 0.05
#pragma parameter OUTLINE_STR "Detail: Outline Power" 0.20 0.0 1.0 0.05
#pragma parameter MICRO_AO "Depth: Micro-AO (0=OFF)" 0.35 0.0 1.0 0.05
#pragma parameter AO_SKIN_PROT "Depth: AO Skin Protect" 0.60 0.0 1.0 0.05
#pragma parameter RIM_LIGHT "Light: Rim Strength" 0.65 0.0 2.0 0.05
#pragma parameter BLOOM_GLOW "Light: Bloom (0=OFF)" 0.35 0.0 1.0 0.05
#pragma parameter VIBRANCE "Color: Vibrance" 1.40 1.0 2.0 0.10
#pragma parameter WARMTH "Color: Warmth" 0.0 -0.50 0.50 0.05
#pragma parameter FILMIC "Color: Filmic Look" 0.40 0.0 1.0 0.05
#pragma parameter BLACK_DEPTH "Color: Black Depth" 0.05 -0.10 0.20 0.01
#pragma parameter GAMMA_CORRECT "Color: Gamma (0-Pow)" 1.10 0.50 2.00 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec4 TexCoord;
varying vec2 texCoord;
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    texCoord = TexCoord.xy;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision mediump float;
#endif

varying vec2 texCoord;
uniform sampler2D Texture;
uniform vec2 TextureSize;

#ifdef PARAMETER_UNIFORM
uniform float CHROMA_STR, LENS_DIST, NTSC_STR, EDGE_SHINE, SHARP_EDGE, OUTLINE_STR, MICRO_AO, AO_SKIN_PROT, RIM_LIGHT, BLOOM_GLOW, VIBRANCE;
uniform float WARMTH, FILMIC, BLACK_DEPTH, GAMMA_CORRECT;
#endif

float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

void main()
{
    vec2 px = 1.0 / TextureSize;
    vec3 raw;

    // [1] Chromatic Aberration Bypass
    if (CHROMA_STR > 0.0) {
        vec2 lensDist = (texCoord - 0.5) * LENS_DIST * 0.1;
        raw.r = texture2D(Texture, texCoord - lensDist * CHROMA_STR).r;
        raw.g = texture2D(Texture, texCoord).g;
        raw.b = texture2D(Texture, texCoord + lensDist * CHROMA_STR).b;
    } else {
        raw = texture2D(Texture, texCoord).rgb;
    }

    // [2] Dither Eraser Logic
    vec3 left   = texture2D(Texture, texCoord - vec2(px.x, 0.0)).rgb;
    vec3 right  = texture2D(Texture, texCoord + vec2(px.x, 0.0)).rgb;
    vec3 ntsc   = mix(raw, (left + right + raw) * 0.333, NTSC_STR);

    // [3] Sharp & Outline Engine
    vec3 t10 = texture2D(Texture, texCoord + vec2(px.x, 0.0)).rgb;
    vec3 t01 = texture2D(Texture, texCoord + vec2(0.0, px.y)).rgb;
    
    vec3 sharpened = ntsc + (ntsc - t10) * SHARP_EDGE;
    float lc = lum(ntsc);
    float edgeDetect = length(ntsc - t10) + length(ntsc - t01);
    vec3 outlined = sharpened * (1.0 - (edgeDetect * OUTLINE_STR * clamp(1.1 - lc, 0.0, 1.0)));

    // [4] Zero-Pow Lighting & AO Bypass
    vec3 final_shading = outlined;
    if (MICRO_AO > 0.0 || EDGE_SHINE > 0.0) {
        vec3 t11 = texture2D(Texture, texCoord + px).rgb;
        vec3 t00 = texture2D(Texture, texCoord - px).rgb;
        float dist = (distance(t00, t11) + distance(t10, t01)) * 1.2;
        
        if (MICRO_AO > 0.0 && lc < AO_SKIN_PROT) {
            final_shading -= (dist * MICRO_AO * clamp(1.0 - lc, 0.0, 1.0));
        }
        
        if (EDGE_SHINE > 0.0) {
            vec2 normal = normalize(vec2(lum(t10) - lc, lum(t01) - lc) + 0.0001);
            float spec = max(dot(normal, vec2(0.7, -0.7)), 0.0);
            final_shading += (edgeDetect * RIM_LIGHT) + (dist * EDGE_SHINE * 2.0 * spec);
        }
    }

    // [5] Color & Bloom Bypass
    vec3 colored = final_shading;
    if (BLOOM_GLOW > 0.0) {
        colored = mix(final_shading, texture2D(Texture, texCoord + px).rgb, BLOOM_GLOW * 0.5);
    }
    
    colored = mix(vec3(lum(colored)), colored, VIBRANCE);
    colored.r += WARMTH * 0.05; colored.b -= WARMTH * 0.05;

    // Filmic Tonemapping
    if (FILMIC > 0.0) {
        vec3 film = (colored*(6.2*colored + 0.5)) / (colored*(6.2*colored + 1.7) + 0.06);
        colored = mix(colored, film, FILMIC);
    }

    // Final Zero-Pow Gamma
    vec3 finalColor = max(vec3(0.0), colored - BLACK_DEPTH);
    vec3 col_sq = finalColor * finalColor;
    finalColor = mix(finalColor, col_sq, GAMMA_CORRECT - 1.0);

    // Fast Vignette
    float vig = smoothstep(1.0, 0.4, distance(texCoord, vec2(0.5)) * 0.8);
    
    gl_FragColor = vec4(clamp(finalColor * vig, 0.0, 1.0), 1.0);
}
#endif