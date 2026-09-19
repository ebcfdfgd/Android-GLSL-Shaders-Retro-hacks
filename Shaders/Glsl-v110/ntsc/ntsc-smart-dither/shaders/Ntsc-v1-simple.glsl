#version 110

/* 777-NTSC-V1-TURBO-ULTRA-BRIGHT (NO-SIN TRIANGLE OPTIMIZED) */

#pragma parameter SATURATION "NTSC Saturation" 1.0 0.0 2.0 0.05
#pragma parameter BRIGHTNESS "Signal Brightness" 1.0 0.0 2.0 0.05
#pragma parameter COL_BLEED "Chroma Bleed Strength" 1.5 0.0 5.0 0.05
#pragma parameter rb_power "Rainbow Strength" 0.15 0.0 2.0 0.01
#pragma parameter rb_size "Rainbow Width" 3.0 0.5 10.0 0.1
#pragma parameter rb_detect "Rainbow Detection" 0.30 0.0 1.0 0.01
#pragma parameter rb_speed "Rainbow Crawl Speed" 0.5 0.0 2.0 0.05
#pragma parameter rb_tilt "Rainbow Diagonal Tilt" 0.5 -2.0 2.0 0.1
#pragma parameter ntsc_blur "Smart Dither 16 Intensity" 0.5 0.0 1.0 0.05

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
precision highp float;

uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform int FrameCount;
varying vec2 vTexCoord;

uniform float SATURATION, BRIGHTNESS, COL_BLEED, rb_power, rb_size, rb_detect, rb_speed, rb_tilt, ntsc_blur;

const mat3 RGB_to_YIQ = mat3(
    0.299,  0.596,  0.211,
    0.587, -0.274, -0.523,
    0.114, -0.322,  0.312
);

const mat3 YIQ_to_RGB = mat3(
    1.0,    1.0,    1.0,
    0.956, -0.272, -1.106,
    0.621, -0.647,  1.703
);

// دالة المثلث السريعة (بديلة sin/cos)
vec2 triangle_wave(float x) {
    vec2 val = abs(fract(vec2(x * 0.159, x * 0.159 + 0.25)) * 2.0 - 1.0) * 2.0 - 1.0;
    return val;
}

void main() {
    vec2 ps = vec2(1.0 / TextureSize.x, 0.0);
    float time = mod(float(FrameCount), 600.0); 
    
    // 1. SMART DITHER 16
    vec3 cM = texture2D(Texture, vTexCoord).rgb;
    vec3 cL = texture2D(Texture, vTexCoord - ps).rgb;
    vec3 cR = texture2D(Texture, vTexCoord + ps).rgb;
    
    vec3 yiqM = RGB_to_YIQ * cM;
    vec3 yiqL = RGB_to_YIQ * cL;
    vec3 yiqR = RGB_to_YIQ * cR;
    
    float d_mask = clamp(abs(yiqM.x - yiqL.x) * abs(yiqM.x - yiqR.x) * 50.0, 0.0, 1.0);
    d_mask *= clamp(1.0 - abs(yiqL.x - yiqR.x) * 5.0, 0.0, 1.0);
    
    vec3 col = mix(cM, (cL + cM + cR) * 0.3333, ntsc_blur * d_mask);
    vec3 yiqCol = RGB_to_YIQ * col;
    float final_y = yiqCol.x;

    // 2. CHROMA ENGINE & SATURATION
    float fI = yiqCol.y * SATURATION;
    float fQ = yiqCol.z * SATURATION;

    vec2 b_off = ps * COL_BLEED * 1.5; 
    vec3 bcL = RGB_to_YIQ * texture2D(Texture, vTexCoord - b_off).rgb;
    vec3 bcR = RGB_to_YIQ * texture2D(Texture, vTexCoord + b_off).rgb;
    
    float has_bleed = step(0.001, COL_BLEED);
    fI = mix(fI, (bcL.y + bcR.y) * 0.5 * SATURATION, 0.7 * has_bleed);
    fQ = mix(fQ, (bcL.z + bcR.z) * 0.5 * SATURATION, 0.7 * has_bleed);

    // 3. RAINBOW (NO SIN/COS)
    float edge = abs(yiqM.x - yiqL.x) + abs(yiqM.x - yiqR.x);
    // استبدال smoothstep بـ clamp لزيادة السرعة
    float rb_mask = clamp((edge - rb_detect) * 10.0, 0.0, 1.0) * step(0.001, rb_power);
    
    float ang = (vTexCoord.x * TextureSize.x / rb_size) + (vTexCoord.y * TextureSize.y * rb_tilt) + (time * rb_speed);
    
    vec2 wave = triangle_wave(ang);
    fI += wave.x * rb_power * rb_mask;
    fQ += wave.y * rb_power * rb_mask;

    // 4. FINAL ASSEMBLY
    vec3 res = YIQ_to_RGB * vec3(final_y, fI, fQ);
    res *= BRIGHTNESS;

    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
#endif