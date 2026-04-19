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
#pragma parameter CHROMA_BLEED "Chroma Bleed Distance" 1.5 0.1 5.0 0.1
#pragma parameter MD_JAILBARS "Mega Drive Jailbars" 0.2 0.0 1.0 0.05
#pragma parameter JAIL_WIDTH "Jailbar Spacing" 1.0 0.1 5.0 0.1
#pragma parameter STATIC_NOISE "Static Noise Intensity" 0.02 0.0 0.2 0.01

uniform float DITHER_THRESHOLD, DITHER_BLUR, RAINBOW_FREQ, RAINBOW_TILT, RAINBOW_POWER, CHROMA_BLEED, MD_JAILBARS, JAIL_WIDTH, STATIC_NOISE;

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

void main() {
    // حساب مسافة السيلان بناءً على CHROMA_BLEED
    vec2 bleed_dist = vec2(CHROMA_BLEED / TextureSize.x, 0.0);
    
    // 1. Sampling (العينات الآن تعتمد على المسافة الديناميكية)
    vec3 c_rgb = texture2D(Texture, uv).rgb;
    vec3 l1 = texture2D(Texture, uv - bleed_dist).rgb;
    vec3 r1 = texture2D(Texture, uv + bleed_dist).rgb;
    vec3 l2 = texture2D(Texture, uv - bleed_dist * 2.0).rgb;
    vec3 r2 = texture2D(Texture, uv + bleed_dist * 2.0).rgb;

    vec3 c_yiq = rgb2yiq(c_rgb);
    vec3 l_yiq = rgb2yiq(l1);
    vec3 r_yiq = rgb2yiq(r1);

    // 2. MD Jailbars
    float jailbar = sin(uv.x * TextureSize.x * (3.14159 / JAIL_WIDTH));
    c_yiq.x *= 1.0 - (jailbar * 0.1 * MD_JAILBARS);

    // 3. Strict Dither Detection
    float luma_avg = (l_yiq.x + r_yiq.x) * 0.5;
    float dither_mask = smoothstep(DITHER_THRESHOLD, DITHER_THRESHOLD + 0.1, abs(c_yiq.x - luma_avg));

    // 4. Dither Blur
    c_yiq.x = mix(c_yiq.x, luma_avg, dither_mask * DITHER_BLUR);

    // 5. Chroma Bleeding (تجميع الألوان من مسافة بعيدة)
    // نأخذ الألوان من اليمين واليسار ونوزعها على البكسل الحالي
    vec3 left_y = rgb2yiq(l2);
    vec3 right_y = rgb2yiq(r2);
    vec2 wide_chroma = (l_yiq.yz + r_yiq.yz + left_y.yz + right_y.yz) * 0.25;
    c_yiq.yz = mix(c_yiq.yz, wide_chroma, 0.8); // 0.8 هي قوة السيلان الثابتة

    // 6. Tilt Rainbow
    float phase = (uv.x * TextureSize.x + uv.y * TextureSize.y * RAINBOW_TILT) * (RAINBOW_FREQ * 0.1);
    vec3 rainbow = vec3(sin(phase), sin(phase + 2.09), sin(phase + 4.18)) * RAINBOW_POWER;
    c_yiq.yz += rainbow.xy * dither_mask;

    // 7. Final Output
    vec3 final_rgb = yiq2rgb(c_yiq);
    float noise = (fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) * STATIC_NOISE;
    
    gl_FragColor = vec4(final_rgb + noise, 1.0);
}
#endif