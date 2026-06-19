#version 110

#pragma parameter R_OFF_X "Red Offset X" 0.5 -2.0 2.0 0.05
#pragma parameter R_OFF_Y "Red Offset Y" 0.0 -2.0 2.0 0.05

#pragma parameter G_OFF_X "Green Offset X" 0.0 -2.0 2.0 0.05
#pragma parameter G_OFF_Y "Green Offset Y" 0.0 -2.0 2.0 0.05

#pragma parameter B_OFF_X "Blue Offset X" -0.5 -2.0 2.0 0.05
#pragma parameter B_OFF_Y "Blue Offset Y" 0.0 -2.0 2.0 0.05

#pragma parameter BLOOM_STR "Phosphor Bleed" 0.25 0.0 1.0 0.05
#pragma parameter BLOOM_THR "Bloom Threshold" 0.10 0.0 1.0 0.01

#if defined(VERTEX)

attribute vec4 VertexCoord;
attribute vec2 TexCoord;

varying vec2 uv;

uniform mat4 MVPMatrix;

void main()
{
    uv = TexCoord;
    gl_Position = MVPMatrix * VertexCoord;
}

#elif defined(FRAGMENT)

#ifdef GL_ES
precision highp float;
#endif

varying vec2 uv;

uniform sampler2D Texture;
uniform vec2 TextureSize;

#ifdef PARAMETER_UNIFORM
uniform float R_OFF_X;
uniform float R_OFF_Y;
uniform float G_OFF_X;
uniform float G_OFF_Y;
uniform float B_OFF_X;
uniform float B_OFF_Y;
uniform float BLOOM_STR;
uniform float BLOOM_THR;
#endif

void main()
{
    vec2 px = 1.0 / TextureSize;

    //--------------------------------------------------
    // RGB CONVERGENCE (3 taps total)
    //--------------------------------------------------

    float r =
    texture2D(Texture,
    uv + vec2(R_OFF_X,R_OFF_Y)*px).r;

    float g =
    texture2D(Texture,
    uv + vec2(G_OFF_X,G_OFF_Y)*px).g;

    float b =
    texture2D(Texture,
    uv + vec2(B_OFF_X,B_OFF_Y)*px).b;

    vec3 res = vec3(r,g,b);

    //--------------------------------------------------
    // PHOSPHOR BLEED FROM CONVERGENCE
    //--------------------------------------------------

    float chroma =
        abs(r-g) +
        abs(g-b) +
        abs(b-r);

    chroma =
        max(chroma - BLOOM_THR, 0.0);

    res +=
        res *
        chroma *
        BLOOM_STR;

    //--------------------------------------------------

    gl_FragColor = vec4(res,1.0);
}

#endif