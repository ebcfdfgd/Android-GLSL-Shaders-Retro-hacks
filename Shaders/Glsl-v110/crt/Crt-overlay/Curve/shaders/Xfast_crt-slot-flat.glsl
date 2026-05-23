#version 110

/* 777-TURBO-ZFAST-PURE-RGB (Screen-Locked Mask Revision)
    - INTEGRATED: Barrel Distortion (Curve 70 Logic).
    - PERFORMANCE: Scanlines and Mask decoupled from warped geometry.
    - SYNCED: Mask locked to gl_FragCoord for zero-aliasing.
*/

#pragma parameter BRIGHTBOOST "Brightness Boost" 1.25 0.5 2.0 0.05
#pragma parameter MASK_STR "Mask Intensity" 0.45 0.0 1.0 0.05
#pragma parameter SCAN_STRENGTH "Scanline Strength" 0.5 0.0 1.0 0.05
#pragma parameter SCAN_FADE_POINT "Scanline Fade Cutoff" 0.85 0.5 1.0 0.05
#pragma parameter BARREL_DISTORTION "Screen Curve" 0.08 0.0 0.5 0.01

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv;
uniform mat4 MVPMatrix;

void main() {
    uv = TexCoord;
    gl_Position = MVPMatrix * VertexCoord;
}

#elif defined(FRAGMENT)
precision highp float;
varying vec2 uv;
uniform sampler2D Texture;
uniform vec2 TextureSize;
uniform vec2 InputSize;
uniform float BRIGHTBOOST, MASK_STR, SCAN_STRENGTH, SCAN_FADE_POINT, BARREL_DISTORTION;

void main() 
{
    // 1. BARREL DISTORTION (Geometry Only)
    vec2 scale = TextureSize / InputSize;
    vec2 texcoord = (uv * scale) - vec2(0.5);
    
    float rsq = dot(texcoord, texcoord);
    texcoord += texcoord * (BARREL_DISTORTION * rsq);
    texcoord *= (1.0 - (0.12 * BARREL_DISTORTION));

    if (abs(texcoord.x) > 0.5 || abs(texcoord.y) > 0.5) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }
    
    vec2 warped_uv = (texcoord + vec2(0.5)) / scale;
    vec3 res = texture2D(Texture, warped_uv).rgb;

    // 2. SCANLINES (Decoupled: Using uv.y - Fixed Grid)
    float scanline = sin(uv.y * TextureSize.y * 6.283185);
    float luma = dot(res, vec3(0.299, 0.587, 0.114));
    float fade = smoothstep(0.0, SCAN_FADE_POINT, luma);
    
    float scan_effect = 1.0 - (scanline * 0.5 + 0.5) * SCAN_STRENGTH * (1.0 - fade);
    vec3 final_rgb = res * scan_effect;

    // 3. MASK (Screen-Locked: Using gl_FragCoord.xy)
    // التغيير: الماسك الآن ثابت تماماً بالنسبة للشاشة
    int x_coord = int(mod(gl_FragCoord.x, 3.0));
    int y_coord = int(mod(gl_FragCoord.y, 1.0)); // يمكن تعديل y_coord لنمط أوسع
    
    vec3 mcol = vec3(0.0);
    mcol[x_coord] = 2.0; 
    
    vec3 mask_rgb = mix(vec3(1.0), mcol, MASK_STR);
    final_rgb *= mask_rgb;

    // 4. Output
    gl_FragColor = vec4(clamp(final_rgb * BRIGHTBOOST, 0.0, 1.0), 1.0);
}
#endif