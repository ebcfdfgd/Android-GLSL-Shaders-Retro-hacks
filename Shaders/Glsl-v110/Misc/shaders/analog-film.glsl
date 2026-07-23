#version 110

// ===== Lens / Levels =====
#pragma parameter af_sample_scale             "AF - Sample Scale"             1.60 0.5  4.0 0.1
#pragma parameter af_ca_strength              "AF - Chromatic Aberration"   0.15 0.0  1.0 0.01
#pragma parameter af_black_level              "AF - Black Level"              0.00 0.0  0.3 0.01
#pragma parameter af_white_level              "AF - White Level"              1.00 0.7  1.0 0.01
#pragma parameter af_gamma                    "AF - Gamma"                    1.00 0.5  2.2 0.02
#pragma parameter af_filmcurve_strength       "AF - Film S-Curve"             0.35 0.0  1.0 0.02

// ===== Glow / Diffusion =====
#pragma parameter af_halation_intensity      "AF - Halation Intensity"     0.40 0.0  2.0 0.05
#pragma parameter af_halation_threshold      "AF - Halation Threshold"     0.60 0.0  1.0 0.02
#pragma parameter af_halation_tint           "AF - Halation Warm Tint"     0.60 0.0  1.0 0.05
#pragma parameter af_diffusion_amount        "AF - Soft Diffusion"         0.15 0.0  0.6 0.02

// ===== Color Grading & Tone =====
#pragma parameter af_splittone_shadow_tint    "AF - Split Tone Shadows"     0.04 -0.3 0.3 0.01
#pragma parameter af_splittone_highlight_tint "AF - Split Tone Highlights" 0.04 -0.3 0.3 0.01
#pragma parameter af_splittone_balance        "AF - Split Tone Balance"     0.50 0.2  0.8 0.02
#pragma parameter af_splittone_strength       "AF - Split Tone Strength"    0.40 0.0  1.0 0.02
#pragma parameter af_saturation               "AF - Saturation"             1.05 0.0  2.0 0.05
#pragma parameter af_sepia_strength           "AF - Sepia Strength"         0.00 0.0  1.0 0.05

// ===== Vignette / Grain =====
#pragma parameter af_vignette_strength        "AF - Vignette Strength"      0.35 0.0  1.0 0.02
#pragma parameter af_grain_strength           "AF - Film Grain Amount"      0.04 0.0  0.3 0.005
#pragma parameter af_grain_size               "AF - Film Grain Size"        1.20 0.3  3.0 0.05

// ===== Output =====
#pragma parameter af_mix                      "AF - Effect Mix"             1.00 0.0  1.0 0.05

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
uniform float af_sample_scale;
uniform float af_ca_strength;
uniform float af_black_level;
uniform float af_white_level;
uniform float af_gamma;
uniform float af_filmcurve_strength;
uniform float af_halation_intensity;
uniform float af_halation_threshold;
uniform float af_halation_tint;
uniform float af_diffusion_amount;
uniform float af_splittone_shadow_tint;
uniform float af_splittone_highlight_tint;
uniform float af_splittone_balance;
uniform float af_splittone_strength;
uniform float af_saturation;
uniform float af_sepia_strength;
uniform float af_vignette_strength;
uniform float af_grain_strength;
uniform float af_grain_size;
uniform float af_mix;
#else
#define af_sample_scale               1.60
#define af_ca_strength                0.15
#define af_black_level                0.00
#define af_white_level                1.00
#define af_gamma                      1.00
#define af_filmcurve_strength         0.35
#define af_halation_intensity         0.40
#define af_halation_threshold         0.60
#define af_halation_tint              0.60
#define af_diffusion_amount           0.15
#define af_splittone_shadow_tint      0.04
#define af_splittone_highlight_tint   0.04
#define af_splittone_balance          0.50
#define af_splittone_strength         0.40
#define af_saturation                 1.05
#define af_sepia_strength             0.00
#define af_vignette_strength          0.35
#define af_grain_strength             0.04
#define af_grain_size                 1.20
#define af_mix                        1.00
#endif

