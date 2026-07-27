/* ULTIMATE SONIC 2026 - INTEGRATED BLEND + HALATION + ADVANCED POST-PROCESSING */
#pragma parameter SGPT_BLEND_LEVEL "Blend Level" 0.85 0.0 1.0 0.05
#pragma parameter halation_str     "Halation Intensity" 0.4 0.0 2.0 0.05
#pragma parameter halation_thr     "Halation Threshold" 0.6 0.0 1.0 0.05
#pragma parameter OUTLINE_STR "Detail: Outline Power" 0.7 0.0 1.0 0.05
#pragma parameter MICRO_AO "Depth: Micro-AO" 0.7 0.0 1.0 0.05
#pragma parameter AO_SKIN_PROT "Depth: AO Skin Protect" 0.60 0.0 1.0 0.05
#pragma parameter RIM_LIGHT "Light: Rim Strength" 1.5 0.0 2.0 0.05
#pragma parameter RIM_MASK_POWER "Rim Mask Threshold" 0.8 0.0 3.0 0.1
#pragma parameter VIBRANCE "Color: Vibrance" 1.1 -1.0 2.0 0.10


#if defined(VERTEX)
attribute vec4 VertexCoord; attribute vec4 TexCoord; varying vec2 texCoord; uniform mat4 MVPMatrix;
void main() { gl_Position = MVPMatrix * VertexCoord; texCoord = TexCoord.xy; }

#elif defined(FRAGMENT)
precision mediump float;
varying vec2 texCoord; uniform sampler2D Texture; uniform vec2 TextureSize;
uniform float SGPT_BLEND_LEVEL, halation_str, halation_thr,OUTLINE_STR, MICRO_AO, AO_SKIN_PROT, RIM_LIGHT, RIM_MASK_POWER, VIBRANCE;

const vec3 lumaWeight = vec3(0.299, 0.587, 0.114);

// دوال الدمج الذكي (Code 5)
vec3 min_s(vec3 central, vec3 adj1, vec3 adj2) { return min(central, max(adj1, adj2)); }
vec3 max_s(vec3 central, vec3 adj1, vec3 adj2) { return max(central, min(adj1, adj2)); }

void main() {
    vec2 px = 1.0 / TextureSize;
    
    // [1] SAMPLING & BLENDING (استبدال الـ Dither القديم بـ Code 5)
    vec3 C = texture2D(Texture, texCoord).rgb;
    vec3 L = texture2D(Texture, texCoord - vec2(px.x, 0.0)).rgb;
    vec3 R = texture2D(Texture, texCoord + vec2(px.x, 0.0)).rgb;
    vec3 col_u = texture2D(Texture, texCoord + vec2(0.0, px.y)).rgb;
    vec3 colHalo = texture2D(Texture, texCoord + px).rgb; // عينة إضافية للهليان
    
    // حساب الحدود والتباين للدمج
    vec3 min_sample = min_s(C, L, R);
    vec3 max_sample = max_s(C, L, R);
    float contrast = dot(max(C, max(L, R)) - min(C, min(L, R)), lumaWeight);
    contrast = clamp((1.0 - SGPT_BLEND_LEVEL) * contrast, 0.0, 1.0);

    // حساب الألوان
    vec3 col_L_blend = 0.5 * (C + L + contrast * (C - L));
    vec3 col_R_blend = 0.5 * (C + R + contrast * (C - R));

    float contrast_L = dot(abs(C - col_L_blend), lumaWeight);
    float contrast_R = dot(abs(C - col_R_blend), lumaWeight);

    vec3 res = contrast_R < contrast_L ? col_L_blend : col_R_blend;
    res = clamp(res, min_sample, max_sample);

    // [1.5] HALATION CALCULATION (التوهج السينمائي الناعم)
    float haloLuma = dot(colHalo, lumaWeight);
    float haloMask = smoothstep(halation_thr - 0.1, halation_thr + 0.1, haloLuma);
    vec3 halo_color = colHalo * vec3(1.3, 0.8, 0.5) * haloMask;
    res += halo_color * halation_str;

    // [2] OUTLINE & EDGE
    float y_m = dot(res, lumaWeight);
    float edge = dot(abs(res - R) + abs(res - col_u), vec3(0.333));
    res *= (1.0 - (edge * OUTLINE_STR * clamp(1.1 - y_m, 0.0, 1.0)));

    // [3] LIGHTING & AO
    float dist = abs(dot(R, lumaWeight) - dot(col_u, lumaWeight)) * 2.0;
    float rimMask = clamp(1.0 - (y_m * RIM_MASK_POWER), 0.0, 1.0); 
    
    // AO
    res -= (dist * MICRO_AO * clamp(1.0 - y_m, 0.0, 1.0)) * step(y_m, AO_SKIN_PROT);
    
    // Rim
    res += (edge * RIM_LIGHT * 0.7 * rimMask);
    
   

    // [5] FINAL COLOR
    
    res = mix(vec3(y_m), res, VIBRANCE);
    
    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
#endif