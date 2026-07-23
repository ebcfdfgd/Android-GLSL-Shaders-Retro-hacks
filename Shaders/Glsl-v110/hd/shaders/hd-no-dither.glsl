#version 110

/* ULTIMATE SONIC 2026 - NO-DITHER + HALATION */
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
uniform float halation_str, halation_thr, MICRO_AO, RIM_LIGHT, VIBRANCE;

const vec3 Y = vec3(0.299, 0.587, 0.114);

void main() { 
    vec2 px = 1.0 / TextureSize;
    
    // [1] SAMPLING (Dither blending removed, keeping necessary edge/halation taps)
    vec3 C = texture2D(Texture, texCoord).rgb;
    vec3 R = texture2D(Texture, texCoord + vec2(px.x, 0.0)).rgb;
    vec3 col_u = texture2D(Texture, texCoord + vec2(0.0, px.y)).rgb;
    vec3 colHalo = texture2D(Texture, texCoord + px).rgb;

    vec3 res = C;
    
    // [1.5] HALATION CALCULATION
    float haloLuma = dot(colHalo, Y);
    float haloMask = smoothstep(halation_thr - 0.1, halation_thr + 0.1, haloLuma);
    vec3 halo_color = colHalo * vec3(1.3, 0.8, 0.5) * haloMask;
    res += halo_color * halation_str;
    
    // [2] EDGE CALCULATION (Needed for Rim Light)
    float y_m = dot(res, Y);
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