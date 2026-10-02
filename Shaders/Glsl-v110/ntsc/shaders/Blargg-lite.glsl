#version 110

/* Blargg Ultra-Lite (NO-SIN TRIANGLE OPTIMIZED)
   - FIXED: Removed sin/cos completely for Adreno compatibility.
   - FIXED: Replaced hash with Fast Linear Pseudo-Random.
*/

#pragma parameter BRIGHTNESS "Signal Brightness" 1.0 0.0 2.0 0.05
#pragma parameter SATURATION "Saturation" 1.0 0.0 2.0 0.05
#pragma parameter COL_BLEED "Chroma Bleed Strength" 1.5 0.0 5.0 0.1
#pragma parameter rb_global_strength "Rainbow Master Power" 1.0 0.0 5.0 0.1
#pragma parameter rb_power "Rainbow Transparency (Mix)" 0.35 0.0 2.0 0.01
#pragma parameter dot_crawl "Dot Crawl Intensity" 0.25 0.0 1.0 0.01
#pragma parameter de_dither "Dither Blending Strength" 0.50 0.0 1.0 0.01
#pragma parameter pi_mod "Subcarrier Phase Angle" 131.5 0.0 360.0 0.1
#pragma parameter vert_scal "Vertical Phase Scale" 0.5 0.0 2.0 0.01
#pragma parameter sig_noise "Signal RF Grain" 0.04 0.0 10.2 0.01

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

uniform float BRIGHTNESS, SATURATION, COL_BLEED, rb_global_strength, rb_power, dot_crawl, de_dither, pi_mod, vert_scal, sig_noise;

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

// دالة المثلث البديلة للـ sin/cos
vec2 triangle_wave(float x) {
    vec2 val = abs(fract(vec2(x * 0.159, x * 0.159 + 0.25)) * 2.0 - 1.0) * 2.0 - 1.0;
    return val;
}

// دالة ضجيج خطية سريعة جداً
float hash(vec2 co) { return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453); }

void main() {
    vec3 col_m = texture2D(Texture, vTexCoord).rgb;
    float time = float(FrameCount);

    vec2 ps = 1.0 / TextureSize;
    vec2 d_off = ps * max(de_dither, 1.0);
    vec3 col_l = texture2D(Texture, vTexCoord - d_off).rgb;
    vec3 col_r = texture2D(Texture, vTexCoord + d_off).rgb;

    vec3 yiq_m = RGB_to_YIQ * col_m;
    vec3 yiq_l = RGB_to_YIQ * col_l;
    vec3 yiq_r = RGB_to_YIQ * col_r;

    float edge = abs(yiq_l.x - yiq_m.x) + abs(yiq_r.x - yiq_m.x) - abs(yiq_l.x - yiq_r.x);
    float rb_mask = smoothstep(0.02, 0.22, edge);

    float final_y = mix(yiq_m.x, (yiq_l.x + yiq_m.x + yiq_r.x) * 0.3333, de_dither * rb_mask) * BRIGHTNESS;

    float x_c = floor(vTexCoord.x * TextureSize.x);
    float y_c = floor(vTexCoord.y * TextureSize.y);
    float phase = (x_c * pi_mod * 0.01745) + (y_c * vert_scal * 3.1416) + (mod(time, 2.0) * 3.1416);
    
    // استخدام الموجة المثلثية
    vec2 wave = triangle_wave(phase);
    final_y += wave.x * dot_crawl * rb_mask;
    
    if (sig_noise > 0.0)
        final_y += (hash(vTexCoord + time * 0.01) - 0.5) * sig_noise;

    float i = yiq_m.y;
    float q = yiq_m.z;

    if (rb_power > 0.0) {
        i = mix(i, i + wave.x * rb_mask * rb_global_strength, rb_power);
        q = mix(q, q + wave.y * rb_mask * rb_global_strength, rb_power);
    }

    if (COL_BLEED > 0.0) {
        float bleed_step = ps.x * COL_BLEED;
        vec3 col_bleed_l = RGB_to_YIQ * texture2D(Texture, vTexCoord - vec2(bleed_step, 0.0)).rgb;
        vec3 col_bleed_r = RGB_to_YIQ * texture2D(Texture, vTexCoord + vec2(bleed_step, 0.0)).rgb;
        i = mix(i, (col_bleed_l.y + col_bleed_r.y) * 0.5, 0.5);
        q = mix(q, (col_bleed_l.z + col_bleed_r.z) * 0.5, 0.5);
    }

    vec3 final_rgb = YIQ_to_RGB * vec3(final_y, i * SATURATION, q * SATURATION);
    
    gl_FragColor = vec4(clamp(final_rgb, 0.0, 1.0), 1.0);
}
#endif