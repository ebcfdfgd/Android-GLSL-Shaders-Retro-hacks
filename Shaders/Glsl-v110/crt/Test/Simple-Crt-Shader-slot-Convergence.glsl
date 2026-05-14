#version 110

/* Simple-Crt-Shader 
       -Curve 
       -Mask
       -Scanlines
       -Bright-boost
       -Quilez
       -Fixed Convergence
*/

// ========================================== Parameters ==========================================

#pragma parameter CONV_X "Home TV Convergence X" 0.35 -2.0 2.0 0.05
#pragma parameter CONV_Y "Home TV Convergence Y" 0.15 -2.0 2.0 0.05
#pragma parameter BARREL_DISTORTION "Screen Curve" 0.15 0.0 1.0 0.02
#pragma parameter BRIGHT_BOOST "Brightness Boost" 1.17 1.0 2.0 0.01
#pragma parameter BLURSCALEX "Zfast Sharpness X" 0.30 0.0 1.0 0.05
#pragma parameter LOWLUMSCAN "Zfast Scanline Dark" 6.0 0.0 10.0 0.5
#pragma parameter HILUMSCAN "Zfast Scanline Bright" 8.0 0.0 50.0 1.0
#pragma parameter MASK_FADE "Zfast Dynamic Strength" 0.8 0.0 1.0 0.05
#pragma parameter MASK_STR "Mask Strength" 0.15 0.0 1.0 0.05

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
uniform vec2 TextureSize, InputSize;

#ifdef PARAMETER_UNIFORM
uniform float BARREL_DISTORTION;
uniform float BRIGHT_BOOST;
uniform float LOWLUMSCAN;
uniform float HILUMSCAN;
uniform float MASK_FADE;
uniform float BLURSCALEX;
uniform float MASK_STR;
uniform float CONV_X;
uniform float CONV_Y;
#endif

void main() {
    vec2 sc = TextureSize / InputSize;
    vec2 p = (uv * sc) - 0.5;

// ========================================== Curve ==========================================

    float ky = BARREL_DISTORTION * 0.8; 
    vec2 p_curved;
    p_curved.x = p.x * (1.0 + (p.y * p.y) * (BARREL_DISTORTION * 0.2));
    p_curved.y = p.y * (1.0 + (p.x * p.x) * ky);
    p_curved *= (1.0 - 0.1 * BARREL_DISTORTION);

    if (abs(p_curved.x) > 0.5 || abs(p_curved.y) > 0.5) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

// ========================================== Quilez ==========================================

    vec2 uv_curved = (p_curved + 0.5) / sc;
    
    vec2 z_p = uv_curved * TextureSize;
    vec2 z_i = floor(z_p) + 0.50;
    vec2 z_f = z_p - z_i;

    vec2 z_uv;
    z_uv.y = (z_i.y + 4.0 * z_f.y * z_f.y * z_f.y) / TextureSize.y;
    z_uv.x = mix((z_i.x + 4.0 * z_f.x * z_f.x * z_f.x) / TextureSize.x, uv_curved.x, BLURSCALEX);

// ========================================== Convergence & FETCH ==========================================

    vec2 c_offset = vec2(CONV_X, CONV_Y) / TextureSize;

    // جلب القنوات بشكل منفصل لتطبيق التقارب على الإحداثيات المصححة z_uv
    float res_R = texture2D(Texture, z_uv + c_offset).r;
    float res_G = texture2D(Texture, z_uv).g;
    float res_B = texture2D(Texture, z_uv - c_offset).b;

    vec3 res = vec3(res_R, res_G, res_B);

// ========================================== Scanlines ==========================================

    float z_py = (p_curved.y + 0.5) * InputSize.y;
    float z_fy = fract(z_py + 0.5) - 0.5; 

    float z_Y  = z_fy * z_fy;
    float z_YY = z_Y * z_Y;
   
    float z_weightLow  = (1.0 - LOWLUMSCAN * (z_Y - 2.05 * z_YY));
    float z_weightHigh = 1.0 - HILUMSCAN * (z_YY - 2.8 * z_YY * z_Y);    

    float z_luma = dot(res.rgb, vec3(0.333 * MASK_FADE));
    res.rgb *= mix(z_weightLow, z_weightHigh, z_luma);

// ========================================== Mask ==========================================

    vec3 mcol = vec3(0.0);
    float y_off = mod(floor(gl_FragCoord.x / 3.0), 2.0);
    mcol[int(mod(gl_FragCoord.x, 3.0))] = (mod(gl_FragCoord.y + y_off, 2.0) < 1.0) ? 1.0 : 0.2;
    res *= mix(vec3(1.0), mcol, MASK_STR);

// ========================================== Bright boost ==========================================

    res *= BRIGHT_BOOST;

    gl_FragColor = vec4(res, 1.0);
}
#endif