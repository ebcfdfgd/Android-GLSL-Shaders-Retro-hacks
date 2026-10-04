#version 450

// ============================================================================
// Lens / Levels
// ============================================================================

#pragma parameter af_ca_strength            "AF - Chromatic Aberration"     0.15 0.0  1.0 0.01
#pragma parameter af_black_level            "AF - Black Level"              0.00 -0.3  0.3 0.01
#pragma parameter af_white_level            "AF - White Level"              1.00 0.7  1.3 0.01
#pragma parameter af_gamma                  "AF - Gamma"                    1.00 0.5  2.2 0.02
#pragma parameter af_filmcurve_strength     "AF - Film S-Curve"             0.35 0.0  1.0 0.02

// ============================================================================
// Glow / Diffusion
// ============================================================================

#pragma parameter af_halation_intensity     "AF - Halation Intensity"       0.40 0.0  2.0 0.05
#pragma parameter af_halation_threshold     "AF - Halation Threshold"       0.60 0.0  1.0 0.02
#pragma parameter af_halation_tint          "AF - Halation Warm Tint"       0.00 0.0  1.0 0.05
#pragma parameter af_diffusion_amount       "AF - Soft Diffusion"           0.15 0.0  0.6 0.02

// ============================================================================
// Color Grading & Tone
// ============================================================================

#pragma parameter af_splittone_shadow_tint    "AF - Split Tone Shadows"     0.00 -0.3 0.3 0.01
#pragma parameter af_splittone_highlight_tint "AF - Split Tone Highlights"  0.00 -0.3 0.3 0.01
#pragma parameter af_splittone_balance        "AF - Split Tone Balance"      0.50 0.2  0.8 0.02
#pragma parameter af_splittone_strength       "AF - Split Tone Strength"     0.40 0.0  1.0 0.02
#pragma parameter af_saturation               "AF - Saturation"              1.05 0.0  2.0 0.05
#pragma parameter af_sepia_strength           "AF - Sepia Strength"          0.00 0.0  1.0 0.05

// ============================================================================
// Vignette / Grain / De-Dither
// ============================================================================

#pragma parameter af_vignette_strength       "AF - Vignette Strength"       0.35 0.0  1.0 0.02
#pragma parameter grain_str                   "Grain Strength"               2.0 0.0 16.0 0.5
#pragma parameter de_dither                   "AF - De-Dither Strength"      0.00 0.0  1.0 0.05


// ============================================================================
// Push Constants
// ============================================================================

layout(push_constant) uniform Push
{
    float af_ca_strength;
    float af_black_level;
    float af_white_level;
    float af_gamma;
    float af_filmcurve_strength;

    float af_halation_intensity;
    float af_halation_threshold;
    float af_halation_tint;
    float af_diffusion_amount;

    float af_splittone_shadow_tint;
    float af_splittone_highlight_tint;
    float af_splittone_balance;
    float af_splittone_strength;
    float af_saturation;
    float af_sepia_strength;

    float af_vignette_strength;
    float grain_str;
    float de_dither;
} params;


// ============================================================================
// RetroArch Global UBO
// ============================================================================

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;

    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;

    uint FrameCount;
} global;


// ============================================================================
// Vertex Stage
// ============================================================================

#pragma stage vertex

layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;

layout(location = 0) out vec2 uv;

void main()
{
    uv =
        TexCoord;

    gl_Position =
        global.MVP *
        Position;
}


// ============================================================================
// Fragment Stage
// ============================================================================

#pragma stage fragment

layout(location = 0) in vec2 uv;
layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 2) uniform sampler2D Source;


// ============================================================================
// Luminance
// ============================================================================

float luma(vec3 c)
{
    return dot(
        c,
        vec3(
            0.299,
            0.587,
            0.114
        )
    );
}


// ============================================================================
// Exact Animated Film Noise
// ============================================================================

float filmGrain(
    vec2 uvCoord,
    float strength,
    float timer
)
{
    float x =
        (uvCoord.x + 4.0) *
        (uvCoord.y + 4.0) *
        (
            (mod(timer, 800.0) + 10.0) *
            10.0
        );

    return (
        mod(
            (mod(x, 13.0) + 1.0) *
            (mod(x, 123.0) + 1.0),
            0.01
        )
        - 0.005
    ) * strength;
}


// ============================================================================
// Main
// ============================================================================

