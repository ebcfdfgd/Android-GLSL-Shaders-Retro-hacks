#version 110

/* 777-NTSC-MEGA-LITE-CLEAN (AUTO-ADAPTIVE)
   - FIXED: Dynamic Tilt (Resolution-based: 320px = Straight, 256px = Tilted).
   - OPTIMIZED: Auto-Scaling Crawl Speed (Resolution Aware).
   - DYNAMIC: Independent Speed Control (256px vs 320px).
*/

#pragma parameter NTSC_BRIGHTNESS "Signal Brightness" 1.0 0.0 2.0 0.05
#pragma parameter SATURATION "Global Saturation" 1.0 0.0 2.0 0.05
#pragma parameter COL_BLEED "Chroma Bleed Strength" 1.5 0.0 5.0 0.05
#pragma parameter rb_power "Rainbow Strength" 0.07 0.0 2.0 0.01
#pragma parameter rb_size "Rainbow Width" 3.0 0.5 10.0 0.1
#pragma parameter rb_detect "Rainbow Detection" 0.30 0.0 1.0 0.01
#pragma parameter rb_speed "Rainbow Crawl Speed" 0.5 0.0 2.0 0.05
#pragma parameter rb_tilt "Rainbow Diagonal Tilt" 0.5 -2.0 2.0 0.1
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
uniform float NTSC_BRIGHTNESS, SATURATION, COL_BLEED, rb_power, rb_size, rb_detect, rb_speed, rb_tilt, de_dither;
#endif

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

vec2 triangle_wave(float x) {
    vec2 val = abs(fract(vec2(x * 0.159, x * 0.159 + 0.25)) * 2.0 - 1.0) * 2.0 - 1.0;
    return val;
}

void main() {
    float res_scale = TextureSize.y / 240.0;
    
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
    final_y *= NTSC_BRIGHTNESS;

    float fI = yiqM.y;
    float fQ = yiqM.z;

    if (COL_BLEED > 0.0) {
        vec2 b_off = ps * COL_BLEED * (1.5 * res_scale); 
        vec3 bcL = RGB_to_YIQ * texture2D(Texture, vTexCoord - b_off).rgb;
        vec3 bcR = RGB_to_YIQ * texture2D(Texture, vTexCoord + b_off).rgb;
        fI = mix(fI, (bcL.y + bcR.y) * 0.5, 0.7);
        fQ = mix(fQ, (bcL.z + bcR.z) * 0.5, 0.7);
    }

    if (rb_power > 0.0) {
        // --- Tuning Zone ---
        const float SPEED_AT_256 = 1.6; // تحكم في سرعة الـ 256 هنا
        const float SPEED_AT_320 = 0.2; // تحكم في سرعة الـ 320 هنا
        // -------------------

        float edge = abs(yiqM.x - yiqL.x) + abs(yiqM.x - yiqR.x);
        float mask = smoothstep(rb_detect, rb_detect + 0.1, edge);
        
        // 1. Tilt: 256px = Full Tilt, 320px = Straight
        float tilt_res_factor = clamp((TextureSize.x - 256.0) / (320.0 - 256.0), 0.0, 1.0);
        float corrected_tilt = rb_tilt * (1.0 - tilt_res_factor);
        
        // 2. Dynamic Speed
        float speed_factor = mix(SPEED_AT_256, SPEED_AT_320, tilt_res_factor);
        
        float adjusted_rb_size = rb_size * res_scale;
        float auto_speed = rb_speed * res_scale * speed_factor;

        float ang = (vTexCoord.x * TextureSize.x / adjusted_rb_size) + 
                    (vTexCoord.y * TextureSize.y * corrected_tilt) + 
                    (time * auto_speed);
        
        vec2 wave = triangle_wave(ang);
        
        fI += wave.x * rb_power * mask;
        fQ += wave.y * rb_power * mask;
    }

    vec3 res = YIQ_to_RGB * vec3(final_y, fI * SATURATION, fQ * SATURATION);

    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
#endif