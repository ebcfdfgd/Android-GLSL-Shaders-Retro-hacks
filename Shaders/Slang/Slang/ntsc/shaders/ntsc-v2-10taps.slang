#version 450

/* 777-NTSC-MD-PRO-TURBO-V3-9TAP (NO-SIN TRIANGLE OPTIMIZED) */

#pragma parameter SATURATION "Global Saturation" 1.0 0.0 2.0 0.05
#pragma parameter BRIGHTNESS "Signal Brightness" 1.0 0.0 2.0 0.05
#pragma parameter BLACK_LEVEL "Black Level" 0.0 -0.5 0.5 0.01
#pragma parameter rb_power "Rainbow Strength" 0.1 0.0 2.0 0.01
#pragma parameter rb_size "Rainbow Width/Scale" 4.5 0.5 10.0 0.1
#pragma parameter rb_slant "Rainbow Tilt/Rotation" 0.0 -2.0 2.0 0.05
#pragma parameter rb_detect "Rainbow Edge Detect" 0.31 0.0 1.0 0.01
#pragma parameter rb_speed "Rainbow Cycle Speed" 0.1 0.0 1.0 0.01
#pragma parameter rb_phase "Rainbow Phase Shift" 0.0 0.0 6.28 0.1
#pragma parameter rb_sat "Rainbow Saturation" 1.0 0.0 2.0 0.05
#pragma parameter COL_BLEED "Chroma Spread (Bleed)" 5.0 0.0 20.0 0.1
#pragma parameter red_persistence "Red Persistence (Right Smear)" 1.0 0.0 2.5 0.05
#pragma parameter black_bleed "Black Level Smear" 0.2 0.0 1.0 0.01
#pragma parameter fringe_str "Edge Color Fringing" 0.4 0.0 5.0 0.1
#pragma parameter de_dither "MD De-Dither Intensity" 1.0 0.0 2.0 0.1
#pragma parameter jail_str "MD Vertical Jailbars" 0.15 0.0 1.0 0.01
#pragma parameter jail_width "MD Jailbar Spacing" 1.5 0.5 10.0 0.1
#pragma parameter sig_noise "Signal RF Grain" 0.04 0.0 0.5 0.01
#pragma parameter JITTER "Signal Jitter (Shake)" 0.04 0.0 3.0 0.05
#pragma parameter MD_WARM "Analog Warmth" 0.05 -0.2 0.2 0.01
#pragma parameter MD_SHARP "Luma Sharpness" 0.1 0.0 2.0 0.05
#pragma parameter ntsc_hue "NTSC Tint (Hue)" 0.0 -3.14 3.14 0.05