void main()
{
    vec2 px =
        1.0 /
        global.SourceSize.xy;


    // ========================================================================
    // 1. Base Texture Samples
    // ========================================================================

    vec3 c =
        texture(
            Source,
            uv
        ).rgb;

    vec3 n =
        texture(
            Source,
            uv + vec2(0.0, px.y)
        ).rgb;

    vec3 s =
        texture(
            Source,
            uv - vec2(0.0, px.y)
        ).rgb;

    vec3 e =
        texture(
            Source,
            uv + vec2(px.x, 0.0)
        ).rgb;

    vec3 w =
        texture(
            Source,
            uv - vec2(px.x, 0.0)
        ).rgb;


    // ========================================================================
    // 2. De-Dither
    // No Grain Size / Pixel Scale
    // ========================================================================

    vec3 deDitheredC =
        mix(
            c,
            (c + e) * 0.5,
            params.de_dither
        );


    // ========================================================================
    // 3. Chromatic Aberration
    // ========================================================================

    vec2 caOffset =
        (uv - 0.5) *
        params.af_ca_strength *
        0.02;

    vec3 redSample =
        texture(
            Source,
            uv + caOffset
        ).rgb;

    vec3 blueSample =
        texture(
            Source,
            uv - caOffset
        ).rgb;

    vec3 work =
        vec3(
            redSample.r,
            deDitheredC.g,
            blueSample.b
        );


    // ========================================================================
    // 4. Diffusion Base
    // ========================================================================

    vec3 blurAvg =
        work * 0.36 +
        (
            n +
            s +
            e +
            w
        ) * 0.16;


    // ========================================================================
    // 5. Levels & Gamma
    // ========================================================================

    vec3 res =
        clamp(
            (
                work -
                params.af_black_level
            ) /
            max(
                params.af_white_level -
                params.af_black_level,
                0.001
            ),
            0.0,
            1.0
        );

    res =
        pow(
            res,
            vec3(
                1.0 /
                params.af_gamma
            )
        );


    // ========================================================================
    // 6. Film S-Curve
    // ========================================================================

    float lum =
        luma(res);

    float curvedLum =
        lum *
        lum *
        (
            3.0 -
            2.0 *
            lum
        );

    float finalLum =
        mix(
            lum,
            curvedLum,
            params.af_filmcurve_strength
        );

    res =
        res *
        (
            finalLum /
            max(
                lum,
                0.001
            )
        );


    // ========================================================================
    // 7. Halation
    // ========================================================================

    float haloLuma =
        luma(blurAvg);

    float haloMask =
        smoothstep(
            params.af_halation_threshold - 0.1,
            params.af_halation_threshold + 0.1,
            haloLuma
        );

    vec3 haloColor =
        mix(
            blurAvg,
            blurAvg *
            vec3(
                1.2,
                0.8,
                0.5
            ),
            params.af_halation_tint
        ) *
        haloMask;

    res =
        1.0 -
        (
            1.0 -
            res
        ) *
        (
            1.0 -
            haloColor *
            params.af_halation_intensity
        );


    // ========================================================================
    // 8. Soft Diffusion
    // ========================================================================

    res =
        mix(
            res,
            blurAvg,
            params.af_diffusion_amount *
            0.5
        );


    // ========================================================================
    // 9. Split Toning
    // ========================================================================

    float lum2 =
        luma(res);

    float shadowMask =
        1.0 -
        smoothstep(
            params.af_splittone_balance - 0.2,
            params.af_splittone_balance + 0.2,
            lum2
        );

    float highlightMask =
        1.0 -
        shadowMask;

    float toneShift =
        (
            params.af_splittone_shadow_tint *
            shadowMask

            +

            params.af_splittone_highlight_tint *
            highlightMask
        ) *
        params.af_splittone_strength;

    res.r +=
        toneShift;

    res.b -=
        toneShift;


    // ========================================================================
    // 10. Saturation
    // ========================================================================

    float grayS =
        luma(res);

    res =
        mix(
            vec3(grayS),
            res,
            params.af_saturation
        );


    // ========================================================================
    // 11. Sepia
    // ========================================================================

    vec3 sepiaColor =
        vec3(
            dot(
                res,
                vec3(
                    0.393,
                    0.769,
                    0.189
                )
            ),

            dot(
                res,
                vec3(
                    0.349,
                    0.686,
                    0.168
                )
            ),

            dot(
                res,
                vec3(
                    0.272,
                    0.534,
                    0.131
                )
            )
        );

    res =
        mix(
            res,
            sepiaColor,
            params.af_sepia_strength
        );


    // ========================================================================
    // 12. Vignette
    // ========================================================================

    vec2 frame_scale =
        global.SourceSize.xy /
        global.OriginalSize.xy;

    vec2 norm_uv =
        uv *
        frame_scale;

    vec2 cc =
        norm_uv -
        0.5;

    float dist =
        dot(
            cc,
            cc
        );

    float vignette =
        1.0 -
        dist *
        params.af_vignette_strength;

    res *=
        vignette;


    // ========================================================================
    // 13. Film Grain
    // Fixed coordinate scale
    // ========================================================================

    float grain =
        filmGrain(
            uv,
            params.grain_str,
            float(global.FrameCount)
        );

    res +=
        grain;


    // ========================================================================
    // 14. Final Output
    // No Effect Mix
    // ========================================================================

    res =
        clamp(
            res,
            0.0,
            1.0
        );

    FragColor =
        vec4(
            res,
            1.0
        );
}