#version 130

/* MEGA-HYBRID-ULTIMATE (V1.3 - FIXED HUE)
    - FIXED: Global Hue Rotation for full color control.
    - Integrated: 5-Tap Chroma Bleed sampling.
*/

#pragma parameter G_GAMMA "Fast Gamma Out" 2.2 1.0 3.5 0.05
#pragma parameter ntsc_res "NTSC Resolution" 0.0 -1.0 1.0 0.05
#pragma parameter ntsc_sharp "NTSC Sharpness" 0.1 -1.0 1.0 0.05
#pragma parameter fring "NTSC Fringing" 0.0 0.0 1.0 0.05
#pragma parameter afacts "NTSC Artifacts" 0.0 0.0 1.0 0.05
#pragma parameter ntsc_hue "NTSC Hue" 0.0 -3.14 3.14 0.05
#pragma parameter COL_BLEED "Chroma Bleed Strength" 1.5 0.0 5.0 0.05
#pragma parameter Conv_R "Conv: Red Shift" 0.35 -3.0 3.0 0.05
#pragma parameter Conv_B "Conv: Blue Shift" -0.25 -3.0 3.0 0.05
#pragma parameter rb_power "Rainbow Strength" 0.15 0.0 2.0 0.01
#pragma parameter rb_size "Rainbow Width" 3.0 0.5 10.0 0.1
#pragma parameter rb_detect "Rainbow Detection" 0.30 0.0 1.0 0.01
#pragma parameter rb_speed "Rainbow Speed" 0.5 0.0 2.0 0.05
#pragma parameter rb_tilt "Rainbow Tilt" 0.5 -2.0 2.0 0.1
#pragma parameter de_dither "MD De-Dither" 1.0 0.0 2.0 0.1
#pragma parameter ntsc_grain "Signal Grain" 0.01 0.0 0.20 0.01
#pragma parameter tv_mist "TV Mist" 0.1 0.0 1.5 0.05

#pragma parameter CLU_R_GAIN "Red Gain" 1.0 0.0 2.0 0.02
#pragma parameter CLU_G_GAIN "Green Gain" 1.0 0.0 2.0 0.02
#pragma parameter CLU_B_GAIN "Blue Gain" 1.0 0.0 2.0 0.02
#pragma parameter CLU_CONTRAST "Contrast" 1.10 0.5 2.0 0.05
#pragma parameter CLU_SATURATION "Saturation" 1.3 0.0 2.0 0.05
#pragma parameter CLU_BRIGHT "CRT Brightness" 1.1 1.0 2.0 0.05
#pragma parameter CLU_GLOW "Glow Strength" 0.15 0.0 1.5 0.05
#pragma parameter CLU_HALATION "Halation Strength" 0.15 0.0 1.0 0.02
#pragma parameter CLU_BLK_D "CRT Black Depth" 0.20 0.0 1.0 0.05

#pragma parameter BARREL_DISTORTION "Toshiba Curve" 0.12 0.0 0.5 0.01
#pragma parameter ZOOM "Zoom" 1.0 0.5 2.0 0.01
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.2 1.0 5.0 0.05
#pragma parameter v_amount "Soft Vignette" 0.25 0.0 2.5 0.01
#pragma parameter OverlayMix "L1 Intensity" 1.0 0.0 1.0 0.05
#pragma parameter LUTWidth "L1 Width" 6.0 1.0 1024.0 1.0
#pragma parameter LUTHeight "L1 Height" 4.0 1.0 1024.0 1.0
#pragma parameter OverlayMix2 "L2 Intensity" 0.0 0.0 1.0 0.05
#pragma parameter LUTWidth2 "L2 Width" 6.0 1.0 1024.0 1.0
#pragma parameter LUTHeight2 "L2 Height" 4.0 1.0 1024.0 1.0

#if defined(VERTEX)
in vec4 VertexCoord;
in vec4 TexCoord;
out vec2 vTexCoord;
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord.xy;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

uniform sampler2D Texture, overlay, overlay2;
uniform vec2 TextureSize, InputSize, OutputSize;
uniform int FrameCount;
in vec2 vTexCoord;

#ifdef PARAMETER_UNIFORM
uniform float G_GAMMA, ntsc_res, ntsc_sharp, fring, afacts, ntsc_hue, COL_BLEED, Conv_R, Conv_B, rb_power, rb_size, rb_detect, rb_speed, rb_tilt, de_dither, ntsc_grain, tv_mist;
uniform float CLU_R_GAIN, CLU_G_GAIN, CLU_B_GAIN, CLU_CONTRAST, CLU_SATURATION, CLU_BRIGHT, CLU_GLOW, CLU_HALATION, CLU_BLK_D;
uniform float BARREL_DISTORTION, ZOOM, BRIGHT_BOOST, v_amount, OverlayMix, LUTWidth, LUTHeight, OverlayMix2, LUTWidth2, LUTHeight2;
#endif

out vec4 FragColor;

float overlay_f(float a, float b) { return a < 0.5 ? (2.0 * a * b) : (1.0 - 2.0 * (1.0 - a) * (1.0 - b)); }
float noise_f(vec2 co) { return fract(sin(dot(co.xy, vec2(12.9898,78.233))) * 43758.5453); }

