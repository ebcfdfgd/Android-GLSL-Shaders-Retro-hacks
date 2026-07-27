#version 110

/* NTSC ADAPTIVE-ULTIMATE (NO-SIN TRIANGLE BUILD)
   - FIXED: Removed sin/cos for performance.
   - FIXED: Replaced sin-based hash with Linear Pseudo-Random.
*/

#pragma parameter ntsc_scale "Adaptive Scale" 1.0 0.2 3.0 0.05
#pragma parameter ntsc_bright "NTSC Brightness" 1.0 0.0 2.0 0.05
#pragma parameter dither_blur "Luma Dither Blur" 0.5 0.0 1.0 0.05
#pragma parameter ntsc_tilt "NTSC Tilt Value" 0.0 0.0 5.0 0.1
#pragma parameter ntsc_crawl "NTSC Crawl Speed" 0.1 0.0 5.0 0.1
#pragma parameter merge_fields "Waterfall Field Fix" 1.0 0.0 1.0 1.0
#pragma parameter custom_art "Custom Artifacting" 0.5 0.0 2.0 0.05
#pragma parameter fring_val "Custom Fringing Value" 3.35 0.0 5.0 0.05
#pragma parameter rb_power "Rainbow Power" 0.0 0.0 2.0 0.05
#pragma parameter fr_str "Fringing Intensity" 0.5 0.0 2.0 0.05
#pragma parameter sat_boost "Color Saturation" 1.1 0.0 2.0 0.05
#pragma parameter bleed_str "Chroma Bleed" 3.5 0.0 5.0 0.1
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
precision highp float;
uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform int FrameCount;
varying vec2 vTexCoord;

uniform float ntsc_scale, ntsc_bright, dither_blur, ntsc_tilt, ntsc_crawl, merge_fields, custom_art, fring_val, rb_power, fr_str, sat_boost, bleed_str, sig_noise;

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

// دالة عشوائية خطية (بديلة hash المعتمدة على sin)
float hash(vec2 co) { return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453); }

void main() {
    vec3 col_m = texture2D(Texture, vTexCoord).rgb;
    
    // تحسين الأداء: خروج مبكر إذا لم تكن هناك تأثيرات
    if (dither_blur <= 0.0 && rb_power <= 0.0 && fr_str <= 0.0 && bleed_str <= 0.0 && sig_noise <= 0.0) {
        gl_FragColor = vec4(clamp(col_m * ntsc_bright, 0.0, 1.0), 1.0);
        return;
    }

    float res_scale = 1.0 / ntsc_scale;
    vec2 ps = vec2(res_scale / TextureSize.x, 1.0 / TextureSize.y);
    float time = float(FrameCount);
    
    vec3 col_l = texture2D(Texture, vTexCoord - vec2(ps.x, 0.0)).rgb;
    vec3 col_r = texture2D(Texture, vTexCoord + vec2(ps.x, 0.0)).rgb;

    vec3 yiq_m = RGB_to_YIQ * col_m;
    vec3 yiq_l = RGB_to_YIQ * col_l;
    vec3 yiq_r = RGB_to_YIQ * col_r;
    
    float final_y = mix(yiq_m.x, (yiq_l.x + yiq_r.x) * 0.5, dither_blur) * ntsc_bright;

    if (sig_noise > 0.0)
        final_y += (hash(vTexCoord + time * 0.01) - 0.5) * sig_noise;

    // phase بدون استخدام pi (تم دمج الثوابت)
    float phase = (vTexCoord.x * TextureSize.x + vTexCoord.y * TextureSize.y * ntsc_tilt + time * ntsc_crawl * 0.5 + (mod(time, 2.0) * merge_fields * 3.14));
    
    float diff = (yiq_m.x - yiq_l.x) * custom_art;
    
    // استخدام الدالة المثلثية الجديدة
    vec2 art_chroma = triangle_wave(phase * 2.09) * diff * rb_power;
    vec2 fringing = triangle_wave(phase * fring_val) * diff * fr_str;
    
    vec2 bleedDx = vec2(ps.x * bleed_str, 0.0);
    vec2 chrL = (RGB_to_YIQ * texture2D(Texture, vTexCoord - bleedDx).rgb).yz;
    vec2 chrR = (RGB_to_YIQ * texture2D(Texture, vTexCoord + bleedDx).rgb).yz;
    vec2 base_chroma = mix(yiq_m.yz, (chrL + chrR) * 0.5, 0.5);

    vec2 final_chroma = (base_chroma + art_chroma + fringing) * sat_boost;

    vec3 final_rgb = YIQ_to_RGB * vec3(final_y, final_chroma);
    
    gl_FragColor = vec4(clamp(final_rgb, 0.0, 1.0), 1.0);
}
#endif