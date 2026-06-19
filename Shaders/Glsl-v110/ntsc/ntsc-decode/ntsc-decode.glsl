#version 110

/* NTSC-PHYSICAL-DECODE-PASS */

#pragma parameter NTSC_BRIGHTNESS "Signal Brightness" 1.1 0.0 2.0 0.05
#pragma parameter SATURATION "Global Saturation" 1.2 0.0 2.0 0.05
#pragma parameter de_dither "MD De-Dither Intensity" 1.0 0.0 2.0 0.1
#pragma parameter GAMMA "Gamma" 0.85 0.5 1.5 0.01

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 vTexCoord;
uniform mat4 MVPMatrix;
void main() {
    vTexCoord = TexCoord;
    gl_Position = MVPMatrix * VertexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 vTexCoord;
uniform sampler2D Texture;
uniform vec2 TextureSize;

#ifdef PARAMETER_UNIFORM
uniform float NTSC_BRIGHTNESS, SATURATION, de_dither, GAMMA;
#endif

const mat3 YIQ_to_RGB = mat3(
    1.0,    1.0,    1.0,
    0.956, -0.272, -1.106,
    0.621, -0.647,  1.703
);

void main() {
    vec2 ps = vec2(1.0 / TextureSize.x, 0.0);
    vec4 yiq = texture2D(Texture, vTexCoord);
    
    // CRITICAL FIX: Restore original negative and positive ranges for I and Q
    yiq.y = (yiq.y - 0.5) * 2.0;
    yiq.z = (yiq.z - 0.5) * 2.0;
    
    // Luma-only De-dithering
    float d_off = max(de_dither, 1.0);
    float yL = texture2D(Texture, vTexCoord - ps * d_off).x;
    float yR = texture2D(Texture, vTexCoord + ps * d_off).x;
    
    float final_y = (de_dither > 0.0) ? mix(yiq.x, (yL + yR) * 0.5, 0.5 * de_dither) : yiq.x;
    final_y *= NTSC_BRIGHTNESS;

    // Convert Signal back to Monitor RGB
    vec3 res = YIQ_to_RGB * vec3(final_y, yiq.y * SATURATION, yiq.z * SATURATION);
    
    // Apply Gamma Correction
    res = pow(max(res, 0.0), vec3(1.0 / GAMMA));
    
    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
#endif