// Convergence and Integrated Bloom - Optimized to 3 Fetches - #version 110

#pragma parameter x_off_r "Conv. X Offset Red" 0.05 -1.0 1.0 0.01
#pragma parameter y_off_r "Conv. Y Offset Red" 0.0 -1.0 1.0 0.01
#pragma parameter x_off_g "Conv. X Offset Green" -0.0 -1.0 1.0 0.01
#pragma parameter y_off_g "Conv. Y Offset Green" -0.0 -1.0 1.0 0.01
#pragma parameter x_off_b "Conv. X Offset Blue" -0.05 -1.0 1.0 0.01
#pragma parameter y_off_b "Conv. Y Offset Blue" 0.0 -1.0 1.0 0.01
#pragma parameter BLOOM_STR "Bloom Intensity" 0.3 0.0 1.0 0.05
#pragma parameter BLOOM_THR "Bloom Threshold" 0.6 0.0 1.0 0.05

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

#ifdef PARAMETER_UNIFORM
uniform float x_off_r, y_off_r, x_off_g, y_off_g, x_off_b, y_off_b;
uniform float BLOOM_STR, BLOOM_THR;
#endif

void main() {
    // 1. حساب إحداثيات التقارب (3 نقاط)
    vec2 red_coord = uv + 0.01 * vec2(x_off_r, y_off_r);
    vec2 green_coord = uv + 0.01 * vec2(x_off_g, y_off_g);
    vec2 blue_coord = uv + 0.01 * vec2(x_off_b, y_off_b);
    
    // 2. سحب النسيج (3 سحبات فقط - Texture Fetches)
    vec3 colR = texture2D(Texture, red_coord).rgb;
    vec3 colG = texture2D(Texture, green_coord).rgb;
    vec3 colB = texture2D(Texture, blue_coord).rgb;
    
    // 3. تجميع اللون الأساسي
    vec3 base = vec3(colR.r, colG.g, colB.b);

    // 4. حساب البلوم (باستخدام القيم التي سحبناها للتو)
    // نأخذ متوسط سطوع القنوات للتركيز على المناطق الساطعة
    vec3 bloom_source = (colR + colG + colB) / 3.0;
    vec3 bloom_final = max(bloom_source - BLOOM_THR, 0.0) * BLOOM_STR;

    // النتيجة النهائية
    gl_FragColor = vec4(base + bloom_final, 1.0);
}
#endif