void main() {
    // 1. Geometry
    vec2 sc = TextureSize / InputSize;
    vec2 uv = (vTexCoord * sc) - 0.5;
    uv /= ZOOM;

    vec2 d_uv;
    d_uv.x = uv.x * (1.0 + (uv.y * uv.y) * BARREL_DISTORTION * 0.2);
    d_uv.y = uv.y * (1.0 + (uv.x * uv.x) * BARREL_DISTORTION * 0.9);
    d_uv *= (1.0 - 0.15 * BARREL_DISTORTION);

    if (abs(d_uv.x) > 0.5 || abs(d_uv.y) > 0.5) {
        FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }
    vec2 f_uv = (d_uv + 0.5) / sc;

    // 2. 5-Tap NTSC Engine
    float res_m = 1.0 - (ntsc_res * 0.5);
    vec2 ps = vec2(res_m / TextureSize.x, 1.0 / TextureSize.y);
    vec2 ps_chr = vec2(COL_BLEED / TextureSize.x, 0.0);
    
    vec3 col_m = texture(Texture, f_uv).rgb;
    vec3 col_l = texture(Texture, f_uv - vec2(ps.x * de_dither, 0.0)).rgb;
    vec3 col_r = texture(Texture, f_uv + vec2(ps.x * de_dither, 0.0)).rgb;
    
    vec3 col_chrL = texture(Texture, f_uv - ps_chr).rgb;
    vec3 col_chrR = texture(Texture, f_uv + ps_chr).rgb;

    mat3 RGBtoYIQ = mat3(0.2989, 0.5870, 0.1140, 0.5959, -0.2744, -0.3216, 0.2115, -0.5229, 0.3114);
    
    vec3 yiq_m = col_m * RGBtoYIQ;
    float lumL = dot(col_l, vec3(0.2989, 0.5870, 0.1140));
    float lumR = dot(col_r, vec3(0.2989, 0.5870, 0.1140));

    // Mixed Chroma
    vec2 chrL = (col_chrL * RGBtoYIQ).gb;
    vec2 chrR = (col_chrR * RGBtoYIQ).gb;
    vec2 mixed_chroma = mix(yiq_m.gb, (chrL + chrR) * 0.5, 0.6);

    // --- Global Hue Correction ---
    // هنا بيحصل الدوران الحقيقي للألوان
    float h_cos = cos(ntsc_hue);
    float h_sin = sin(ntsc_hue);
    vec2 rotated_chroma;
    rotated_chroma.x = mixed_chroma.x * h_cos - mixed_chroma.y * h_sin;
    rotated_chroma.y = mixed_chroma.x * h_sin + mixed_chroma.y * h_cos;
    mixed_chroma = rotated_chroma;

    float y = yiq_m.r;
    y += (y - (lumL + lumR) * 0.5) * ntsc_sharp;

    float t = float(FrameCount);
    float ang = (f_uv.x * TextureSize.x / rb_size) + (f_uv.y * TextureSize.y * rb_tilt) + (t * rb_speed);
    float rb_m = smoothstep(rb_detect, rb_detect + 0.2, abs(y - lumL) + abs(y - lumR));
    float rb_s = rb_power + (afacts * 0.5) + (fring * 0.5);
    
    float fI = mixed_chroma.x + sin(ang) * rb_s * rb_m;
    float fQ = mixed_chroma.y + cos(ang) * rb_s * rb_m;
    y = mix(y, (lumL + y + lumR) * 0.333, tv_mist);

    // Convergence Shift
    vec3 res;
    res.r = texture(Texture, f_uv - vec2(Conv_R / TextureSize.x, 0.0)).r;
    res.g = col_m.g;
    res.b = texture(Texture, f_uv - vec2(Conv_B / TextureSize.x, 0.0)).b;

    // Merge YIQ to RGB
    vec3 ntsc_c;
    ntsc_c.r = y + 0.956 * fI + 0.621 * fQ;
    ntsc_c.g = y - 0.272 * fI - 0.647 * fQ;
    ntsc_c.b = y - 1.106 * fI + 1.703 * fQ;
    
    res = mix(res, ntsc_c, 0.7) * BRIGHT_BOOST;
    res += (noise_f(f_uv + mod(t, 64.0)) - 0.5) * ntsc_grain;

    // 3. Color Grade
    res = max(res * res, 0.0); 
    res *= vec3(CLU_R_GAIN, CLU_G_GAIN, CLU_B_GAIN);
    res = (res - 0.5) * CLU_CONTRAST + 0.5;
    float l_f = dot(res, vec3(0.299, 0.587, 0.114)); 
    res = mix(vec3(l_f), res, CLU_SATURATION);
    res *= (1.0 - CLU_BLK_D * (1.0 - l_f));

    // 4. Glow
    vec3 glow_p = pow(max(res, 0.0), vec3(4.0));
    res += glow_p * (CLU_GLOW + glow_p * CLU_HALATION);
    res *= CLU_BRIGHT;

    // 5. Final Output & Overlays
    res *= clamp(1.0 - (d_uv.x * d_uv.x + d_uv.y * d_uv.y) * v_amount, 0.0, 1.0);
    
    vec2 mP = vTexCoord * TextureSize / InputSize;
    if (OverlayMix > 0.0) {
        vec3 l1 = texture(overlay, vec2(fract(mP.x * OutputSize.x / LUTWidth), fract(mP.y * OutputSize.y / LUTHeight))).rgb;
        res = mix(res, vec3(overlay_f(res.r, l1.r), overlay_f(res.g, l1.g), overlay_f(res.b, l1.b)), OverlayMix);
    }
    if (OverlayMix2 > 0.0) {
        vec3 l2 = texture(overlay2, vec2(fract(mP.x * OutputSize.x / LUTWidth2), fract(mP.y * OutputSize.y / LUTHeight2))).rgb;
        res *= mix(vec3(1.0), l2, OverlayMix2);
    }

    FragColor = vec4(pow(max(res, 0.0), vec3(1.0 / G_GAMMA)), 1.0);
}
#endif