layout(push_constant) uniform Push
{
    float SATURATION;
    float BRIGHTNESS;
    float BLACK_LEVEL;
    float rb_power;
    float rb_size;
    float rb_slant;
    float rb_detect;
    float rb_speed;
    float rb_phase;
    float rb_sat;
    float COL_BLEED;
    float red_persistence;
    float black_bleed;
    float fringe_str;
    float de_dither;
    float jail_str;
    float jail_width;
    float sig_noise;
    float JITTER;
    float MD_WARM;
    float MD_SHARP;
    float ntsc_hue;
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
    gl_Position =
        global.MVP *
        Position;

    vTexCoord =
        TexCoord.xy;

    hTrig =
        vec2(
            params.ntsc_hue * 0.9,
            1.0 -
            (params.ntsc_hue * params.ntsc_hue * 0.5)
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


const vec3 kY =
    vec3(
        0.2989,
        0.5870,
        0.1140
    );

const vec3 kI =
    vec3(
        0.5959,
       -0.2744,
       -0.3216
    );

const vec3 kQ =
    vec3(
        0.2115,
       -0.5229,
        0.3114
    );


vec2 triangle_wave(float x)
{
    vec2 val =
        abs(
            fract(
                vec2(
                    x * 0.159,
                    x * 0.159 + 0.25
                )
            ) * 2.0 -
            1.0
        ) * 2.0 -
        1.0;

    return val;
}


float hash(vec2 co)
{
    return fract(
        sin(
            dot(
                co,
                vec2(
                    12.9898,
                    78.233
                )
            )
        ) *
        43758.5453
    );
}


void main()
{
    vec2 ps =
        1.0 /
        global.SourceSize.xy;

    float time =
        mod(
            float(global.FrameCount),
            1024.0
        );

    vec2 uv =
        vTexCoord;


    if (params.JITTER > 0.0)
    {
        uv.x +=
            (
                hash(
                    vec2(
                        time,
                        uv.y
                    )
                ) -
                0.5
            )
            *
            params.JITTER *
            ps.x;
    }


    // [A] 4 Dither Fetches

    float d_v =
        max(
            params.de_dither,
            1.0
        );

    vec3 cL2 =
        texture(
            Source,
            uv -
            vec2(
                ps.x *
                d_v *
                2.0,
                0.0
            )
        ).rgb;

    vec3 cL1 =
        texture(
            Source,
            uv -
            vec2(
                ps.x *
                d_v,
                0.0
            )
        ).rgb;

    vec3 cR1 =
        texture(
            Source,
            uv +
            vec2(
                ps.x *
                d_v,
                0.0
            )
        ).rgb;

    vec3 cR2 =
        texture(
            Source,
            uv +
            vec2(
                ps.x *
                d_v *
                2.0,
                0.0
            )
        ).rgb;


    // [B] 5 Chroma Fetches

    float c_off =
        max(
            params.COL_BLEED,
            1.0
        );

    vec3 cM =
        texture(
            Source,
            uv
        ).rgb;

    vec3 cbL2 =
        texture(
            Source,
            uv -
            vec2(
                ps.x *
                c_off *
                2.0,
                0.0
            )
        ).rgb;

    vec3 cbL1 =
        texture(
            Source,
            uv -
            vec2(
                ps.x *
                c_off,
                0.0
            )
        ).rgb;

    vec3 cbR1 =
        texture(
            Source,
            uv +
            vec2(
                ps.x *
                c_off,
                0.0
            )
        ).rgb;

    vec3 cbR2 =
        texture(
            Source,
            uv +
            vec2(
                ps.x *
                c_off *
                2.0,
                0.0
            )
        ).rgb;


    float yM =
        dot(
            cM,
            kY
        );

    float yL =
        dot(
            cL1,
            kY
        );

    float yR =
        dot(
            cR1,
            kY
        );


    // De-dither Logic

    float edge =
        abs(yL - yM) +
        abs(yR - yM) -
        abs(yL - yR);

    float mask =
        clamp(
            (edge - 0.02) *
            4.5,
            0.0,
            1.0
        );

    vec3 dither_avg =
        (
            cL2 +
            cL1 * 2.0 +
            cR1 * 2.0 +
            cR2
        ) /
        6.0;

    float y =
        mix(
            yM,
            dot(
                dither_avg,
                kY
            ),
            params.de_dither *
            mask
        );


    // Chroma Processing

    float fI =
        (
            dot(cbL2, kI) +
            dot(cbL1, kI) * 2.0 +
            dot(cM, kI) * 3.0 +
            dot(cbR1, kI) * 2.0 +
            dot(cbR2, kI)
        ) /
        9.0;

    float fQ =
        (
            dot(cbL2, kQ) +
            dot(cbL1, kQ) * 2.0 +
            dot(cM, kQ) * 3.0 +
            dot(cbR1, kQ) * 2.0 +
            dot(cbR2, kQ)
        ) /
        9.0;


    if (params.COL_BLEED > 0.1)
    {
        fI =
            mix(
                dot(cM, kI),
                fI,
                0.75
            );

        fQ =
            mix(
                dot(cM, kQ),
                fQ,
                0.75
            );

        if (params.red_persistence > 0.0)
        {
            fI =
                mix(
                    fI,
                    dot(cbL1, kI),
                    0.45 *
                    params.red_persistence
                );
        }
    }


    if (params.rb_power > 0.0)
    {
        float ang =
            (
                uv.x *
                global.SourceSize.x /
                params.rb_size
            )
            +
            (
                uv.y *
                global.SourceSize.y *
                params.rb_slant
            )
            +
            (
                time *
                params.rb_speed
            )
            +
            params.rb_phase;

        vec2 wave =
            triangle_wave(
                ang
            );

        fI +=
            wave.x *
            params.rb_power *
            mask *
            params.rb_sat;

        fQ +=
            wave.y *
            params.rb_power *
            mask *
            params.rb_sat;
    }


    if (params.MD_SHARP > 0.0)
    {
        y +=
            (yM - yL) *
            params.MD_SHARP;
    }


    if (params.black_bleed > 0.0)
    {
        y -=
            params.black_bleed *
            clamp(
                (0.3 - y) /
                0.3,
                0.0,
                1.0
            ) *
            0.2;
    }


    if (params.jail_str > 0.0)
    {
        y +=
            triangle_wave(
                uv.x *
                50.0 *
                params.jail_width
            ).x *
            params.jail_str *
            0.02;
    }


    if (params.sig_noise > 0.0)
    {
        y +=
            (
                fract(
                    uv.x *
                    uv.y *
                    time *
                    1000.0
                ) -
                0.5
            ) *
            params.sig_noise;
    }


    if (params.fringe_str > 0.0)
    {
        fI +=
            (yM - yR) *
            params.fringe_str *
            0.5;

        fQ -=
            (yM - yL) *
            params.fringe_str *
            0.3;
    }


    float resI =
        (
            fI * hTrig.y -
            fQ * hTrig.x
        ) *
        params.SATURATION;

    float resQ =
        (
            fI * hTrig.x +
            fQ * hTrig.y
        ) *
        params.SATURATION;


    vec3 res =
        vec3(
            y + 0.956 * resI + 0.621 * resQ,
            y - 0.272 * resI - 0.647 * resQ,
            y - 1.106 * resI + 1.703 * resQ
        );


    if (params.MD_WARM != 0.0)
    {
        res.r +=
            params.MD_WARM;
    }

    res *=
        params.BRIGHTNESS;


    // Black Level Adjustment

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