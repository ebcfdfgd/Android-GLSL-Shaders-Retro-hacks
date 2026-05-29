#version 110
#extension GL_OES_standard_derivatives : enable

/* 5060-GSTR-HYBRID (Subpixel Pure + Full-Cycle Scanline - No Zoom)
    - GREEN: Retained G_STR Green Mask Power.
    - SUBPIXEL: Pure Subpixel structures intact.
    - SCANLINE: Full-cycle sin-wave horizontal scanlines.
    - REMOVED: Global Zoom logic and bounds checking.
*/

#pragma parameter SUBPIX_STR "Subpixel Strength" 0.5 0.0 1.0 0.05
#pragma parameter SCAN_LINE "Horizontal Scan Dim" 0.10 0.0 0.50 0.01
#pragma parameter BRIGHTNESS_LCD "Brightness Boost" 1.2 1.0 2.0 0.05

#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec4 TexCoord;
varying vec2 vTexCoord;
uniform mat4 MVPMatrix;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    vTexCoord = TexCoord.xy;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 vTexCoord;
uniform sampler2D Texture;
uniform vec2 TextureSize;

#ifdef PARAMETER_UNIFORM
uniform float SUBPIX_STR, SCAN_LINE, BRIGHTNESS_LCD;
#endif

void main() {
    // 1. Direct Coordinates (Zoom Removed)
    vec2 uv = vTexCoord;
    vec2 pix_coord = uv * TextureSize;
    vec3 color = texture2D(Texture, uv).rgb;

    // 2. Full-Cycle Scanline Logic
    // استخدام دالة الجيب (sin) على مدار دورة كاملة 2*PI موازية لموقع البكسل الرأسي
    float wave = sin(pix_coord.y * 6.2831853);
    // تحويل النطاق من [-1, 1] إلى [0, 1] بشكل ناعم ومتزن تماماً كدورة كاملة
    float scan_smooth = wave * 0.5 + 0.5;
    float scan_dim_multiplier = mix(1.0, 1.0 - SCAN_LINE, scan_smooth);

    // 3. Subpixel Logic
    vec2 pos = fract(pix_coord);
    float x = pos.x * 3.0;
    vec3 w;
    w.r = clamp(1.0 - abs(x - 0.5), 0.0, 1.0);
    w.g = clamp(1.0 - abs(x - 1.5), 0.0, 1.0);
    w.b = clamp(1.0 - abs(x - 2.5), 0.0, 1.0);
    
    vec3 subpixel = mix(vec3(1.0), w * 1.1, SUBPIX_STR);

    // 4. Final Output
    vec3 final = color * subpixel * scan_dim_multiplier * BRIGHTNESS_LCD;

    gl_FragColor = vec4(clamp(final, 0.0, 1.0), 1.0);
}
#endif