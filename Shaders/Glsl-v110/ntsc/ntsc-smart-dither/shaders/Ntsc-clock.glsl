#version 110

// --- [ RetroArch Parameters ] ---
#pragma parameter NTSC_BRIGHT "NTSC Brightness" 1.0 1.0 2.0 0.05
#pragma parameter CC_FREQ "NTSC Color Clock" 3.5979 0.0 10.0 0.1
#pragma parameter NTSC_TILT "NTSC Rainbow Tilt" 0.0 0.0 2.0 0.05
#pragma parameter JITTER_STR "NTSC Rotation Speed" 0.0 0.0 2.0 0.05
#pragma parameter ARTF_STR "NTSC Artifacting" 0.45 0.0 2.0 0.05
#pragma parameter RAINBOW_STR "NTSC Rainbow" 0.3 0.0 1.0 0.05
#pragma parameter CHROMA_BLEED "NTSC Chroma Bleed" 1.6 0.0 5.0 0.1
#pragma parameter red_persistence "Red Persistence (Right Smear)" 1.0 0.0 2.5 0.05
#pragma parameter SHARPNESS "NTSC Sharpness" 0.2 -1.0 1.0 0.05
#pragma parameter SATURATION "NTSC Saturation" 1.0 0.0 2.0 0.05

#if defined(VERTEX)
uniform mat4 MVPMatrix;
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 vTexCoord;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision mediump float;
#endif

varying vec2 vTexCoord;
uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform int FrameCount;

#ifdef PARAMETER_UNIFORM
uniform float NTSC_BRIGHT, CC_FREQ, NTSC_TILT, JITTER_STR, ARTF_STR, RAINBOW_STR, CHROMA_BLEED, red_persistence, SHARPNESS, SATURATION;
#else
#define NTSC_BRIGHT 1.0
#define CC_FREQ 3.5979
#define NTSC_TILT 0.0
#define JITTER_STR 0.0
#define ARTF_STR 0.45
#define RAINBOW_STR 0.3
#define CHROMA_BLEED 1.6
#define red_persistence 1.0
#define SHARPNESS 0.2
#define SATURATION 1.0
#endif

void main() {
    vec2 pos = vTexCoord;
    
    // [1] سحب العينة المركزية أولاً
    vec3 col_center = texture2D(Texture, pos).rgb;

    // --- شرط الإيقاف الذكي (Bypass) ---
    if (ARTF_STR <= 0.0 && RAINBOW_STR <= 0.0 && CHROMA_BLEED <= 0.0 && red_persistence <= 0.0 && SHARPNESS <= 0.0) {
        float luma_raw = dot(col_center * NTSC_BRIGHT, vec3(0.299, 0.587, 0.114));
        vec3 final_rgb = mix(vec3(luma_raw), col_center * NTSC_BRIGHT, SATURATION);
        gl_FragColor = vec4(clamp(final_rgb, 0.0, 1.0), 1.0);
        return; 
    }

    vec2 pix = pos * TextureSize;
    vec2 texel = vec2(1.0 / TextureSize.x, 0.0);

    // --- 2. المرحلة (Phase) ---
    float rotation = mod(float(FrameCount) * JITTER_STR, 6.28318);
    float phase = (pix.x * CC_FREQ + pix.y * NTSC_TILT) + rotation; 
    
    float sub_i = cos(phase);
    float sub_q = sin(phase);

    // 3. سحب عينات الجوار
    vec3 col_left   = texture2D(Texture, pos - texel).rgb;
    vec3 col_right  = texture2D(Texture, pos + texel).rgb;
    
    // 4. Sharpness & Luma
    vec3 sharp_col = col_center + (col_center - (col_left + col_right) * 0.5) * SHARPNESS;
    
    float y = dot(sharp_col, vec3(0.2989, 0.5870, 0.1140));
    float i = dot(sharp_col, vec3(0.5959, -0.2744, -0.3216));
    float q = dot(sharp_col, vec3(0.2115, -0.5229, 0.3114));

    // 5. Artifacting (Fringing & Rainbow)
    float luma_diff = dot(col_center - col_left, vec3(0.299, 0.587, 0.114));
    
    i += luma_diff * sub_i * ARTF_STR;
    q += luma_diff * sub_q * ARTF_STR;
    
    float rainbow = cos(phase) * luma_diff * RAINBOW_STR;
    i += rainbow;
    q -= rainbow; 

    // 6. Chroma Bleeding & Red Persistence (Logic 1010)
    vec2 bleed_off = texel * CHROMA_BLEED;
    vec3 bleed_l = texture2D(Texture, pos - bleed_off).rgb;
    vec3 bleed_r = texture2D(Texture, pos + bleed_off).rgb;
    
    float i_l = dot(bleed_l, vec3(0.5959, -0.2744, -0.3216));
    float i_r = dot(bleed_r, vec3(0.5959, -0.2744, -0.3216));
    
    float i_bleed = (i_l + i_r) * 0.5;
    float q_bleed = (dot(bleed_l, vec3(0.2115, -0.5229, 0.3114)) + dot(bleed_r, vec3(0.2115, -0.5229, 0.3114))) * 0.5;
    
    i = mix(i, i_bleed, 0.75);
    q = mix(q, q_bleed, 0.75);

    // إضافة سيلان الأحمر: سحب قيمة I من اليسار ودمجها في البكسل الحالي لعمل Smear جهة اليمين
    if (red_persistence > 0.0) {
        float smear = mix(i, i_l, 0.4 * red_persistence);
        i = mix(i, smear, 0.6);
    }

    // 7. YIQ to RGB
    vec3 rgb;
    rgb.r = y + 0.956 * i + 0.621 * q;
    rgb.g = y - 0.272 * i - 0.647 * q;
    rgb.b = y - 1.106 * i + 1.703 * q;
    
    // 8. Post-Processing
    rgb *= NTSC_BRIGHT;
    float luma_final = dot(rgb, vec3(0.299, 0.587, 0.114));
    rgb = mix(vec3(luma_final), rgb, SATURATION);

    gl_FragColor = vec4(clamp(rgb, 0.0, 1.0), 1.0);
}
#endif