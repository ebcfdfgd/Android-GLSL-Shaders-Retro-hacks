#version 110
precision mediump float;

uniform mat4 MVPMatrix;
uniform sampler2D Texture;
uniform vec2 TextureSize; 

// Parameters
#pragma parameter DITHER_THRESHOLD "Dither Sensitivity" 0.15 0.05 0.5 0.01
#pragma parameter DITHER_BLUR "Dither Blur (Transparency)" 0.5 0.0 1.0 0.05
#pragma parameter RAINBOW_FREQ "Rainbow Frequency" 8.0 1.0 20.0 0.5
#pragma parameter RAINBOW_TILT "Rainbow Tilt" 0.5 0.0 2.0 0.05
#pragma parameter RAINBOW_POWER "Rainbow Strength" 0.12 0.0 1.0 0.01
#pragma parameter CHROMA_BLEED "Chroma Bleed Width" 1.5 0.0 5.0 0.1
#pragma parameter MD_JAILBARS "Mega Drive Jailbars" 0.2 0.0 1.0 0.01
#pragma parameter JAIL_WIDTH "Jailbar Spacing" 1.5 0.5 10.0 0.1
#pragma parameter STATIC_NOISE "Static Noise Intensity" 0.02 0.0 0.2 0.01

uniform float DITHER_THRESHOLD;
uniform float DITHER_BLUR;
uniform float RAINBOW_FREQ;
uniform float RAINBOW_TILT;
uniform float RAINBOW_POWER;
uniform float CHROMA_BLEED;
uniform float MD_JAILBARS;
uniform float JAIL_WIDTH;
uniform float STATIC_NOISE;

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv;
void main() {
    gl_Position = MVPMatrix * VertexCoord;
    uv = TexCoord;
}
#elif defined(FRAGMENT)
varying vec2 uv;

vec3 rgb2yiq(vec3 c) {
    return vec3(0.299*c.r + 0.587*c.g + 0.114*c.b, 0.596*c.r - 0.274*c.g - 0.322*c.b, 0.211*c.r - 0.523*c.g + 0.312*c.b);
}

vec3 yiq2rgb(vec3 c) {
    return vec3(c.x + 0.956*c.y + 0.621*c.z, c.x - 0.272*c.y - 0.647*c.z, c.x - 1.106*c.y + 1.703*c.z);
}

float rand(vec2 co) { return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453); }

void main() {
    vec2 dx = vec2(1.0 / TextureSize.x, 0.0);
    
    // 1. Sampling Tight (للحواف والديزر)
    vec3 c_rgb = texture2D(Texture, uv).rgb;
    vec3 l1 = texture2D(Texture, uv - dx).rgb;
    vec3 r1 = texture2D(Texture, uv + dx).rgb;

    vec3 c_yiq = rgb2yiq(c_rgb);
    vec3 l_yiq = rgb2yiq(l1);
    vec3 r_yiq = rgb2yiq(r1);

    // 2. Smart Dither Detection
    float y_m = c_yiq.x;
    float y_l = l_yiq.x;
    float y_r = r_yiq.x;
    float is_dither = abs(y_m - y_l) * abs(y_m - y_r);
    float dither_mask = clamp(is_dither * (1.0 / (DITHER_THRESHOLD + 0.001)), 0.0, 1.0);
    dither_mask *= clamp(1.0 - abs(y_l - y_r) * 10.0, 0.0, 1.0);

    // 3. Smart Dither Blur
    float luma_avg = (l_yiq.x + r_yiq.x) * 0.5;
    c_yiq.x = mix(c_yiq.x, luma_avg, dither_mask * DITHER_BLUR);

    // 4. Improved MD Jailbars
    float jailbar = sin(uv.x * TextureSize.x * (3.14159 / JAIL_WIDTH));
    c_yiq.x += (jailbar * 0.02 * MD_JAILBARS);

    // 5. Chroma Bleeding (مط الألوان بعيداً عن المركز)
    // نستخدم CHROMA_BLEED لتحديد مدى السيلان (Stretch)
    vec3 l_wide = texture2D(Texture, uv - dx * (CHROMA_BLEED + 1.0)).rgb;
    vec3 r_wide = texture2D(Texture, uv + dx * (CHROMA_BLEED + 1.0)).rgb;
    
    vec2 wide_chroma = (rgb2yiq(l_wide).yz + rgb2yiq(r_wide).yz + c_yiq.yz) / 3.0;
    c_yiq.yz = mix(c_yiq.yz, wide_chroma, clamp(CHROMA_BLEED * 0.5, 0.0, 1.0));

    // 6. Tilt Rainbow
    float phase = (uv.x * TextureSize.x + uv.y * TextureSize.y * RAINBOW_TILT) * (RAINBOW_FREQ * 0.1);
    vec3 rainbow = vec3(sin(phase), sin(phase + 2.09), sin(phase + 4.18)) * RAINBOW_POWER;
    c_yiq.yz += rainbow.xy * dither_mask;

    // 7. Final Output & Noise
    vec3 final_rgb = yiq2rgb(c_yiq);
    float noise = (rand(uv) - 0.5) * STATIC_NOISE;
    
    gl_FragColor = vec4(final_rgb + noise, 1.0);
}
#endif