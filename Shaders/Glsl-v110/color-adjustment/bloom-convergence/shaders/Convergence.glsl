#version 110

#pragma parameter CONV_X "Convergence Horizontal" 0.05 -1.0 1.0 0.01
#pragma parameter CONV_Y "Convergence Vertical" 0.0 -1.0 1.0 0.01

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

uniform float CONV_X;
uniform float CONV_Y;

void main() {

    // Convergence
    vec2 conv = 0.01 * vec2(CONV_X, CONV_Y);

    vec2 red_coord   = uv + conv;
    vec2 green_coord = uv;
    vec2 blue_coord  = uv - conv;

    // 3 Texture Fetches
    vec3 red_light   = texture2D(Texture, red_coord).rgb;
    vec3 green_light = texture2D(Texture, green_coord).rgb;
    vec3 blue_light  = texture2D(Texture, blue_coord).rgb;

    // Combine RGB channels
    vec3 res = vec3(
        red_light.r,
        green_light.g,
        blue_light.b
    );

    gl_FragColor = vec4(res, 1.0);
}

#endif