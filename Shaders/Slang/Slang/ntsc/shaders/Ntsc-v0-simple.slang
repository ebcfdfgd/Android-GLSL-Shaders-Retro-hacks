#version 450

/* 777-NTSC-MEGA-LITE-PASS1 (NTSC CORE)
    - Pass 1: Handles De-Dithering, Chroma Bleeding, and Rainbow Effects.
*/

#pragma parameter de_dither "MD De-Dither Intensity" 1.0 0.0 2.0 0.1
#pragma parameter COL_BLEED "Chroma Bleed Strength" 2.25 0.0 5.0 0.05
#pragma parameter rb_power "Rainbow Strength" 0.08 0.0 2.0 0.01
#pragma parameter rb_size "Rainbow Width" 4.5 0.5 10.0 0.1
#pragma parameter rb_detect "Rainbow Detection" 0.30 0.0 1.0 0.01
#pragma parameter rb_speed "Rainbow Crawl Speed" 0.05 0.0 2.0 0.05
#pragma parameter rb_tilt "Rainbow Diagonal Tilt" 0.0 -2.0 2.0 0.05


layout(push_constant) uniform Push
{
    float de_dither;
    float COL_BLEED;
    float rb_power;
    float rb_size;
    float rb_detect;
    float rb_speed;
    float rb_tilt;
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

void main()
{
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
}


// ============================================================================
// Fragment
// ============================================================================

#pragma stage fragment

layout(location = 0) in vec2 vTexCoord;
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


// Fast Triangle Wave for Rainbow modulation
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


    vec3 cM =
        texture(
            Source,
            vTexCoord
        ).rgb;

    float d_off =
        max(
            params.de_dither,
            1.0
        );

    vec3 cL =
        texture(
            Source,
            vTexCoord -
            ps * d_off
        ).rgb;

    vec3 cR =
        texture(
            Source,
            vTexCoord +
            ps * d_off
        ).rgb;


    vec3 yiqM =
        RGB_to_YIQ * cM;

    vec3 yiqL =
        RGB_to_YIQ * cL;

    vec3 yiqR =
        RGB_to_YIQ * cR;


    float final_y;

    if (params.de_dither > 0.0)
    {
        final_y =
            mix(
                yiqM.x,
                (yiqL.x + yiqR.x) * 0.5,
                0.5 * params.de_dither
            );
    }
    else
    {
        final_y =
            yiqM.x;
    }


    float fI =
        yiqM.y;

    float fQ =
        yiqM.z;


    if (params.COL_BLEED > 0.0)
    {
        vec2 b_off =
            ps *
            params.COL_BLEED *
            1.5;

        vec3 bcL =
            RGB_to_YIQ *
            texture(
                Source,
                vTexCoord - b_off
            ).rgb;

        vec3 bcR =
            RGB_to_YIQ *
            texture(
                Source,
                vTexCoord + b_off
            ).rgb;

        fI =
            mix(
                fI,
                (bcL.y + bcR.y) * 0.5,
                0.7
            );

        fQ =
            mix(
                fQ,
                (bcL.z + bcR.z) * 0.5,
                0.7
            );
    }


    if (params.rb_power > 0.0)
    {
        float edge =
            abs(yiqM.x - yiqL.x) +
            abs(yiqM.x - yiqR.x);

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
            triangle_wave(ang);


        fI +=
            wave.x *
            params.rb_power *
            mask;

        fQ +=
            wave.y *
            params.rb_power *
            mask;
    }


    vec3 res =
        YIQ_to_RGB *
        vec3(
            final_y,
            fI,
            fQ
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