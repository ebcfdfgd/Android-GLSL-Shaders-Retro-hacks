// --- NTSC ADAPTIVE-ULTIMATE (113 Logic + Smart Dither Blur) ---
// Optimization: Smart Bypass on Zero Parameters + Pattern Recognition

#version 110

#pragma parameter ntsc_scale "Adaptive Scale" 1.0 0.2 3.0 0.05
#pragma parameter ntsc_hue "NTSC Hue Shift" 0.0 -3.14 3.14 0.05
#pragma parameter ntsc_bright "NTSC Brightness" 1.0 0.0 2.0 0.05
#pragma parameter ntsc_blur "NTSC Dither Blur" 0.3 0.0 1.0 0.05
#pragma parameter red_persistence "Red Persistence (Right Smear)" 1.0 0.0 2.5 0.05
#pragma parameter ntsc_tilt "NTSC Tilt Value" 0.0 0.0 5.0 0.1
#pragma parameter ntsc_crawl "NTSC Crawl Speed" 0.0 0.0 5.0 0.1
#pragma parameter merge_fields "Waterfall Field Fix" 1.0 0.0 1.0 1.0
#pragma parameter custom_art "Custom Artifacting" 1.0 0.0 2.0 0.05
#pragma parameter fring_val "Custom Fringing Value" 0.5 0.0 2.0 0.05
#pragma parameter rb_power "Rainbow Power" 0.0 0.0 2.0 0.05
#pragma parameter fr_str "Fringing Intensity" 0.7 0.0 2.0 0.05
#pragma parameter sat_boost "Color Saturation" 1.2 0.0 2.0 0.05
#pragma parameter bleed_str "Chroma Bleed" 2.5 0.0 5.0 0.1

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
uniform float ntsc_scale, ntsc_hue, ntsc_bright, ntsc_blur, red_persistence, ntsc_tilt, ntsc_crawl, merge_fields, custom_art, fring_val, rb_power, fr_str, sat_boost, bleed_str;
#else
#define ntsc_bright 1.0
#define sat_boost 1.2
#endif

mat3 RGBtoYIQ = mat3(0.2989, 0.5870, 0.1140, 0.5959, -0.2744, -0.3216, 0.2115, -0.5229, 0.3114);
mat3 YIQtoRGB = mat3(1.0, 0.956, 0.6210, 1.0, -0.2720, -0.6474, 1.0, -1.1060, 1.7046);

void main() {
    // 1. FETCH المبدئي
    vec3 col_m = texture2D(Texture, vTexCoord).rgb;

    // --- نظام الإيقاف الذكي (BYPASS) ---
    if (ntsc_blur <= 0.0 && rb_power <= 0.0 && fr_str <= 0.0 && bleed_str <= 0.0 && red_persistence <= 0.0) {
        float luma_m = dot(col_m, vec3(0.2989, 0.5870, 0.1140)) * ntsc_bright;
        vec3 final_rgb = mix(vec3(luma_m), col_m * ntsc_bright, sat_boost);
        gl_FragColor = vec4(clamp(final_rgb, 0.0, 1.0), 1.0);
        return; 
    }

    float res_scale = 1.0 / ntsc_scale;
    vec2 ps = vec2(res_scale / TextureSize.x, 1.0 / TextureSize.y);
    float time = float(FrameCount);
    
    // 2. FETCHES الإضافية
    vec3 col_l = texture2D(Texture, vTexCoord - vec2(ps.x, 0.0)).rgb;
    vec3 col_r = texture2D(Texture, vTexCoord + vec2(ps.x, 0.0)).rgb;

    // 3. SMART DITHER DETECTION (Logic 113)
    float y_m = dot(col_m, vec3(0.2989, 0.5870, 0.1140));
    float y_l = dot(col_l, vec3(0.2989, 0.5870, 0.1140));
    float y_r = dot(col_r, vec3(0.2989, 0.5870, 0.1140));

    float is_dither = abs(y_m - y_l) * abs(y_m - y_r);
    float dither_mask = clamp(is_dither * 50.0, 0.0, 1.0);
    dither_mask *= clamp(1.0 - abs(y_l - y_r) * 5.0, 0.0, 1.0);

    // تطبيق الـ Blur فقط في مناطق الديزر
    vec3 col = col_m;
    if (ntsc_blur > 0.0) {
        vec3 avg = (col_l + col_m + col_r) * 0.3333;
        col = mix(col_m, avg, ntsc_blur * dither_mask);
    }
    
    float final_y = dot(col, vec3(0.2989, 0.5870, 0.1140)) * ntsc_bright;

    // 4. PHASE LOGIC
    float x_pix = vTexCoord.x * TextureSize.x;
    float y_pix = vTexCoord.y * TextureSize.y;
    float field = mod(time, 2.0) * merge_fields * 3.14159;
    float phase = (x_pix + y_pix * ntsc_tilt + time * ntsc_crawl * 0.5 + field);
    float angle = (phase * 2.094395);

    // 5. THE ENGINE (Artifacting)
    float diff = (y_m - y_l) * custom_art;
    float h_c = cos(ntsc_hue); float h_s = sin(ntsc_hue);
    mat2 hue_rot = mat2(h_c, -h_s, h_s, h_c);
    
    // ربط الرينبو بقناع الديثير لواقعية أعلى
    vec2 rainbow = vec2(sin(angle), cos(angle + 1.57)) * diff * rb_power * dither_mask;
    vec2 fringing = vec2(sin(phase * fring_val), cos(phase * fring_val)) * diff * fr_str;
    vec2 art_chroma = (rainbow + fringing) * hue_rot;

    // 6. CHROMA BLEED & RED PERSISTENCE
    float b_off = ps.x * bleed_str;
    vec2 chrL = (texture2D(Texture, vTexCoord - vec2(b_off, 0.0)).rgb * RGBtoYIQ).gb;
    vec2 chrR = (texture2D(Texture, vTexCoord + vec2(b_off, 0.0)).rgb * RGBtoYIQ).gb;
    
    vec2 yiq_gb_m = (col.rgb * RGBtoYIQ).gb;
    vec2 base_chroma = mix(yiq_gb_m, (chrL + chrR) * 0.5, 0.5);

    if (red_persistence > 0.0) {
        float smear = mix(yiq_gb_m.x, chrL.x, 0.4 * red_persistence);
        base_chroma.x = mix(base_chroma.x, smear, 0.6);
    }

    vec2 final_chroma = (base_chroma * hue_rot + art_chroma) * sat_boost;

    // 7. OUTPUT
    vec3 final_rgb = vec3(final_y, final_chroma) * YIQtoRGB;
    gl_FragColor = vec4(clamp(final_rgb, 0.0, 1.0), 1.0);
}
#endif