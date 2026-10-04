#version 450

/* 777-NTSC-MEGA-LITE-ULTRA-GRAIN (9-TAP + BROKEN CABLE GLITCH EDITION)
    - COMPONENT SPLIT: 4 Dither Taps + 5 Chroma Taps = 9 Total Fetches.
    - INTEGRATED: High-precision RF Grain (Namash), NTSC Hue Control & Black Level.
    - ADDED: Horizontal Sync Noise (Broken Cable Static) injected safely into 9-tap pipeline.
*/

#pragma parameter NTSC_BRIGHTNESS "Signal Brightness" 1.0 0.0 2.0 0.05
#pragma parameter SATURATION "Global Saturation" 1.0 0.0 2.0 0.05
#pragma parameter BLACK_LEVEL "Black Level" 0.0 -0.5 0.5 0.01
#pragma parameter ntsc_hue "NTSC Color Hue (Cyan Fix)" 0.0 -3.14 3.14 0.05
#pragma parameter COL_BLEED "Chroma Bleed Strength" 1.5 0.0 5.0 0.05
#pragma parameter rb_power "Rainbow Strength" 0.15 0.0 2.0 0.01
#pragma parameter rb_size "Rainbow Width" 3.0 0.5 10.0 0.1
#pragma parameter rb_detect "Rainbow Detection" 0.30 0.0 1.0 0.01
#pragma parameter rb_speed "Rainbow Crawl Speed" 0.5 0.0 2.0 0.05
#pragma parameter rb_tilt "Rainbow Diagonal Tilt" 0.5 -2.0 2.0 0.1
#pragma parameter de_dither "MD De-Dither Intensity" 1.0 0.0 2.0 0.1
#pragma parameter sig_noise "Signal RF Grain (Namash)" 0.04 0.0 0.5 0.01
#pragma parameter cable_glitch "Broken Cable Static" 0.0 0.0 1.0 0.05


layout(push_constant) uniform Push
{
    float NTSC_BRIGHTNESS;
    float SATURATION;
    float BLACK_LEVEL;
    float ntsc_hue;
    float COL_BLEED;
    float rb_power;
    float rb_size;
    float rb_detect;
    float rb_speed;
    float rb_tilt;
    float de_dither;
    float sig_noise;
    float cable_glitch;
} params;


layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
} global;


// ============================================================================
// Vertex
// ============================================================================

#pragma stage vertex

layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;

layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 hTrig;

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;

    hTrig =
        vec2(
            sin(params.ntsc_hue),
            cos(params.ntsc_hue)
        );
}


// ============================================================================
// Fragment
// ============================================================================

#pragma stage fragment

layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 hTrig;

layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 2) uniform sampler2D Source;


const mat3 RGB_to_YIQ = mat3(
    0.299,  0.596,  0.211,
    0.587, -0.274, -0.523,
    0.114, -0.322,  0.312
);

const mat3 YIQ_to_RGB = mat3(
    1.0,    1.0,    1.0,
    0.956, -0.272, -1.106,
    0.621, -0.647,  1.703
);


// High-speed pseudo-random noise generator
float hash(vec2 co)
{
    return fract(
        sin(
            dot(
                co,
                vec2(12.9898, 78.233)
            )
        ) * 43758.5453
    );
}


// Ultra-fast Triangle Wave for Rainbow modulation
vec2 triangle_wave(float x)
{
    vec2 val =
        abs(
            fract(
                vec2(
                    x * 0.159,
                    x * 0.159 + 0.25
                )
            ) * 2.0 - 1.0
        ) * 2.0 - 1.0;

    return val;
}


