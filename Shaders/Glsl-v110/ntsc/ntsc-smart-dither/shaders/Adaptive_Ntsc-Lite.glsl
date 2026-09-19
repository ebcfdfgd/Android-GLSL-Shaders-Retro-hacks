#version 110

/* NTSC ADAPTIVE-ULTIMATE - TRIANGLE-WAVE BUILD (NO-SIN) */

#pragma parameter ntsc_scale "Adaptive Scale" 1.0 0.2 3.0 0.05
#pragma parameter ntsc_bright "NTSC Brightness" 1.0 0.0 2.0 0.05
#pragma parameter ntsc_blur "NTSC Dither Blur" 0.7 0.0 1.0 0.05
#pragma parameter ntsc_tilt "NTSC Tilt Value" 0.0 0.0 5.0 0.1
#pragma parameter ntsc_crawl "NTSC Crawl Speed" 0.0 0.0 5.0 0.1
#pragma parameter merge_fields "Waterfall Field Fix" 1.0 0.0 1.0 1.0
#pragma parameter custom_art "Custom Artifacting" 0.5 0.0 2.0 0.05
#pragma parameter fring_val "Custom Fringing Value" 3.35 0.0 5.0 0.05
#pragma parameter rb_power "Rainbow Power" 0.0 0.0 2.0 0.05
#pragma parameter fr_str "Fringing Intensity" 0.5 0.0 2.0 0.05
#pragma parameter sat_boost "Color Saturation" 1.1 0.0 2.0 0.05
#pragma parameter bleed_str "Chroma Bleed" 3.5 0.0 5.0 0.1
#pragma parameter sig_noise "Signal RF Grain" 0.05 0.0 0.5 0.01

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

uniform float ntsc_scale, ntsc_bright, ntsc_blur, ntsc_tilt, ntsc_crawl, merge_fields, custom_art, fring_val, rb_power, fr_str, sat_boost, bleed_str, sig_noise;

const mat3 RGBtoYIQ = mat3(
    0.299,  0.596,  0.211,
    0.587, -0.274, -0.523,
    0.114, -0.322,  0.312
);

const mat3 YIQtoRGB = mat3(
    1.0,    1.0,    1.0,
    0.956, -0.272, -1.106,
    0.621, -0.647,  1.703
);

// دالة الموجة المثلثية السريعة (بديلة sin/cos)
vec2 triangle_wave(float x) {
    vec2 val = abs(fract(vec2(x * 0.159, x * 0.159 + 0.25)) * 2.0 - 1.0) * 2.0 - 1.0;
    return val;
}

// دالة ضجيج خطي سريع (بديلة لـ hash المعتمدة على sin)
float hash(vec2 co) { return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453); }

void main() {
    vec3 col_m = texture2D(Texture, vTexCoord).rgb;
    
    // Smart Bypass
    if (ntsc_blur <= 0.0 && rb_power <= 0.0 && fr_str <= 0.0 && bleed_str <= 0.0 && sig_noise <= 0.0) {
        vec3 yiq = RGBtoYIQ * col_m;
        gl_FragColor = vec4(clamp((YIQtoRGB * vec3(yiq.x * ntsc_bright, yiq.yz * sat_boost)), 0.0, 1.0), 1.0);
        return; 
    }

    float res_scale = 1.0 / ntsc_scale;
    vec2 ps = vec2(res_scale / TextureSize.x, 1.0 / TextureSize.y);
    float time = float(FrameCount);
    
    vec3 col_l = texture2D(Texture, vTexCoord - vec2(ps.x, 0.0)).rgb;
    vec3 col_r = texture2D(Texture, vTexCoord + vec2(ps.x, 0.0)).rgb;

    vec3 yiq_m = RGBtoYIQ * col_m;
    vec3 yiq_l = RGBtoYIQ * col_l;
    vec3 yiq_r = RGBtoYIQ * col_r;

    float is_dither = abs(yiq_m.x - yiq_l.x) * abs(yiq_m.x - yiq_r.x);
    float dither_mask = clamp(is_dither * 50.0, 0.0, 1.0) * clamp(1.0 - abs(yiq_l.x - yiq_r.x) * 5.0, 0.0, 1.0);

    vec3 col = mix(col_m, (col_l + col_m + col_r) * 0.3333, ntsc_blur * dither_mask);
    vec3 yiq_final = RGBtoYIQ * col;
    float final_y = yiq_final.x * ntsc_bright;

    if (sig_noise > 0.0)
        final_y += (hash(vTexCoord + time * 0.01) - 0.5) * sig_noise;

    float phase = (vTexCoord.x * TextureSize.x) + (vTexCoord.y * TextureSize.y * ntsc_tilt) + (time * ntsc_crawl * 0.5) + (mod(time, 2.0) * merge_fields * 3.14);
    float diff = (yiq_m.x - yiq_l.x) * custom_art;
    
    vec2 wave = triangle_wave(phase * 2.09);
    vec2 wave_f = triangle_wave(phase * fring_val);
    
    vec2 rainbow = wave * diff * rb_power * dither_mask;
    vec2 fringing = wave_f * diff * fr_str;
    
    vec2 b_off = vec2(ps.x * bleed_str, 0.0);
    vec2 chrL = (RGBtoYIQ * texture2D(Texture, vTexCoord - b_off).rgb).yz;
    vec2 chrR = (RGBtoYIQ * texture2D(Texture, vTexCoord + b_off).rgb).yz;
    
    vec2 final_chroma = (mix(yiq_m.yz, (chrL + chrR) * 0.5, 0.5) + rainbow + fringing) * sat_boost;
    gl_FragColor = vec4(clamp(YIQtoRGB * vec3(final_y, final_chroma), 0.0, 1.0), 1.0);
}
#endif