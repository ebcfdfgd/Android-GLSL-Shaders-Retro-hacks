#version 450

/*
    PURE-COLOR-INVERTER WITH HUE
    - PURPOSE: Pure mathematical color inversion with adjustable Hue shift.
    - HOW IT WORKS: Inverts RGB channels instantly and shifts the Hue of the result.
*/

// ============================================================================
// RetroArch Parameters
// ============================================================================

#pragma parameter INV_HUE "Invert Hue Shift" 0.0 0.0 360.0 5.0

layout(push_constant) uniform Push
{
    float INV_HUE;
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

layout(location = 0) out vec2 vTexCoord;

void main()
{
    gl_Position =
        global.MVP *
        Position;

    vTexCoord =
        TexCoord.xy;
}


// ============================================================================
// Fragment Stage
// ============================================================================

#pragma stage fragment

layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 2) uniform sampler2D Source;


// ============================================================================
// RGB → HSV
// ============================================================================

vec3 rgb2hsv(vec3 c)
{
    vec4 K =
        vec4(
            0.0,
           -1.0 / 3.0,
            2.0 / 3.0,
           -1.0
        );

    vec4 p;

    if (c.g < c.b)
    {
        p = vec4(c.b, c.g, K.w, K.z);
    }
    else
    {
        p = vec4(c.g, c.b, K.x, K.y);
    }

    vec4 q;

    if (c.r < p.x)
    {
        q = vec4(p.x, p.y, p.w, c.r);
    }
    else
    {
        q = vec4(c.r, p.y, p.z, p.x);
    }

    float d =
        q.x -
        min(q.w, q.y);

    float e =
        1.0e-10;

    return vec3(
        abs(
            q.z +
            (q.w - q.y) /
            (6.0 * d + e)
        ),
        d / (q.x + e),
        q.x
    );
}


// ============================================================================
// HSV → RGB
// ============================================================================

vec3 hsv2rgb(float h, float s, float v)
{
    h =
        h / 60.0;

    float i =
        floor(h);

    float f =
        h - i;

    float p =
        v * (1.0 - s);

    float q =
        v * (1.0 - s * f);

    float t =
        v * (1.0 - s * (1.0 - f));

    vec3 res =
        vec3(v, t, p) *
        step(abs(h - 0.0), 0.5)

        +

        vec3(q, v, p) *
        step(abs(h - 1.0), 0.5)

        +

        vec3(p, v, t) *
        step(abs(h - 2.0), 0.5)

        +

        vec3(p, q, v) *
        step(abs(h - 3.0), 0.5)

        +

        vec3(t, p, v) *
        step(abs(h - 4.0), 0.5)

        +

        vec3(v, p, q) *
        step(abs(h - 5.0), 0.5);

    return res;
}


// ============================================================================
// Main
// ============================================================================

void main()
{
    // 1. Read core pixel color
    vec3 core_col =
        texture(
            Source,
            vTexCoord
        ).rgb;


    // 2. Pure mathematical color inversion
    vec3 inverted_col =
        vec3(1.0) -
        core_col;


    // 3. Convert to HSV
    vec3 hsv =
        rgb2hsv(inverted_col);


    // 4. Shift Hue only
    float shifted_hue =
        mod(
            (hsv.x * 360.0) +
            params.INV_HUE,
            360.0
        );


    // 5. Convert back to RGB
    vec3 final_col =
        hsv2rgb(
            shifted_hue,
            hsv.y,
            hsv.z
        );


    // 6. Output final color
    FragColor =
        vec4(
            final_col,
            1.0
        );
}