#version 110

/* 777-TURBO-ZFAST-PURE-RGB (FIXED FADE)
    - FIX: Changed fade logic to prevent darkening the base image.
*/

#pragma parameter BRIGHTBOOST "Brightness Boost" 1.25 0.5 2.0 0.05
#pragma parameter MASK_STR "Mask Intensity" 0.45 0.0 1.0 0.05
#pragma parameter SCAN_STRENGTH "Scanline Strength" 0.5 0.0 1.0 0.05
#pragma parameter SCAN_FADE_POINT "Scanline Fade Cutoff" 0.85 0.5 1.0 0.05

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
#ifdef GL_ES
precision highp float;
#endif

varying vec2 uv;
uniform sampler2D Texture;
uniform vec2 TextureSize;

#ifdef PARAMETER_UNIFORM
uniform float BRIGHTBOOST, MASK_STR, SCAN_STRENGTH, SCAN_FADE_POINT;
#endif

void main() 
{
    vec3 res = texture2D(Texture, uv).rgb;

    // 1. حساب السكان لاين
    // نطرح من 1.0 للحصول على خطوط داكنة
    float scanline = sin(uv.y * TextureSize.y * 3.14159 * 2.0);
    
    // حساب السطوع (Luma) لتلاشي السكان لاين
    float luma = dot(res, vec3(0.299, 0.587, 0.114));
    
    // كلما زاد السطوع، قل تأثير السكان لاين (من 0 إلى 1)
    float fade = smoothstep(0.0, SCAN_FADE_POINT, luma);
    
    // نستخدم (1.0 - (scan * strength * (1.0 - fade)))
    // بهذه الطريقة، عندما يكون fade = 1 (أبيض)، التأثير يصبح (1.0 - 0) = 1 (بدون تعتيم)
    float scan_effect = 1.0 - (scanline * 0.5 + 0.5) * SCAN_STRENGTH * (1.0 - fade);
    vec3 final_rgb = res * scan_effect;

    // 2. ماسك الـ Slot
    int x_coord = int(mod(gl_FragCoord.x, 6.0));
    int y_coord = int(mod(gl_FragCoord.y, 2.0));
    int idx = x_coord - (y_coord * 3);
    
    vec3 mcol = vec3(0.0);
    if (idx >= 0 && idx < 3) {
        mcol[idx] = 2.0; 
    }
    
    vec3 mask_rgb = mix(vec3(1.0), mcol, MASK_STR);
    final_rgb *= mask_rgb;

    // 3. السطوع النهائي
    gl_FragColor = vec4(final_rgb * BRIGHTBOOST, 1.0);
}
#endif