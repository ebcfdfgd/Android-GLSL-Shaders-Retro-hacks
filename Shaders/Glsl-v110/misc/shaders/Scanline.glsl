#version 110

/*
    Scanlines Standalone Shader
    ---------------------------
*/

#pragma parameter scanline_amount      "Scanline Amount"           0.12 0.0 0.5 0.02
#pragma parameter scanline_scale       "Scanline Density"          1.0  1.0 4.0 0.5

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

uniform float scanline_amount;
uniform float scanline_scale;

// Scanline Pattern
float scanlinePattern(vec2 fragCoord, float scale) {
    float line = sin(fragCoord.y / scale * 3.14159);
    return line * 0.5 + 0.5;
}

void main() {
    vec3 C = texture2D(Texture, uv).rgb;

    // Scanlines Overlay
    float scan = scanlinePattern(
        uv * TextureSize,
        scanline_scale
    );

    C *= mix(
        1.0,
        scan,
        scanline_amount
    );

    gl_FragColor = vec4(clamp(C, 0.0, 1.0), 1.0);
}

#endif