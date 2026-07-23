#version 110

/* ULTIMATE SONIC 2026 - INTEGRATED BLEND + TWO-TAP DITHER + HALATION */
#pragma parameter SGPT_BLEND_LEVEL "Blend Level" 1.0 0.0 1.0 0.05
#pragma parameter halation_str "Halation Intensity" 0.4 0.0 2.0 0.05
#pragma parameter halation_thr "Halation Threshold" 0.6 0.0 1.0 0.05
#pragma parameter MICRO_AO "MICRO AO" 0.30 0.0 1.0 0.05
#pragma parameter RIM_LIGHT "Light: Rim Strength" 0.3 0.0 2.0 0.05
#pragma parameter VIBRANCE "Color: Vibrance" 1.1 -1.0 2.0 0.10

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
precision mediump float;
varying vec2 texCoord; 
uniform sampler2D Texture; 
uniform vec2 TextureSize;
uniform float SGPT_BLEND_LEVEL, halation_str, halation_thr, MICRO_AO, RIM_LIGHT, VIBRANCE;

const vec3 Y = vec3(0.299, 0.587, 0.114);

// Helper functions for Code 5 logic
vec3 min_s(vec3 central, vec3 adj1, vec3 adj2) { return min(central, max(adj1, adj2)); }
vec3 max_s(vec3 central, vec3 adj1, vec3 adj2) { return max(central, min(adj1, adj2)); }

void main() {
    vec2 px = 1.0 / TextureSize;
    
    // [1] SAMPLING (Code 5 Setup + Halation Tap)
    vec3 C = texture2D(Texture, texCoord).rgb;
    vec3 L = texture2D(Texture, texCoord - vec2(px.x, 0.0)).rgb;
    vec3 R = texture2D(Texture, texCoord + vec2(px.x, 0.0)).rgb;
    vec3 col_u = texture2D(Texture, texCoord + vec2(0.0, px.y)).rgb; // Used for vertical edge detection
    vec3 colHalo = texture2D(Texture, texCoord + px).rgb; // Halation tap

    // Code 5 Dither Removal / Blending Logic
    vec3 min_sample = min_s(C, L, R);
    vec3 max_sample = max_s(C, L, R);
    
    float contrast = dot(max(C, max(L, R)) - min(C, min(L, R)), Y);
    contrast = clamp((1.0 - SGPT_BLEND_LEVEL) * contrast, 0.0, 1.0);
    
    vec3 col_L = 0.5 * (C + L + contrast * (C - L));
    vec3 col_R = 0.5 * (C + R + contrast * (C - R));
    
    float contrast_L = dot(abs(C - col_L), Y);
    float contrast_R = dot(abs(C - col_R), Y);
    
    vec3 res = contrast_R < contrast_L ? col_L : col_R;
    res = clamp(res, min_sample, max_sample);
    
    // [1.5] HALATION CALCULATION
    float haloLuma = dot(colHalo, Y);
    float haloMask = smoothstep(halation_thr - 0.1, halation_thr + 0.1, haloLuma);
    vec3 halo_color = colHalo * vec3(1.3, 0.8, 0.5) * haloMask;
    res += halo_color * halation_str;
    
    // [2] EDGE CALCULATION (Needed for Rim Light)
    float y_m = dot(res, Y);
    // Edge detection comparing against original Right and Up samples
    float edge = dot(abs(res - R) + abs(res - col_u), vec3(0.333));
    
    // [3] LIGHTING & AO
    float dist = abs(dot(R, Y) - dot(col_u, Y)) * 2.0;
    res -= (dist * MICRO_AO * clamp(1.0 - y_m, 0.0, 1.0));
    res += (edge * RIM_LIGHT * 0.7);
    
    // Final Vibrance adjustment
    res = mix(vec3(y_m), res, VIBRANCE);
    
    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
#endif