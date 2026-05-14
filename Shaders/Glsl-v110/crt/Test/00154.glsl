#version 110

/*
    MINI-CRT RGB FAST
    - Ultra Lightweight CRT Shader
    - RGB Mask
    - Fast Curvature
    - GLSL110 / GLES2 SAFE
    - RetroArch Ready
*/

//==================================================
// PARAMETERS
//==================================================

#pragma parameter CURVE "CRT Curve" 0.10 0.0 0.50 0.01
#pragma parameter VIGNETTE "Vignette" 0.18 0.0 1.0 0.01
#pragma parameter BRIGHTNESS "Brightness" 1.10 0.5 2.0 0.01
#pragma parameter SCANLINE "Scanline Strength" 0.10 0.0 1.0 0.01
#pragma parameter MASK_STRENGTH "RGB Mask Strength" 0.20 0.0 1.0 0.01

//==================================================
// VERTEX
//==================================================

#if defined(VERTEX)

attribute vec4 VertexCoord;
attribute vec4 TexCoord;

uniform mat4 MVPMatrix;
uniform vec2 TextureSize;
uniform vec2 InputSize;

varying vec2 TEX0;
varying vec2 scale;

void main()
{
    gl_Position = MVPMatrix * VertexCoord;

    TEX0 = TexCoord.xy;

    scale = TextureSize / InputSize;
}

#elif defined(FRAGMENT)

//==================================================
// FRAGMENT
//==================================================

#ifdef GL_ES
precision mediump float;
#endif

uniform sampler2D Texture;

uniform vec2 OutputSize;

varying vec2 TEX0;
varying vec2 scale;

#ifdef PARAMETER_UNIFORM
uniform float CURVE;
uniform float VIGNETTE;
uniform float BRIGHTNESS;
uniform float SCANLINE;
uniform float MASK_STRENGTH;
#endif

//==================================================
// RGB MASK
//==================================================

vec3 rgb_mask(float x)
{
    float m = mod(floor(x), 3.0);

    return mix(
        mix(
            vec3(1.0, 0.75, 0.75),
            vec3(0.75, 1.0, 0.75),
            step(1.0, m)
        ),
        vec3(0.75, 0.75, 1.0),
        step(2.0, m)
    );
}

//==================================================
// MAIN
//==================================================

void main()
{
    //----------------------------------------------
    // CURVE
    //----------------------------------------------

    vec2 p = (TEX0 * scale) - 0.5;

    float r2 = dot(p, p);

    vec2 curved = p * (1.0 + r2 * CURVE);

    //----------------------------------------------
    // BORDER CHECK
    //----------------------------------------------

    vec2 inside = step(abs(curved), vec2(0.5));

    float border = inside.x * inside.y;

    //----------------------------------------------
    // UV
    //----------------------------------------------

    vec2 uv = (curved + 0.5) / scale;

    //----------------------------------------------
    // FETCH
    //----------------------------------------------

    vec3 col = texture2D(Texture, uv).rgb;

    //----------------------------------------------
    // VIGNETTE
    //----------------------------------------------

    col *= (1.0 - r2 * VIGNETTE);

    //----------------------------------------------
    // SCANLINES
    //----------------------------------------------

    float scan = sin(TEX0.y * OutputSize.y * 3.14159);

    col *= 1.0 - (SCANLINE * 0.15 * (0.5 - scan * 0.5));

    //----------------------------------------------
    // RGB MASK
    //----------------------------------------------

    vec3 mask = rgb_mask(gl_FragCoord.x);

    col *= mix(vec3(1.0), mask, MASK_STRENGTH);

    //----------------------------------------------
    // FINAL
    //----------------------------------------------

    col *= BRIGHTNESS;

    gl_FragColor = vec4(
        clamp(col, 0.0, 1.0) * border,
        1.0
    );
}

#endif