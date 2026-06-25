#version 110

/* 777-NTSC-MEGA-LITE-CLEAN (TRIANGLE-WAVE OPTIMIZED)
    - FIXED: Removed sin/cos for performance.
    - OPTIMIZED: Triangle wave for Rainbow effect.
    - ADDED: Black Level and Gamma Control.
*/

#pragma parameter NTSC_BRIGHTNESS "Signal Brightness" 1.1 0.0 2.0 0.01
#pragma parameter SATURATION "Global Saturation" 1.15 0.0 2.0 0.05
//#pragma parameter BLACK_LEVEL "Black Level" 0.0 0.0 1.0 0.01
#pragma parameter GAMMA "Gamma" 0.85 0.5 1.5 0.01
#pragma parameter COL_BLEED "Chroma Bleed Strength" 2.5 0.0 5.0 0.05
#pragma parameter rb_power "Rainbow Strength" 0.08 0.0 2.0 0.01
#pragma parameter rb_size "Rainbow Width" 4.5 0.5 10.0 0.1
#pragma parameter rb_detect "Rainbow Detection" 0.30 0.0 1.0 0.01
#pragma parameter rb_speed "Rainbow Crawl Speed" 0.1 0.0 2.0 0.01
#pragma parameter rb_tilt "Rainbow Diagonal Tilt" 0.0 -2.0 2.0 0.1
#pragma parameter de_dither "MD De-Dither Intensity" 1.0 0.0 2.0 0.1

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 vTexCoord;
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform int FrameCount;
varying vec2 vTexCoord;

#ifdef PARAMETER_UNIFORM
uniform float NTSC_BRIGHTNESS, SATURATION, BLACK_LEVEL, GAMMA, COL_BLEED, rb_power, rb_size, rb_detect, rb_speed, rb_tilt, de_dither;
#endif

const mat3 RGB_to_YIQ = mat3(
    0.299,  0.596,  0.211,
    0.587, -0.274, -0.523,
    0.114, -0.322,  0.312
);

const mat3 YIQ_to_RGB = mat3(
    1.0,    1.0,    1.0,
    1.110, -0.272, -1.106,
    0.260, -0.647,  1.703
);

vec2 triangle_wave(float x) {
    vec2 val = abs(fract(vec2(x * 0.159, x * 0.159 + 0.25)) * 2.0 - 1.0) * 2.0 - 1.0;
    return val;
}

void main() {
    vec2 ps = vec2(1.0 / TextureSize.x, 0.0);
    float time = float(FrameCount);

    vec3 cM = texture2D(Texture, vTexCoord).rgb;
    float d_off = max(de_dither, 1.0);
    vec3 cL = texture2D(Texture, vTexCoord - ps * d_off).rgb;
    vec3 cR = texture2D(Texture, vTexCoord + ps * d_off).rgb;

    vec3 yiqM = RGB_to_YIQ * cM;
    vec3 yiqL = RGB_to_YIQ * cL;
    vec3 yiqR = RGB_to_YIQ * cR;

    float final_y = (de_dither > 0.0) ? mix(yiqM.x, (yiqL.x + yiqR.x) * 0.5, 0.5 * de_dither) : yiqM.x;
    
    // Apply Black Level (offset before brightness)
   // final_y = max(0.0, final_y - BLACK_LEVEL);
    final_y *= NTSC_BRIGHTNESS;

    float fI = yiqM.y;
    float fQ = yiqM.z;

    if (COL_BLEED > 0.0) {
        vec2 b_off = ps * COL_BLEED * 1.5; 
        vec3 bcL = RGB_to_YIQ * texture2D(Texture, vTexCoord - b_off).rgb;
        vec3 bcR = RGB_to_YIQ * texture2D(Texture, vTexCoord + b_off).rgb;
        fI = mix(fI, (bcL.y + bcR.y) * 0.5, 0.7);
        fQ = mix(fQ, (bcL.z + bcR.z) * 0.5, 0.7);
    }

    if (rb_power > 0.0) {
        float edge = abs(yiqM.x - yiqL.x) + abs(yiqM.x - yiqR.x);
        float mask = smoothstep(rb_detect, rb_detect + 0.1, edge);
        
        float ang = (vTexCoord.x * TextureSize.x / rb_size) + (vTexCoord.y * TextureSize.y * rb_tilt) + (time * rb_speed);
        
        vec2 wave = triangle_wave(ang);
        
        fI += wave.x * rb_power * mask;
        fQ += wave.y * rb_power * mask;
    }

    vec3 res = YIQ_to_RGB * vec3(final_y, fI * SATURATION, fQ * SATURATION);
    
    // Apply Gamma Correction
    res = pow(max(res, 0.0), vec3(1.0 / GAMMA));

    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
#endif