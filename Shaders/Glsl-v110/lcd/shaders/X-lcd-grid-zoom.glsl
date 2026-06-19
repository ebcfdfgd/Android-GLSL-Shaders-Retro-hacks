#version 110
#extension GL_OES_standard_derivatives : enable

/* 5060-ZOOM-GSTR-HYBRID (Subpixel Pure + Full-Cycle Scanline)
    - ZOOM: Integrated 5060 Global Zoom logic.
    - GREEN: Retained G_STR Green Mask Power.
    - SUBPIXEL: Pure Subpixel structures intact.
    - SCANLINE: Added full-cycle sin-wave horizontal scanlines mapped to zoom coords.
*/

#pragma parameter GAME_ZOOM "Global Zoom Scale" 0.964 0.5 2.0 0.001
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
uniform float GAME_ZOOM, SUBPIX_STR, SCAN_LINE, BRIGHTNESS_LCD;
#endif

void main() {
    // 1. Zoom Logic from 5060
    vec2 uv = (vTexCoord - 0.5) / GAME_ZOOM + 0.5;

    // Bounds Check
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // 2. Pixel Coordinates based on Zoom
    vec2 pix_coord = uv * TextureSize;
    vec3 color = texture2D(Texture, uv).rgb;

    // 3. Full-Cycle Scanline Logic
    // استخدام دالة الجيب (sin) على مدار دورة كاملة 2*PI موازية لموقع البكسل الرأسي
    float wave = sin(pix_coord.y * 6.2831853);
    // تحويل النطاق من [-1, 1] إلى [0, 1] بشكل ناعم ومتزن تماماً كدورة كاملة
    float scan_smooth = wave * 0.5 + 0.5;
    float scan_dim_multiplier = mix(1.0, 1.0 - SCAN_LINE, scan_smooth);

    // 4. Subpixel Logic + Green Power (G_STR)
    vec2 pos = fract(pix_coord);
    float x = pos.x * 3.0;
    vec3 w;
    w.r = clamp(1.0 - abs(x - 0.5), 0.0, 1.0);
    w.g = clamp(1.0 - abs(x - 1.5), 0.0, 1.0);
    w.b = clamp(1.0 - abs(x - 2.5), 0.0, 1.0);
    
    vec3 subpixel = mix(vec3(1.0), w * 1.1, SUBPIX_STR);

    // 5. Final Output
    vec3 final = color * subpixel * scan_dim_multiplier * BRIGHTNESS_LCD;

    gl_FragColor = vec4(clamp(final, 0.0, 1.0), 1.0);
}
#endif