float luma(vec3 c) {
    return dot(c, vec3(0.299, 0.587, 0.114));
}

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec2 px = af_sample_scale / TextureSize;

    // 5 base fetches (cross)
    vec3 c = texture2D(Texture, uv).rgb;
    vec3 n = texture2D(Texture, uv + vec2(0.0,  px.y)).rgb;
    vec3 s = texture2D(Texture, uv - vec2(0.0,  px.y)).rgb;
    vec3 e = texture2D(Texture, uv + vec2(px.x, 0.0)).rgb;
    vec3 w = texture2D(Texture, uv - vec2(px.x, 0.0)).rgb;

    // +2 fetches for radial chromatic aberration (per-channel offset)
    vec2 caOffset = (uv - 0.5) * af_ca_strength * 0.02;
    vec3 redSample  = texture2D(Texture, uv + caOffset).rgb;
    vec3 blueSample = texture2D(Texture, uv - caOffset).rgb;
    vec3 work = vec3(redSample.r, c.g, blueSample.b);

    vec3 blurAvg = work * 0.36 + (n + s + e + w) * 0.16;

    // --- Levels & Gamma ---
    vec3 res = clamp((work - af_black_level) / max(af_white_level - af_black_level, 0.001), 0.0, 1.0);
    res = pow(res, vec3(1.0 / af_gamma));

    // --- Film S-Curve Contrast ---
    vec3 curved = res * res * (3.0 - 2.0 * res);
    res = mix(res, curved, af_filmcurve_strength);

    // --- Halation (warm glow around highlights, classic film trait) ---
    float haloLuma = luma(blurAvg);
    float haloMask = smoothstep(af_halation_threshold - 0.1, af_halation_threshold + 0.1, haloLuma);
    vec3 haloColor = mix(blurAvg, blurAvg * vec3(1.2, 0.8, 0.5), af_halation_tint) * haloMask;
    res = 1.0 - (1.0 - res) * (1.0 - haloColor * af_halation_intensity);

    // --- Soft Diffusion (global dreamy softness, Pro-Mist style) ---
    res = mix(res, blurAvg, af_diffusion_amount * 0.5);

    // --- Split Toning ---
    float lum2 = luma(res);
    float shadowMask = 1.0 - smoothstep(af_splittone_balance - 0.2, af_splittone_balance + 0.2, lum2);
    float highlightMask = 1.0 - shadowMask;
    float toneShift = (af_splittone_shadow_tint * shadowMask + af_splittone_highlight_tint * highlightMask) * af_splittone_strength;
    res.r += toneShift;
    res.b -= toneShift;

    // --- Saturation ---
    float grayS = luma(res);
    res = mix(vec3(grayS), res, af_saturation);

    // --- Sepia Tone ---
    vec3 sepiaColor = vec3(
        dot(res, vec3(0.393, 0.769, 0.189)),
        dot(res, vec3(0.349, 0.686, 0.168)),
        dot(res, vec3(0.272, 0.534, 0.131))
    );
    res = mix(res, sepiaColor, af_sepia_strength);

    // --- Exact Vignette Logic (Flat, No Geometric Curve) ---
    vec2 frame_scale = TextureSize / InputSize;
    vec2 norm_uv = uv * frame_scale;
    vec2 cc = norm_uv - 0.5;
    float dist = dot(cc, cc);
    float vignette = 1.0 - dist * af_vignette_strength;
    res *= vignette;

    // --- Film Grain ---
    float grain = hash(uv * TextureSize * af_grain_size);
    res += (grain - 0.5) * af_grain_strength;

    res = clamp(res, 0.0, 1.0);
    res = mix(c, res, af_mix);

    gl_FragColor = vec4(res, 1.0);
}
#endif