void main()
{
    vec2 ps =
        vec2(
            1.0 / global.SourceSize.x,
            0.0
        );

    float time =
        float(global.FrameCount);


    // ========================================================================
    // BROKEN CABLE STATIC GENERATOR
    // ========================================================================

    float line_noise =
        fract(
            vTexCoord.y * 5.0 +
            time * 0.13
        )
        *
        fract(
            vTexCoord.y * 23.0 -
            time * 0.21
        );

    float static_lines =
        step(
            0.88,
            line_noise
        ) *
        params.cable_glitch;


    // ========================================================================
    // 9 FETCHES ARCHITECTURE (4 DITHER TAPS + 5 CHROMA TAPS)
    // ========================================================================

    // [A] 4 Dither Fetches (Symmetric Horizontal Array)
    float d_step =
        max(
            params.de_dither,
            1.0
        );

    vec3 cL2 =
        texture(
            Source,
            vTexCoord -
            ps * 2.0 * d_step
        ).rgb;

    vec3 cL1 =
        texture(
            Source,
            vTexCoord -
            ps * 1.0 * d_step
        ).rgb;

    vec3 cR1 =
        texture(
            Source,
            vTexCoord +
            ps * 1.0 * d_step
        ).rgb;

    vec3 cR2 =
        texture(
            Source,
            vTexCoord +
            ps * 2.0 * d_step
        ).rgb;


    // [B] 5 Chroma Fetches (Center + 4 Wide-Bleed Taps)
    float c_step =
        max(
            params.COL_BLEED,
            1.0
        );

    vec3 cM =
        texture(
            Source,
            vTexCoord
        ).rgb;

    vec3 cbL2 =
        texture(
            Source,
            vTexCoord -
            ps * 2.0 * c_step
        ).rgb;

    vec3 cbL1 =
        texture(
            Source,
            vTexCoord -
            ps * 1.0 * c_step
        ).rgb;

    vec3 cbR1 =
        texture(
            Source,
            vTexCoord +
            ps * 1.0 * c_step
        ).rgb;

    vec3 cbR2 =
        texture(
            Source,
            vTexCoord +
            ps * 2.0 * c_step
        ).rgb;


    // ========================================================================
    // ADVANCED PATTERN DETECTION & DITHER PROCESSING
    // ========================================================================

    const vec3 lumaWeight =
        vec3(
            0.299,
            0.587,
            0.114
        );

    float yM =
        dot(
            cM,
            lumaWeight
        );

    float yL1 =
        dot(
            cL1,
            lumaWeight
        );

    float yR1 =
        dot(
            cR1,
            lumaWeight
        );

    float yL2 =
        dot(
            cL2,
            lumaWeight
        );

    float yR2 =
        dot(
            cR2,
            lumaWeight
        );


    // Advanced Mesh/Checkerboard Pattern Recognition
    float pattern =
        abs(yM - yL1) *
        abs(yM - yR1) *
        50.0;


    // Macro edge protection
    // (Disables blending on real sharp visual edges)
    float edge_protection =
        clamp(
            1.0 -
            abs(yL1 - yR1) * 4.0,
            0.0,
            1.0
        );

    float dither_mask =
        clamp(
            pattern,
            0.0,
            1.0
        )
        *
        edge_protection
        *
        clamp(
            params.de_dither,
            0.0,
            1.0
        );


    // High quality 4-tap smart dither blending
    vec3 dither_avg =
        (
            cL2 +
            cL1 * 2.0 +
            cR1 * 2.0 +
            cR2
        ) / 6.0;

    vec3 blended_rgb =
        mix(
            cM,
            dither_avg,
            dither_mask
        );

    float final_y =
        dot(
            blended_rgb,
            lumaWeight
        )
        *
        params.NTSC_BRIGHTNESS;


    // [C] RF GRAIN APPLICATION (Namash)
    if (params.sig_noise > 0.0)
    {
        final_y +=
            (
                hash(
                    vTexCoord +
                    time * 0.01
                ) -
                0.5
            )
            *
            params.sig_noise;
    }


    // Apply Broken Cable Static to Luma
    final_y -=
        static_lines * 0.4;


    // ========================================================================
    // 5-TAP CHROMA BLEED & RAINBOW EFFECT
    // ========================================================================

    vec3 yiqM =
        RGB_to_YIQ *
        cM;

    vec3 yiqL2 =
        RGB_to_YIQ *
        cbL2;

    vec3 yiqL1 =
        RGB_to_YIQ *
        cbL1;

    vec3 yiqR1 =
        RGB_to_YIQ *
        cbR1;

    vec3 yiqR2 =
        RGB_to_YIQ *
        cbR2;


    // 5-tap smooth binomial blur for I & Q components
    float fI =
        (
            yiqL2.y +
            yiqL1.y * 2.0 +
            yiqM.y * 3.0 +
            yiqR1.y * 2.0 +
            yiqR2.y
        ) / 9.0;

    float fQ =
        (
            yiqL2.z +
            yiqL1.z * 2.0 +
            yiqM.z * 3.0 +
            yiqR1.z * 2.0 +
            yiqR2.z
        ) / 9.0;


    fI =
        mix(
            yiqM.y,
            fI,
            clamp(
                params.COL_BLEED,
                0.0,
                1.0
            )
        );

    fQ =
        mix(
            yiqM.z,
            fQ,
            clamp(
                params.COL_BLEED,
                0.0,
                1.0
            )
        );


    // Inject Broken Cable Static into Chroma
    fI -=
        static_lines * 0.15;

    fQ +=
        static_lines * 0.15;


    // Optimized Rainbow Generation using enhanced luma metrics
    if (params.rb_power > 0.0)
    {
        float edge =
            abs(yM - yL1) +
            abs(yM - yR1);

        float mask =
            smoothstep(
                params.rb_detect,
                params.rb_detect + 0.1,
                edge
            );


        float ang =
            (
                vTexCoord.x *
                global.SourceSize.x /
                params.rb_size
            )
            +
            (
                vTexCoord.y *
                global.SourceSize.y *
                params.rb_tilt
            )
            +
            (
                time *
                params.rb_speed
            );

        vec2 wave =
            triangle_wave(
                ang
            );


        // Cable glitch dynamically amplifies the rainbow artifacts on edges
        fI +=
            wave.x *
            params.rb_power *
            (
                mask +
                static_lines * 0.5
            );

        fQ +=
            wave.y *
            params.rb_power *
            (
                mask +
                static_lines * 0.5
            );
    }


    // ========================================================================
    // HUE SHIFT, SATURATION & FINAL ASSEMBLY
    // ========================================================================

    float resI =
        (
            fI * hTrig.y -
            fQ * hTrig.x
        )
        *
        params.SATURATION;

    float resQ =
        (
            fI * hTrig.x +
            fQ * hTrig.y
        )
        *
        params.SATURATION;


    vec3 res =
        YIQ_to_RGB *
        vec3(
            final_y,
            resI,
            resQ
        );


    // [D] BLACK LEVEL ADJUSTMENT
    res =
        mix(
            vec3(params.BLACK_LEVEL),
            vec3(1.0),
            res
        );


    FragColor =
        vec4(
            clamp(
                res,
                0.0,
                1.0
            ),
            1.0
        );
}