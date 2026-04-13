// --- NTSC MEGA LITE + CHROMA (SENSITIVITY & WATERFALL FIX) ---
// Optimized for Android - Artifact Sensitivity & 0121 Waterfall Logic + Red Persistence

#version 110

#pragma parameter ntsc_res "NTSC: Resolution" 0.0 -1.0 1.0 0.05
#pragma parameter ntsc_sharp "NTSC: Sharpness Boost" 0.1 -1.0 1.0 0.05
#pragma parameter fring "NTSC: Edge Fringing" 0.0 0.0 1.0 0.05
#pragma parameter afacts "NTSC: Artifact Intensity" 0.0 0.0 1.0 0.05
#pragma parameter Artifact_Sensitivity "Rainbow Sensitivity (Auto=1.0)" 0.2 0.0 5.0 0.1
#pragma parameter ntsc_hue "NTSC Color Hue (Cyan Fix)" 0.0 -3.14 3.14 0.05
#pragma parameter COL_BLEED "Chroma Bleed Strength" 1.5 0.0 5.0 0.05
#pragma parameter red_persistence "Red persistence (Right only)" 1.3 0.0 5.0 0.05
#pragma parameter rb_power "Rainbow Strength" 0.10 0.0 2.0 0.01
#pragma parameter rb_size "Rainbow Width" 5.0 0.5 10.0 0.1
#pragma parameter rb_speed "Rainbow Crawl Speed (0=OFF)" 0.05 0.0 2.0 0.05
#pragma parameter rb_tilt "Rainbow Diagonal Tilt" 0.0 -2.0 2.0 0.05
#pragma parameter de_dither "MD De-Dither Intensity" 1.0 0.0 2.0 0.1
#pragma parameter ntsc_grain "Signal Grain (RF Noise)" 0.0 0.0 0.20 0.01
#pragma parameter tv_mist "TV Signal Mist (Blur)" 0.0 0.0 1.5 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 vTexCoord;
varying vec2 hue_trig; 
uniform mat4 MVPMatrix;

#ifdef PARAMETER_UNIFORM
uniform float ntsc_hue;
#endif

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
uniform float ntsc_res, ntsc_sharp, fring, afacts, Artifact_Sensitivity;
uniform float ntsc_hue, COL_BLEED, red_persistence, rb_power, rb_size, rb_speed, rb_tilt, de_dither, ntsc_grain, tv_mist;
#endif

float noise(vec2 co) {
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

mat3 RGBtoYIQ = mat3(0.2989, 0.5870, 0.1140, 0.5959, -0.2744, -0.3216, 0.2115, -0.5229, 0.3114);
mat3 YIQtoRGB = mat3(1.0, 0.956, 0.6210, 1.0, -0.2720, -0.6474, 1.0, -1.1060, 1.7046);

void main() {
    float res_step = 1.0 - (ntsc_res * 0.5);
    vec2 ps = vec2(res_step / TextureSize.x, 1.0 / TextureSize.y);
    float time = float(FrameCount);
    
    // --- 1. SMART FETCHES & DE-DITHER ---
    vec3 col_m = texture2D(Texture, vTexCoord).rgb;
    vec3 col_l = texture2D(Texture, vTexCoord - vec2(ps.x, 0.0)).rgb;
    vec3 col_r = texture2D(Texture, vTexCoord + vec2(ps.x, 0.0)).rgb;

    // معالجة الديزر (De-Dither)
    vec3 col = (de_dither > 0.0) ? mix(col_m, (col_l + col_r) * 0.5, 0.4 * de_dither) : col_m;
    vec3 yiq = col * RGBtoYIQ;
    
    float yM = (col_m * RGBtoYIQ).r;
    float yL = (col_l * RGBtoYIQ).r;
    float yR = (col_r * RGBtoYIQ).r;

    // --- 2. CHROMA BLEED & RED PERSISTENCE ---
    vec2 mixed_chroma = yiq.gb;
    
    // سحب عينات إضافية للكروما لضمان نعومة النزيف
    float bleed_offset = ps.x * (COL_BLEED + 0.001) * 2.0;
    vec2 chrL = (texture2D(Texture, vTexCoord - vec2(bleed_offset, 0.0)).rgb * RGBtoYIQ).gb;
    vec2 chrR = (texture2D(Texture, vTexCoord + vec2(bleed_offset, 0.0)).rgb * RGBtoYIQ).gb;

    // النزيف العام (Symmetrical Bleed)
    if (COL_BLEED > 0.0) {
        mixed_chroma = mix(yiq.gb, (chrL + chrR) * 0.5, 0.5);
    }

    // سيلان الأحمر جهة اليمين (Logic 1010)
    if (red_persistence > 0.0) {
        // سحب التردد I من البكسل الأيسر لإنتاج سحب اتجاهي لليمين
        float smear = mix(mixed_chroma.x, chrL.x, 0.5 * red_persistence);
        mixed_chroma.x = smear;
    }

    // --- 3. RAINBOW WITH AUTO-SENSITIVITY (0121 LOGIC) ---
    float rainbowI = 0.0;
    float rainbowQ = 0.0;
    if (rb_power > 0.0) {
        // حساب الفرق التفاضلي للكشف عن أنماط الديزر (مثل شلالات سونيك)
        float diff = abs(yL + yR - 2.0 * yM);
        float mask = clamp(diff * Artifact_Sensitivity * 4.0, 0.0, 1.0);
        
        float angle = (vTexCoord.x * TextureSize.x / rb_size) + (vTexCoord.y * TextureSize.y * rb_tilt) + (time * rb_speed); 
        float total_rb = rb_power + (afacts * 0.5);
        
        rainbowI = sin(angle) * total_rb * mask;
        rainbowQ = cos(angle) * total_rb * mask;
    }

    // --- 4. LUMA & SHARPNESS ---
    float y = yiq.r;
    if (ntsc_sharp > 0.0) y += (yiq.r - yL) * (ntsc_sharp * 0.6);
    
    float final_y = (tv_mist > 0.0) ? mix(y, (yL + y + yR) * 0.333, tv_mist) : y;
    
    if (ntsc_grain > 0.0) {
        final_y += (noise(vTexCoord + mod(time, 60.0)) - 0.5) * ntsc_grain;
    }

    // --- 5. FRINGING & ASSEMBLY ---
    float fI = mixed_chroma.x + rainbowI;
    float fQ = mixed_chroma.y + rainbowQ;
    
    // تأثير تداخل الحواف (Fringing)
    if (fring > 0.0) {
        fI += (yM - yR) * fring * 0.3;
        fQ -= (yM - yL) * fring * 0.3;
    }
    
    // تطبيق تدوير اللون (Hue)
    float hueI = fI * hue_trig.x - fQ * hue_trig.y;
    float hueQ = fI * hue_trig.y + fQ * hue_trig.x;

    vec3 final_rgb = vec3(final_y, hueI, hueQ) * YIQtoRGB;

    gl_FragColor = vec4(clamp(final_rgb, 0.0, 1.0), 1.0);
}
#endif