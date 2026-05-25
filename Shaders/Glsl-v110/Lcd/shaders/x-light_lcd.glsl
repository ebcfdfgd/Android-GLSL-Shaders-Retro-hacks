#version 110
#extension GL_OES_standard_derivatives : enable

#pragma parameter BRIGHT_BOOST "BightBoost" 1.0 1.0 2.0 0.01
#pragma parameter MASK_STRENGTH "Mask Strength" 0.15 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width" 6.75 1.0 8.0 0.01
#pragma parameter SCAN_LINE "Horizontal Scan Dim" 0.10 0.0 0.50 0.01

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
uniform vec2 TextureSize;

#ifdef PARAMETER_UNIFORM
uniform float BRIGHT_BOOST;
uniform float MASK_STRENGTH;
uniform float MASK_W;
uniform float SCAN_LINE;
#endif

void main() {
    vec3 res = texture2D(Texture, uv).rgb;

    float pixel_y = uv.y * TextureSize.y;
    float filter_width = max(fwidth(pixel_y), 0.001);
    float wave = abs(fract(pixel_y) - 0.5);
    
    float scan_smooth = smoothstep(0.35 - filter_width, 0.35 + filter_width, wave);
    float scan_dim_multiplier = mix(1.0, 1.0 - SCAN_LINE, scan_smooth);

    float W = floor(MASK_W);
    float pos = mod(gl_FragCoord.x, W) / W;
    vec3 mcol = clamp(2.0 - abs(pos * 6.0 - vec3(1.0, 3.0, 5.0)), 0.0, 1.0);
    res *= mix(vec3(1.0), mcol, MASK_STRENGTH);
    res *= scan_dim_multiplier;
    res *= BRIGHT_BOOST;

    gl_FragColor = vec4(res, 1.0);
}
#endif