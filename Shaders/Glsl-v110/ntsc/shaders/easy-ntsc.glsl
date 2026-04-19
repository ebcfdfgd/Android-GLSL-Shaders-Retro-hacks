#version 110

/* NTSC-1000-RGB-PRO-V3 (Crawl Edition)
    - Added: rb_speed for Dot Crawl animation.
    - Added: FrameCount conversion to float for compatibility.
    - Improved: Phase rotation for smoother Crawl effect.
*/

#pragma parameter ntsc_hue "NTSC Hue Shift" 0.0 -3.14 3.14 0.05
#pragma parameter rb_power "Rainbow Power" 1.8 0.0 5.0 0.1
#pragma parameter rb_speed "Crawl Speed" 0.5 0.0 2.0 0.05
#pragma parameter de_dither "Dither Blend" 0.60 0.0 1.0 0.01
#pragma parameter COL_BLEED "Chroma Bleed Strength" 1.5 0.0 5.0 0.1
#pragma parameter red_persistence "Red Smear" 0.7 0.0 2.5 0.05
#pragma parameter pi_mod "Subcarrier Phase" 131.5 0.0 360.0 0.5
#pragma parameter vert_scal "Vertical Phase Scale" 1.0 0.0 2.0 0.01

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 vTexCoord;
varying vec2 hue_trig; 
uniform mat4 MVPMatrix;
uniform float ntsc_hue;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord;
    hue_trig = vec2(cos(ntsc_hue), sin(ntsc_hue));
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform int FrameCount;
varying vec2 vTexCoord;
varying vec2 hue_trig;

#ifdef PARAMETER_UNIFORM
uniform float ntsc_hue, rb_power, rb_speed, de_dither, COL_BLEED, red_persistence, pi_mod, vert_scal;
#endif

#define PI 3.1415926535

void main() {
    vec2 ps = 1.0 / TextureSize;
    float time = float(FrameCount);
    
    // 1. ANALYTICAL FETCH
    vec3 col_m = texture2D(Texture, vTexCoord).rgb;
    vec3 col_l = texture2D(Texture, vTexCoord - vec2(ps.x, 0.0)).rgb;
    vec3 col_r = texture2D(Texture, vTexCoord + vec2(ps.x, 0.0)).rgb;

    float y_m = dot(col_m, vec3(0.299, 0.587, 0.114));
    float y_l = dot(col_l, vec3(0.299, 0.587, 0.114));
    float y_r = dot(col_r, vec3(0.299, 0.587, 0.114));

    // 2. EDGE DETECTION
    float edge = abs(y_l - y_m) + abs(y_r - y_m) - abs(y_l - y_r);
    float rb_mask = smoothstep(0.02, 0.20, edge);
    float final_y = mix(y_m, (y_l + y_m + y_r) * 0.3333, de_dither * rb_mask);

    // 3. RGB RAINBOW PHASE ENGINE (With Crawl Logic)
    float x_c = floor(vTexCoord.x * TextureSize.x);
    float y_c = floor(vTexCoord.y * TextureSize.y);
    
    // إضافة rb_speed للوقت لخلق تأثير الزحف (Dot Crawl)
    // mod(time, 2.0) تعطي اهتزاز الإطارات، و (time * rb_speed) تعطي حركة الزحف المستمرة
    float p_angle = (x_c * pi_mod * 0.01745) + (y_c * vert_scal * PI) + (mod(time, 2.0) * PI) + (time * rb_speed);
    
    float wave_i = sin(p_angle);
    float wave_q = cos(p_angle);

    // 4. CHROMA ENGINE
    float i = dot(col_m, vec3(0.5957, -0.2744, -0.3212));
    float q = dot(col_m, vec3(0.2114, -0.5227, 0.3113));

    // حقن الرينبو
    i += wave_i * rb_mask * rb_power;
    q += wave_q * rb_mask * rb_power;

    // 5. CHROMA BLEED & RED SMEAR
    if (COL_BLEED > 0.0) {
        float b_dist = ps.x * COL_BLEED;
        vec3 c_l = texture2D(Texture, vTexCoord - vec2(b_dist, 0.0)).rgb;
        vec3 c_r = texture2D(Texture, vTexCoord + vec2(b_dist, 0.0)).rgb;
        
        float i_l = dot(c_l, vec3(0.5957, -0.2744, -0.3212));
        float i_r = dot(c_r, vec3(0.5957, -0.2744, -0.3212));
        float q_l = dot(c_l, vec3(0.2114, -0.5227, 0.3113));
        float q_r = dot(c_r, vec3(0.2114, -0.5227, 0.3113));

        i = mix(i, (i_l + i_r) * 0.5, 0.5);
        q = mix(q, (q_l + q_r) * 0.5, 0.5);
        i = mix(i, i_l, 0.6 * red_persistence);
    }

    // 6. FINAL ASSEMBLY
    float fI = i * hue_trig.x - q * hue_trig.y;
    float fQ = i * hue_trig.y + q * hue_trig.x;

    vec3 rgb = vec3(
        final_y + 0.956 * fI + 0.621 * fQ,
        final_y - 0.272 * fI - 0.647 * fQ,
        final_y - 1.106 * fI + 1.703 * fQ
    );

    gl_FragColor = vec4(clamp(rgb, 0.0, 1.0), 1.0);
}
#endif