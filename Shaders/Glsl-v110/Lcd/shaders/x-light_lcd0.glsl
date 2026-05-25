#version 110
#extension GL_OES_standard_derivatives : enable


#pragma parameter BRIGHT_BOOST "BightBoost" 1.0 1.0 2.0 0.01
#pragma parameter MASK_STRENGTH "Mask Strength" 0.15 0.0 1.0 0.05
#pragma parameter MASK_W "Mask Width" 6.75 1.0 8.0 0.01
#pragma parameter SCAN_LINE "Horizontal Scan Dim" 0.10 0.0 0.50 0.01
#pragma parameter SCAN_SIZE "Scanline Scale/Zoom" 3.0 1.0 10.0 1.0

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
uniform float SCAN_SIZE;
#endif

void main() {
    vec3 res = texture2D(Texture, uv).rgb;

    float scan_pos_y = gl_FragCoord.y / SCAN_SIZE;
    float y_mod = mod(scan_pos_y, 1.0);
    float scan_dim_multiplier = (y_mod > 0.15) ? 1.0 : (1.0 - SCAN_LINE);

    float W = floor(MASK_W);
    float pos = mod(gl_FragCoord.x, W) / W;
    vec3 mcol = clamp(2.0 - abs(pos * 6.0 - vec3(1.0, 3.0, 5.0)), 0.0, 1.0);
    res *= mix(vec3(1.0), mcol, MASK_STRENGTH);
    res *= scan_dim_multiplier;
res *= BRIGHT_BOOST;

    gl_FragColor = vec4(res, 1.0);
}
#endif