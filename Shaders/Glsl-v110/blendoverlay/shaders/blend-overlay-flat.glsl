#version 110


#pragma parameter overlay_str "L1 PNG Intensity (Overlay)" 1.0 0.0 1.5 0.05
#pragma parameter png_width "L1 PNG Width" 0.0 0.0 1024.0 1.0
#pragma parameter png_height "L1 PNG Height" 5.0 1.0 1024.0 1.0


#if defined(VERTEX)
attribute vec4 VertexCoord;
attribute vec2 TexCoord;
varying vec2 TEX0, screen_scale;
uniform mat4 MVPMatrix;
uniform vec2 TextureSize, InputSize;

void main() {
    gl_Position = MVPMatrix * VertexCoord;
    TEX0 = TexCoord; 
    screen_scale = TextureSize / InputSize;
}

#elif defined(FRAGMENT)
#ifdef GL_ES
precision highp float;
#endif

varying vec2 TEX0, screen_scale;
uniform sampler2D Texture;           
uniform sampler2D OverlayTexture; 
uniform vec2 TextureSize, InputSize, OutputSize;

#ifdef PARAMETER_UNIFORM
uniform float overlay_str, png_width, png_height;

#endif

// دالة الـ Overlay
vec3 overlay_logic(vec3 a, vec3 b) {
    return mix(2.0 * a * b, 1.0 - 2.0 * (1.0 - a) * (1.0 - b), step(0.5, a));
}

void main() {
    vec2 mP = TEX0.xy * screen_scale; 
    
    // [1] DIRECT SAMPLING
    vec3 res = texture2D(Texture, TEX0).rgb;

    // [2] Layer 1 (Overlay Mode)
    if (overlay_str > 0.01) {
        vec2 maskUV1 = vec2(fract(mP.x * OutputSize.x / max(png_width , 1.0)), 
                            fract(mP.y * OutputSize.y / max(png_height , 1.0)));
        vec3 png1 = texture2D(OverlayTexture, maskUV1).rgb;
        
        vec3 ovl1 = overlay_logic(res, png1);
        res = mix(res, clamp(ovl1, 0.0, 1.0), overlay_str);
    }

    gl_FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
#endif