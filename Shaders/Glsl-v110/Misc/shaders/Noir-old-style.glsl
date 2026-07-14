/* RetroArch Noir Enhanced Shader - Grain, Contrast,  Sepia, De-Dither, Flicker, Bloom, Scanlines */
#version 110

// RetroArch Parameters
#pragma parameter contrast "Contrast" 1.6 1.0 3.0 0.1
#pragma parameter grain_strength "Film Grain Intensity" 0.05 0.0 0.2 0.01
#pragma parameter brightness "Base Brightness" 0.03 -0.5 0.5 0.02
#pragma parameter sepia "Sepia Tone Amount" 0.3 0.0 1.0 0.1
#pragma parameter de_dither "De-Dither Intensity" 0.0 0.0 1.0 0.1
#pragma parameter bloom "Highlight Glow" 0.2 0.0 1.0 0.05

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
uniform int FrameCount; // يُستخدم للارتعاش

uniform float contrast;
uniform float grain_strength;
uniform float brightness;
uniform float sepia;
uniform float de_dither;
uniform float bloom;


float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    // 1. معالجة الديثر
    vec2 texelSize = vec2(1.0 / TextureSize.x, 0.0);
    vec3 color1 = texture2D(Texture, uv).rgb;
    vec3 color2 = texture2D(Texture, uv + texelSize).rgb;
    

vec3 color = mix(color1, (color1 + color2) * 0.5, de_dither);

    // 2. تطبيق السطوع
    color += brightness;

    // 3. التحويل لرمادي
    float gray = dot(color, vec3(0.299, 0.587, 0.114));

    // 4. وهج الإضاءة (Bloom/Highlight Glow)
    // يزيد من سطوع المناطق الساطعة فقط لإعطاء مظهر سينمائي حالم
    gray += pow(gray, 3.0) * bloom;

    // 5. التباين
    gray = (gray - 0.5) * contrast + 0.5;

    
    
   
    

    // 8. الحبيبات (Grain)
    float noise = (rand(uv) - 0.5) * grain_strength;
    gray += noise;

 

    // 10. السبيا (Sepia)
    vec3 finalColor = vec3(gray);
    vec3 sepiaColor = vec3(gray) * vec3(1.2, 1.1, 0.9);
    finalColor = mix(finalColor, sepiaColor, sepia);

    gl_FragColor = vec4(finalColor, 1.0);
}
#endif