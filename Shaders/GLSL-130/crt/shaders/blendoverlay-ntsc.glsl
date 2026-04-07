#version 130

/*
    MEGA-HYBRID-ULTIMATE (V1.1 - Pure 130 Build)
    - Updated to modern 'in/out' syntax.
    - Standardized for OpenGL 3.0 / GLSL 1.30.
*/

#pragma parameter ntsc_res "NTSC Resolution" 0.0 -1.0 1.0 0.05
#pragma parameter ntsc_sharp "NTSC Sharpness" 0.1 -1.0 1.0 0.05
#pragma parameter fring "NTSC Fringing" 0.0 0.0 1.0 0.05
#pragma parameter afacts "NTSC Artifacts" 0.0 0.0 1.0 0.05
#pragma parameter ntsc_hue "NTSC Hue" 0.0 -3.14 3.14 0.05
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
uniform float ntsc_res, ntsc_sharp, fring, afacts, ntsc_hue, rb_power, rb_size, rb_detect, rb_speed, rb_tilt, de_dither, ntsc_grain, tv_mist;
uniform float CLU_R_GAIN, CLU_G_GAIN, CLU_B_GAIN, CLU_CONTRAST, CLU_SATURATION, CLU_BRIGHT, CLU_GLOW, CLU_HALATION, CLU_BLK_D;
uniform float BARREL_DISTORTION, ZOOM, BRIGHT_BOOST, v_amount, OverlayMix, LUTWidth, LUTHeight, OverlayMix2, LUTWidth2, LUTHeight2;
#endif

// مخرج الألوان الإلزامي في نسخة 130
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

    // 2. NTSC Processing
    float res_m = 1.0 - (ntsc_res * 0.5);
    vec2 ps = vec2(res_m / TextureSize.x, 1.0 / TextureSize.y);
    
    // استخدام texture() بدلاً من texture2D()
    vec3 col_m = texture(Texture, f_uv).rgb * BRIGHT_BOOST;
    vec3 col_l = texture(Texture, f_uv - vec2(ps.x * de_dither, 0.0)).rgb * BRIGHT_BOOST;
    vec3 col_r = texture(Texture, f_uv + vec2(ps.x * de_dither, 0.0)).rgb * BRIGHT_BOOST;
    
    vec3 color = mix(col_m, (col_l + col_r) * 0.5, 0.4);
    
    float y = dot(color, vec3(0.299, 0.587, 0.114));
    float i = dot(color, vec3(0.596, -0.274, -0.322));
    float q = dot(color, vec3(0.211, -0.523, 0.312));
    
    float lumL = dot(col_l, vec3(0.299, 0.587, 0.114));
    float lumR = dot(col_r, vec3(0.299, 0.587, 0.114));
    y += (y - (lumL + lumR) * 0.5) * ntsc_sharp;

    float t = float(FrameCount);
    float ang = (f_uv.x * TextureSize.x / rb_size) + (f_uv.y * TextureSize.y * rb_tilt) + (t * rb_speed) + ntsc_hue;
    float rb_m = smoothstep(rb_detect, rb_detect + 0.2, abs(y - lumL) + abs(y - lumR));
    float rb_s = rb_power + (afacts * 0.5) + (fring * 0.5);
    
    i += sin(ang) * rb_s * rb_m;
    q += cos(ang) * rb_s * rb_m;
    y = mix(y, (lumL + y + lumR) * 0.333, tv_mist);

    vec3 res;
    res.r = y + 0.956 * i + 0.621 * q;
    res.g = y - 0.272 * i - 0.647 * q;
    res.b = y - 1.106 * i + 1.703 * q;
    res += (noise_f(f_uv + mod(t, 64.0)) - 0.5) * ntsc_grain;

    // 3. Color Grade
    res = max(res * res, 0.0);
    res *= vec3(CLU_R_GAIN, CLU_G_GAIN, CLU_B_GAIN);
    res = (res - 0.5) * CLU_CONTRAST + 0.5;
    float l_f = dot(res, vec3(0.25, 0.5, 0.25)); 
    res = mix(vec3(l_f), res, CLU_SATURATION);
    res *= (1.0 - CLU_BLK_D * (1.0 - l_f));

    // 4. Glow
    vec3 glow_p = pow(max(res, 0.0), vec3(4.0));
    res += glow_p * (CLU_GLOW + glow_p * CLU_HALATION);
    res *= CLU_BRIGHT;

    // 5. Final Output
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

    FragColor = vec4(sqrt(max(res, 0.0)), 1.0);
}
#endif