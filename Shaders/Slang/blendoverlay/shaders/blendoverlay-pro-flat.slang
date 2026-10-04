#version 450

/* ULTIMATE-HYBRID (300 Engine - Backported to 110)
    - REMOVED: Distortion, Vignette, and Quilez Scaling (Raw Performance Mode).
    - REMOVED: Game Zoom feature for fixed 1:1 pixel mapping.
    - FIXED: Bright Boost moved to final stage for correct blending.
*/

// --- PARAMETERS ---

#pragma parameter BRIGHT_BOOST "Final Bright Boost" 1.2 1.0 5.0 0.05
#pragma parameter blend_mode "L1 Mode: Mult, Over, Soft, SUB, DODGE, DARK" 0.0 0.0 5.0 1.0
#pragma parameter overlay_str "L1 PNG Intensity" 0.35 0.0 1.0 0.05
#pragma parameter zoom_overlay "L1 PNG Scale" 1.0 0.1 10.0 0.1
#pragma parameter png_width "L1 PNG Width" 6.0 1.0 1024.0 1.0
#pragma parameter png_height "L1 PNG Height" 4.0 1.0 1024.0 1.0
#pragma parameter blend_mode2 "L2 Mode: Mult, Over, Soft, SUB, DODGE, DARK" 0.0 0.0 5.0 1.0
#pragma parameter overlay_str2 "L2 PNG Intensity" 0.20 0.0 1.0 0.05
#pragma parameter zoom_overlay2 "L2 PNG Scale" 1.0 0.1 10.0 0.1
#pragma parameter png_width2 "L2 PNG Width" 6.0 1.0 1024.0 1.0
#pragma parameter png_height2 "L2 PNG Height" 4.0 1.0 1024.0 1.0

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float BRIGHT_BOOST;
	float blend_mode;
	float overlay_str;
	float zoom_overlay;
	float png_width;
	float png_height;
	float blend_mode2;
	float overlay_str2;
	float zoom_overlay2;
	float png_width2;
	float png_height2;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 TEX0;
layout(location = 1) out vec2 screen_scale;
layout(location = 2) out vec2 inv_tex_size;

void main() {
    gl_Position = global.MVP * Position;
    TEX0 = TexCoord; 
    screen_scale = params.SourceSize.xy / params.SourceSize.xy;
    inv_tex_size = params.SourceSize.zw;
}

#pragma stage fragment
layout(location = 0) in vec2 TEX0;
layout(location = 1) in vec2 screen_scale;
layout(location = 2) in vec2 inv_tex_size;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D OverlayTexture;
layout(set = 0, binding = 4) uniform sampler2D OverlayTexture2;

vec3 blend_logic(vec3 a, vec3 b, float mode) {
    if (mode < 0.5) return a * b;
    if (mode < 1.5) return mix(2.0 * a * b, 1.0 - 2.0 * (1.0 - a) * (1.0 - b), step(0.5, a.r));
    if (mode < 2.5) return (1.0 - 2.0 * b) * a * a + 2.0 * b * a;
    if (mode < 3.5) return clamp(a - b, 0.0, 1.0);
    if (mode < 4.5) return a / (1.00001 - b);
    return min(a, b);
}

void main() {
    // إحداثيات للشاشة (تستخدم للطبقات)
    vec2 mP = TEX0.xy * screen_scale; 
    
    // [1] إعداد إحداثيات الصورة الأصلية (بدون زوم)
    vec2 uv = TEX0.xy;
    
    // [2] DIRECT SAMPLING (Raw Mode)
    vec3 res = texture(Source, uv).rgb;

    // [3] Layer 1
    if (params.overlay_str > 0.01) {
        vec2 maskUV1 = vec2(fract(mP.x * params.OutputSize.x / (params.png_width * params.zoom_overlay)), 
                            fract(mP.y * params.OutputSize.y / (params.png_height * params.zoom_overlay)));
        vec3 png1 = texture(OverlayTexture, maskUV1).rgb;
        res = mix(res, clamp(blend_logic(res, png1, params.blend_mode), 0.0, 1.0), params.overlay_str);
    }

    // [4] Layer 2
    if (params.overlay_str2 > 0.01) {
        vec2 maskUV2 = vec2(fract(mP.x * params.OutputSize.x / (params.png_width2 * params.zoom_overlay2)), 
                            fract(mP.y * params.OutputSize.y / (params.png_height2 * params.zoom_overlay2)));
        vec3 png2 = texture(OverlayTexture2, maskUV2).rgb;
        res = mix(res, clamp(blend_logic(res, png2, params.blend_mode2), 0.0, 1.0), params.overlay_str2);
    }

    // [5] تطبيق الـ Boost النهائي
    res *= params.BRIGHT_BOOST;

    FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
