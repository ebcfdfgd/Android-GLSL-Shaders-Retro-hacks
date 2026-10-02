#version 110

/*
    Ben-Day Dots Standalone Shader (Physical Screen Pixels)
    -------------------------------------------------------
*/

#pragma parameter DOT_DENSITY  "Dot Grid Size (px)"     6.0  3.0 16.0 0.5
#pragma parameter DOT_ANGLE    "Dot Grid Angle (deg)"   15.0 0.0 90.0 5.0
#pragma parameter DOT_STRENGTH "Dot Shading Strength"   0.85 0.0 1.0 0.05

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
precision mediump float;
#endif

varying vec2 uv;
uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform vec2 OutputSize;

uniform float DOT_DENSITY;
uniform float DOT_ANGLE;
uniform float DOT_STRENGTH;

const vec3 Y = vec3(0.299, 0.587, 0.114);

// Ben-Day Dot Pattern Generator
float benDayDot(vec2 fragCoord, float density, float angleDeg, float darkness) {
    float angle = radians(angleDeg);

    vec2 rotated = vec2(
        fragCoord.x * cos(angle) - fragCoord.y * sin(angle),
        fragCoord.x * sin(angle) + fragCoord.y * cos(angle)
    );

    vec2 cell = mod(rotated, density) - density * 0.5;
    float dist = length(cell);
    float radius = darkness * (density * 0.5);

    return 1.0 - smoothstep(
        radius - 1.0,
        radius + 1.0,
        dist
    );
}

void main() {
    vec3 color = texture2D(Texture, uv).rgb;

    // Ben-Day Dots Shading Overlay locked to physical screen resolution (OutputSize)
    float finalLum = dot(color, Y);
    float darkness = 1.0 - finalLum;
    
    vec2 screenCoord = uv * OutputSize;
    float dotPattern = benDayDot(
        screenCoord,
        DOT_DENSITY,
        DOT_ANGLE,
        darkness
    );

    color = mix(
        color,
        vec3(0.0),
        dotPattern * DOT_STRENGTH * 0.4
    );

    gl_FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}

#endif