/* ULTIMATE SONIC 2026 - TINTED LIGHTING MODEL (SINGLE BAR FOR AO & RIM) */
#pragma parameter C_BLK_LVL "Black Level" 0.0 -0.2 0.2 0.01
#pragma parameter C_WHT_LVL "White Level" 1.0 0.0 1.0 0.01
#pragma parameter dither_str "Dither Removal Strength" 1.0 0.0 2.0 0.05
#pragma parameter OUTLINE_STR "Detail: Outline Power" 0.40 0.0 1.0 0.05
#pragma parameter MICRO_AO "Depth: Cavity AO Power" 0.8 0.0 2.0 0.05
#pragma parameter AO_SKIN_PROT "Depth: AO Skin Protect" 0.60 0.0 1.0 0.05
#pragma parameter FRESNEL_INT "Light: Fresnel Intensity" 0.5 0.0 2.0 0.05
#pragma parameter RIM_LIGHT "Light: Rim Intensity" 0.5 0.0 2.0 0.05
#pragma parameter RIM_MASK_POWER "Light: Rim Mask Threshold" 1.0 0.0 3.0 0.1
#pragma parameter SPEC_STR "Light: Specular Intensity" 0.5 0.0 2.0 0.05
#pragma parameter DIR_BIAS "Light: Dir Bias" 0.2 -1.0 1.0 0.05

// [البارات الموحدة الجديدة للتحكم الذكي في لون الظلال والحواف]
#pragma parameter AO_TINT_SEL "AO Shadow Color: Purple->Dark->Warm" 0.0 0.0 1.0 0.05
#pragma parameter RIM_TINT_SEL "Rim Light Color: Ice->White->Gold" 0.0 0.0 1.0 0.05

#pragma parameter LUMA_ADAPT "Engine: Luma Adaptation" 0.2 0.0 0.5 0.05
#pragma parameter HIGH_COMP "Engine: Highlight Comp" 0.2 0.0 1.0 0.05
#pragma parameter VIBRANCE "Color: Vibrance" 1.0 -1.0 2.0 0.10
#pragma parameter WARMTH "Color: Warmth" 0.0 -0.50 0.50 0.05
#pragma parameter AMBIENT_INJECT "ACES: Ambient Injection" 0.0 0.0 1.0 0.05
#pragma parameter BLU_CYN "Color: Blue -> Crisp Cyan" 0.30 0.0 1.0 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord; attribute vec4 TexCoord; varying vec2 texCoord; uniform mat4 MVPMatrix;
void main() { gl_Position = MVPMatrix * VertexCoord; texCoord = TexCoord.xy; }

#elif defined(FRAGMENT)
precision mediump float;
varying vec2 texCoord; uniform sampler2D Texture; uniform vec2 TextureSize;
uniform float C_BLK_LVL, C_WHT_LVL, dither_str, OUTLINE_STR, MICRO_AO, AO_SKIN_PROT, FRESNEL_INT, RIM_LIGHT, RIM_MASK_POWER, SPEC_STR, DIR_BIAS, LUMA_ADAPT, HIGH_COMP, VIBRANCE, WARMTH, AMBIENT_INJECT, BLU_CYN;
uniform float AO_TINT_SEL, RIM_TINT_SEL; // استدعاء البارات الجديدة

const vec3 lumaWeight = vec3(0.299, 0.587, 0.114);

void main() {
    vec2 px = 1.0 / TextureSize;
    vec3 center = texture2D(Texture, texCoord).rgb;
    vec3 col_r = texture2D(Texture, texCoord + px).rgb;
    vec3 res = mix(center, (center + col_r) * 0.5, dither_str);

    float y_m = dot(res, lumaWeight);
    vec3 col_u = texture2D(Texture, texCoord + vec2(0.0, px.y)).rgb;
    float edge = dot(abs(res - col_r) + abs(res - col_u), vec3(0.333));
    
    // [1] DYNAMIC AO TINT SPECTRUM
    vec3 ao_purple = vec3(0.4, 0.3, 0.7);   // المود الأصلي
    vec3 ao_dark   = vec3(0.2, 0.2, 0.2);   // مود واقعي داكن
    vec3 ao_warm   = vec3(0.5, 0.35, 0.2);  // مود أرضي دافئ
    
    float ao_mix1 = clamp(AO_TINT_SEL * 2.0, 0.0, 1.0);
    float ao_mix2 = clamp((AO_TINT_SEL - 0.5) * 2.0, 0.0, 1.0);
    vec3 AO_TINT  = mix(mix(ao_purple, ao_dark, ao_mix1), ao_warm, ao_mix2);

    // [2] DYNAMIC RIM TINT SPECTRUM
    vec3 rim_ice   = vec3(0.8, 0.9, 1.0);   // المود الأزرق البارد
    vec3 rim_white = vec3(1.0, 1.0, 1.0);   // مود محايد
    vec3 rim_gold  = vec3(1.0, 0.93, 0.80);  // مود ماريو الذهبي
    
    float rim_mix1 = clamp(RIM_TINT_SEL * 2.0, 0.0, 1.0);
    float rim_mix2 = clamp((RIM_TINT_SEL - 0.5) * 2.0, 0.0, 1.0);
    vec3 RIM_TINT  = mix(mix(rim_ice, rim_white, rim_mix1), rim_gold, rim_mix2);

    // [3] CAVITY AO
    float ao = length(res - texture2D(Texture, texCoord + px * 2.0).rgb);
    res -= (ao * MICRO_AO * AO_TINT * clamp(1.0 - y_m, 0.0, 1.0)) * step(y_m, AO_SKIN_PROT);

    // [4] LIGHTING: FRESNEL & RIM
    float edge_intensity = edge * 5.0;
    
    // Fresnel
    vec3 fresnel = edge_intensity * FRESNEL_INT * res;
    
    // Rim
    float rimMask = clamp(1.0 - (y_m * RIM_MASK_POWER), 0.0, 1.0);
    vec3 rim = edge_intensity * RIM_LIGHT * rimMask * RIM_TINT;
    
    res += (fresnel + rim);
    
    // Specular
    float spec = y_m * y_m * y_m * SPEC_STR;
    res += (spec * (1.0 + DIR_BIAS));

    // [5] ENGINE ADAPTATION
    res = mix(res, res + (1.0 - y_m) * LUMA_ADAPT, HIGH_COMP);

    // [6] OUTLINE
    res *= (1.0 - (edge * OUTLINE_STR * clamp(1.1 - y_m, 0.0, 1.0)));

    if (AMBIENT_INJECT > 0.0) {
        vec3 ambientColor = mix(res * vec3(0.45, 0.38, 0.58), res * vec3(1.22, 0.58, 0.38), y_m);
        res = mix(res, ambientColor, AMBIENT_INJECT);
    }

    // [7] FINAL
    float blueMask = max(0.0, res.b - res.g);
    res.g += blueMask * BLU_CYN;
    res.r -= blueMask * (BLU_CYN * 0.4);

    res = max(vec3(0.0), res - C_BLK_LVL); 
    res = res * (1.0 / max(0.001, C_WHT_LVL));
    res = mix(vec3(dot(res, lumaWeight)), res, VIBRANCE);
    res.rb += vec2(WARMTH, -WARMTH) * 0.05;
    
    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
#endif