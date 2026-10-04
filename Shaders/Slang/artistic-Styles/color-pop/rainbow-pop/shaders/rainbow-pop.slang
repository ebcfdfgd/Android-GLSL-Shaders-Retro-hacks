#version 450

/*
    Unichrome: Color Reduction + Grayscale + Selective Color + Rainbow Accent
    -----------------------------------------------------------------------
    Slang 450 conversion
*/

#pragma parameter UNI_GAIN             "Contrast"                    1.0  0.5 2.0 0.05
#pragma parameter UNI_LEVEL            "Brightness"                  0.0 -0.3 0.3 0.02
#pragma parameter UNI_ACCENT_THRESHOLD "Rainbow Highlight Threshold" 0.8  0.0 1.0 0.01
#pragma parameter UNI_ACCENT_STRENGTH  "Rainbow Accent Strength"     0.7  0.0 1.0 0.05
#pragma parameter UNI_RAINBOW_SCALE    "Rainbow Spatial Scale"       1.0  0.1 8.0 0.1
#pragma parameter UNI_RAINBOW_SPEED    "Rainbow Shimmer Speed"       0.15 0.0 1.0 0.01
#pragma parameter SEL_TARGET_HUE       "Selective Target Hue"        0.0  0.0 1.0 0.01
#pragma parameter SEL_HUE_WIDTH        "Selective Hue Range"         0.15 0.0 0.5 0.01
#pragma parameter SEL_MIN_SAT          "Selective Min Saturation"    0.3  0.0 1.0 0.05
#pragma parameter COLOR_LEVELS         "Color Reduction Levels"      16.0 2.0 32.0 1.0


// -------------------------------------------------------------------------
// Push Constants - RetroArch parameters
// -------------------------------------------------------------------------

layout(push_constant) uniform Push
{
    float UNI_GAIN;
    float UNI_LEVEL;
    float UNI_ACCENT_THRESHOLD;
    float UNI_ACCENT_STRENGTH;

    float UNI_RAINBOW_SCALE;
    float UNI_RAINBOW_SPEED;
    float SEL_TARGET_HUE;
    float SEL_HUE_WIDTH;

    float SEL_MIN_SAT;
    float COLOR_LEVELS;
} params;


// -------------------------------------------------------------------------
// RetroArch global data
// -------------------------------------------------------------------------

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;

    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;

    uint FrameCount;
} global;


// -------------------------------------------------------------------------
// Vertex Stage
// -------------------------------------------------------------------------

#pragma stage vertex

layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;

layout(location = 0) out vec2 vTexCoord;

void main()
{
    vTexCoord = TexCoord;

    gl_Position = global.MVP * Position;
}


// -------------------------------------------------------------------------
// Fragment Stage
// -------------------------------------------------------------------------

#pragma stage fragment

layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 2) uniform sampler2D Source;


// -------------------------------------------------------------------------
// Constants
// -------------------------------------------------------------------------

const vec3 Y = vec3(
    0.299,
    0.587,
    0.114
);


// -------------------------------------------------------------------------
// Hue Color
// -------------------------------------------------------------------------

vec3 hueColor(float h)
{
    vec4 K = vec4(
        1.0,
        2.0 / 3.0,
        1.0 / 3.0,
        3.0
    );

    vec3 p = abs(
        fract(h + K.xyz) * 6.0 - K.www
    );

    return clamp(
        p - K.xxx,
        0.0,
        1.0
    );
}


// -------------------------------------------------------------------------
// RGB -> HSV
// -------------------------------------------------------------------------

vec3 rgb2hsv(vec3 c)
{
    vec4 K = vec4(
        0.0,
        -1.0 / 3.0,
        2.0 / 3.0,
        -1.0
    );

    vec4 p = mix(
        vec4(c.bg, K.wz),
        vec4(c.gb, K.xy),
        step(c.b, c.g)
    );

    vec4 q = mix(
        vec4(p.xyw, c.r),
        vec4(c.r, p.yzx),
        step(p.x, c.r)
    );

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;

    return vec3(
        abs(
            q.z + (q.w - q.y) /
            (6.0 * d + e)
        ),

        d / (q.x + e),

        q.x
    );
}


// -------------------------------------------------------------------------
// Fragment
// -------------------------------------------------------------------------

void main()
{
    // Equivalent to:
    // vec2 gamePixel = floor(uv * TextureSize);

    vec2 gamePixel =
        floor(
            vTexCoord *
            global.SourceSize.xy
        );


    // ---------------------------------------------------------------------
    // Source color
    // ---------------------------------------------------------------------

    vec3 C =
        texture(
            Source,
            vTexCoord
        ).rgb;


    // ---------------------------------------------------------------------
    // Luminance / contrast / brightness
    // ---------------------------------------------------------------------

    float lum =
        clamp(
            dot(C, Y) *
            params.UNI_GAIN +
            params.UNI_LEVEL,

            0.0,
            1.0
        );


    // ---------------------------------------------------------------------
    // Base grayscale
    // ---------------------------------------------------------------------

    vec3 baseBW =
        vec3(lum);


    // ---------------------------------------------------------------------
    // Color reduction
    // ---------------------------------------------------------------------

    vec3 reducedC =
        floor(
            C *
            params.COLOR_LEVELS
        )
        /
        params.COLOR_LEVELS;


    // ---------------------------------------------------------------------
    // Selective color
    // ---------------------------------------------------------------------

    vec3 hsv =
        rgb2hsv(reducedC);


    float hueDist =
        abs(
            hsv.x -
            params.SEL_TARGET_HUE
        );


    hueDist =
        min(
            hueDist,
            1.0 - hueDist
        );


    float colorMask =
        (
            1.0 -
            smoothstep(
                params.SEL_HUE_WIDTH - 0.05,
                params.SEL_HUE_WIDTH + 0.05,
                hueDist
            )
        )
        *
        smoothstep(
            params.SEL_MIN_SAT - 0.1,
            params.SEL_MIN_SAT + 0.1,
            hsv.y
        );


    vec3 base =
        mix(
            baseBW,
            reducedC,
            colorMask
        );


    // ---------------------------------------------------------------------
    // Rainbow highlight mask
    // ---------------------------------------------------------------------

    float rainbowMask =
        smoothstep(
            params.UNI_ACCENT_THRESHOLD - 0.05,
            params.UNI_ACCENT_THRESHOLD + 0.05,
            lum
        );


    // ---------------------------------------------------------------------
    // Animated rainbow
    //
    // Original:
    //
    // FrameCount * UNI_RAINBOW_SPEED * 0.005
    //
    // FrameCount is converted to float explicitly because the Slang
    // RetroArch UBO uses uint FrameCount.
    // ---------------------------------------------------------------------

    float frame =
        float(global.FrameCount);


    float hue =
        fract(
            (
                gamePixel.x +
                gamePixel.y
            )
            *
            0.01 *
            params.UNI_RAINBOW_SCALE

            +

            frame *
            params.UNI_RAINBOW_SPEED *
            0.005
        );


    vec3 accent =
        hueColor(hue);


    // ---------------------------------------------------------------------
    // Final rainbow accent
    // ---------------------------------------------------------------------

    vec3 result =
        mix(
            base,
            accent,
            rainbowMask *
            params.UNI_ACCENT_STRENGTH
        );


    // ---------------------------------------------------------------------
    // Output
    // ---------------------------------------------------------------------

    FragColor =
        vec4(
            clamp(
                result,
                0.0,
                1.0
            ),
            1.0
        );
}