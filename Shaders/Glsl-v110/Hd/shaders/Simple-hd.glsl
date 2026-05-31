#version 110

#pragma parameter SATURATION "Saturation" 1.20 0.00 3.00 0.01
#pragma parameter C_BLK_LVL "Black Level" 0.0 -0.2 0.2 0.01
#pragma parameter C_WHT_LVL "White Level" 1.0 0.0 1.0 0.01
#pragma parameter RIM_STRENGTH "Rim Strength" 0.35 0.00 2.00 0.01
#pragma parameter RIM_THRESHOLD "Rim Threshold" 0.08 0.00 0.50 0.01
#pragma parameter FRESNEL_STRENGTH "Fresnel Strength" 0.20 0.00 2.00 0.01
#pragma parameter SPECULAR_STRENGTH "Specular Strength" 0.15 0.00 2.00 0.01
#pragma parameter AO_STRENGTH "Fake AO" 0.35 0.00 1.50 0.01
#pragma parameter SHARPNESS "Sharpness" 0.0 -1.00 2.00 0.01

#if defined(VERTEX)

attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 uv;
uniform mat4 MVPMatrix;

void main()
{
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
uniform vec2 InputSize;

#ifdef PARAMETER_UNIFORM

uniform float SATURATION;
uniform float C_BLK_LVL,C_WHT_LVL;
uniform float RIM_STRENGTH;
uniform float RIM_THRESHOLD;
uniform float FRESNEL_STRENGTH;
uniform float SPECULAR_STRENGTH;
uniform float AO_STRENGTH;
uniform float SHARPNESS;

#else

#define SATURATION        1.20
#define RIM_STRENGTH      0.35
#define RIM_THRESHOLD     0.08
#define FRESNEL_STRENGTH  0.20
#define SPECULAR_STRENGTH 0.15
#define AO_STRENGTH       0.35
#define SHARPNESS         0.20

#endif

void main()
{
    vec2 px = vec2(
        1.0 / TextureSize.x,
        1.0 / TextureSize.y
    );

    vec3 c = texture2D(Texture, uv).rgb;

    vec3 l = texture2D(Texture, uv - vec2(px.x, 0.0)).rgb;
    vec3 r = texture2D(Texture, uv + vec2(px.x, 0.0)).rgb;
    vec3 u = texture2D(Texture, uv - vec2(0.0, px.y)).rgb;
    vec3 d = texture2D(Texture, uv + vec2(0.0, px.y)).rgb;

    vec3 avgNeighbor = (l + r + u + d) * 0.25;

    //---------------------------------
    // SHARPEN (PURE MATH)
    //---------------------------------
    c += (c - avgNeighbor) * (SHARPNESS * 2.0);

    //---------------------------------
    // LUMINANCE
    //---------------------------------
    float lum = dot(c, vec3(0.299, 0.587, 0.114));

    //---------------------------------
    // SATURATION (NO MIX)
    //---------------------------------
    c = vec3(lum) + SATURATION * (c - lum);

    //---------------------------------
    // CONTRAST
    //---------------------------------
    c = max(vec3(0.0), c - C_BLK_LVL); 
c = c * (1.0 / max(0.001, C_WHT_LVL));

    //---------------------------------
    // EDGE DETECTION (NO SQRT / NO LENGTH)
    //---------------------------------
    float edge = dot(abs(c - avgNeighbor), vec3(0.57735));

    //---------------------------------
    // RIM LIGHT (NO DIVISION)
    //---------------------------------
    float rim = clamp((edge - RIM_THRESHOLD) * 6.66667, 0.0, 1.0);

    //---------------------------------
    // FRESNEL (FAST MATH)
    //---------------------------------
    float fresnel = clamp(edge * 2.0, 0.0, 1.0);
    fresnel *= fresnel;

    //---------------------------------
    // SPECULAR (FAST MATH)
    //---------------------------------
    float spec = max(lum - 0.65, 0.0);
    spec *= spec;
    spec *= spec;

    //---------------------------------
    // CAVITY AO (NO DIVISION)
    //---------------------------------
    float neighborLum = dot(avgNeighbor, vec3(0.299, 0.587, 0.114));
    float cavity = max(neighborLum - lum, 0.0);
    
    float ao = clamp((cavity - 0.01) * 5.26316, 0.0, 1.0);
    ao += rim * 0.15; 
    
    // تطبيق التعتيم رياضياً
    c *= max(1.0 - ao * AO_STRENGTH, 0.0);

    //---------------------------------
    // COMBINED LIGHTING OUTPUT
    //---------------------------------
    // تم إزالة الفريسنال من هنا تماماً لحماية ألوان الصورة الأصلية من التبييض والانفجار الضوئي
    c += (rim * RIM_STRENGTH + spec * SPECULAR_STRENGTH);

    //---------------------------------
    // FRESNEL HALO (PURE ALGEBRAIC BLEND)
    //---------------------------------
    // إضافة الهالة كطبقة مدمجة ناعمة تحيط بالحواف فقط دون التلاعب بالإضاءة الداخلية
    vec3 haloColor = vec3(0.30, 0.55, 1.00); // لون الهالة الأزرق النيون (يمكنك تعديله حسب رغبتك)
    c += (haloColor - c) * (fresnel * FRESNEL_STRENGTH);

    //---------------------------------
    // FINAL
    //---------------------------------
    c = clamp(c, 0.0, 1.0);
    gl_FragColor = vec4(c, 1.0);
}

#endif