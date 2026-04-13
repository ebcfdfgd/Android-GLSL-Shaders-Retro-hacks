#version 130

/*
    ULTIMATE SONIC 2026: CHROMA-SHINE + DITHER (Hybrid Edition)
    - INTEGRATED: NTSC Dither Eraser from "500 Edition".
    - PRESERVED: Chromatic Aberration, Sharp Specular, Micro-AO.
    - NO SMOOTHING: High-definition pixel-perfect base.
*/

// --- 1. [ CHROMA & DITHER ] ---
#pragma parameter CHROMA_STR "Chromatic Aberration" 0.12 0.0 0.50 0.02
#pragma parameter LENS_DIST "Lens Edge Distortion" 0.10 0.0 0.50 0.02
#pragma parameter NTSC_STR "NTSC Dither Eraser" 0.65 0.0 1.0 0.05

// --- 2. [ SHINE & DEPTH ] ---
#pragma parameter EDGE_SHINE "Edge Specular Shine" 0.45 0.0 1.0 0.05
#pragma parameter SHARP_EDGE "Modern Sharpen" 0.45 0.0 1.0 0.05
#pragma parameter OUTLINE_STR "Outline Strength" 0.20 0.0 1.0 0.05
#pragma parameter MICRO_AO "Micro-AO Strength" 0.35 0.0 1.0 0.05
#pragma parameter AO_SKIN_PROT "AO Skin Protect" 0.60 0.0 1.0 0.05
#pragma parameter RIM_LIGHT "Character Rim Light" 0.65 0.0 2.0 0.05
#pragma parameter BLOOM_GLOW "Modern Bloom Glow" 0.35 0.0 1.0 0.05

// --- 3. [ COLOR & POLISH ] ---
#pragma parameter VIBRANCE "Color Vibrance" 1.40 1.0 2.0 0.10
#pragma parameter WARMTH "Color Warmth" 0.0 -0.50 0.50 0.05
#pragma parameter LIGHT_STRENGTH "Depth Light Strength" 0.50 0.0 2.0 0.05
#pragma parameter SPEC_POWER "Specular Sharpness" 16.0 1.0 64.0 1.0
#pragma parameter FILMIC "Filmic Look" 0.40 0.0 1.0 0.05
#pragma parameter BLACK_DEPTH "Black Depth (Soot)" 0.05 -0.10 0.20 0.01
#pragma parameter GAMMA_CORRECT "Gamma Correction" 1.10 0.50 2.00 0.05
#pragma parameter SHADOW_STRENGTH "Shadow Depth Strength" 0.15 0.0 0.50 0.05
#pragma parameter SHADOW_DETAIL "Isolated Shadow Detail" 0.12 0.0 1.0 0.05

#if defined(VERTEX)
in vec4 VertexCoord; in vec4 TexCoord; out vec2 texCoord; uniform mat4 MVPMatrix;
void main() { gl_Position = MVPMatrix * VertexCoord; texCoord = TexCoord.xy; }

#elif defined(FRAGMENT)
precision mediump float;
in vec2 texCoord; out vec4 FragColor; uniform sampler2D Texture; uniform vec2 TextureSize;

#ifdef PARAMETER_UNIFORM
uniform float CHROMA_STR, LENS_DIST, NTSC_STR, EDGE_SHINE, SHARP_EDGE, OUTLINE_STR, MICRO_AO, AO_SKIN_PROT, RIM_LIGHT, BLOOM_GLOW, VIBRANCE;
uniform float WARMTH, LIGHT_STRENGTH, SPEC_POWER, FILMIC, BLACK_DEPTH, GAMMA_CORRECT, SHADOW_STRENGTH, SHADOW_DETAIL;
#endif

#define px (1.0 / TextureSize)
#define saturate(x) clamp(x, 0.0, 1.0)
float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

void main()
{
    // 1. Chromatic Aberration + Base Sampling
    vec2 lensDist = (texCoord - 0.5) * LENS_DIST * 0.1;
    float r = texture(Texture, texCoord - lensDist * CHROMA_STR).r;
    float g = texture(Texture, texCoord).g;
    float b = texture(Texture, texCoord + lensDist * CHROMA_STR).b;
    vec3 raw = vec3(r, g, b);

    // 2. NTSC Dither Eraser (From Edition 500)
    vec3 left   = texture(Texture, texCoord - vec2(px.x, 0.0)).rgb;
    vec3 right  = texture(Texture, texCoord + vec2(px.x, 0.0)).rgb;
    vec3 ntsc = mix(raw, (left + right + raw) * 0.333, NTSC_STR);

    // 3. Neighbors & Pure Sharp Engine
    vec3 t10 = texture(Texture, texCoord + vec2(px.x, 0.0)).rgb;
    vec3 t01 = texture(Texture, texCoord + vec2(0.0, px.y)).rgb;
    vec3 t11 = texture(Texture, texCoord + px).rgb;
    vec3 t00 = texture(Texture, texCoord - px).rgb;

    float dist = (distance(t00, t11) + distance(t10, t01)) * 1.2;
    vec3 sharpened = ntsc + (ntsc - t10) * SHARP_EDGE;
    
    float lc = lum(ntsc);
    float whiteProt = saturate(1.1 - lc);
    float edgeDetect = length(ntsc - t10) + length(ntsc - t01);
    vec3 outlined = sharpened * (1.0 - (edgeDetect * OUTLINE_STR * whiteProt));

    // 4. Depth & Shine Logic
    float aoMask = (lc > AO_SKIN_PROT) ? 0.0 : saturate(pow(1.0 - lc, 3.0));
    vec3 aoFinal = outlined - (dist * MICRO_AO * aoMask);
    
    vec2 normal = normalize(vec2(lum(t10) - lc, lum(t01) - lc) + 0.0001);
    float specBase = max(dot(normal, vec2(0.7, -0.7)), 0.0);
    float spec = pow(specBase, SPEC_POWER) * LIGHT_STRENGTH;
    float edgeShine = saturate(dist * EDGE_SHINE * 5.0) * specBase;
    
    vec3 rimResult = aoFinal + (edgeDetect * RIM_LIGHT) + spec + (edgeShine * whiteProt);

    // 5. Final Composite & Color Polish
    vec3 colored = mix(rimResult, texture(Texture, texCoord + px).rgb, BLOOM_GLOW * 0.5);
    colored = mix(vec3(lum(colored)), colored, VIBRANCE);
    colored.r += WARMTH * 0.1; colored.b -= WARMTH * 0.1;

    // Filmic & Gamma
    vec3 filmic = mix(colored, (colored*(6.2*colored + 0.5)) / (colored*(6.2*colored + 1.7) + 0.06), FILMIC);
    vec3 finalColor = pow(max(vec3(0.0), filmic - BLACK_DEPTH), vec3(GAMMA_CORRECT));

    // Shadow Enhancements
    float shadowFactor = 1.0 - (saturate(lum(finalColor) * 2.0) * SHADOW_STRENGTH);
    finalColor *= shadowFactor;
    
    float shadowMask = saturate(pow(1.0 - lum(finalColor), 4.0));
    finalColor = mix(finalColor, finalColor * 0.8, SHADOW_DETAIL * shadowMask);

    // Vignette
    finalColor *= smoothstep(1.0, 0.4, distance(texCoord, vec2(0.5, 0.5)) * 0.8);

    FragColor = vec4(saturate(finalColor), 1.0);
}
#endif