#version 450

#pragma parameter overlay_str "L1 PNG Intensity (Overlay)" 1.0 0.0 1.5 0.05
#pragma parameter png_width "L1 PNG Width" 0.0 0.0 1024.0 1.0
#pragma parameter png_height "L1 PNG Height" 5.0 1.0 1024.0 1.0

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
	float overlay_str;
	float png_width;
	float png_height;
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

void main() {
    gl_Position = global.MVP * Position;
    TEX0 = TexCoord; 
    screen_scale = params.SourceSize.xy / params.SourceSize.xy;
}

#pragma stage fragment
layout(location = 0) in vec2 TEX0;
layout(location = 1) in vec2 screen_scale;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D OverlayTexture;

// دالة الـ Overlay
vec3 overlay_logic(vec3 a, vec3 b) {
    return mix(2.0 * a * b, 1.0 - 2.0 * (1.0 - a) * (1.0 - b), step(0.5, a));
}

void main() {
    vec2 mP = TEX0.xy * screen_scale; 
    
    // [1] DIRECT SAMPLING
    vec3 res = texture(Source, TEX0).rgb;

    // [2] Layer 1 (Overlay Mode)
    if (params.overlay_str > 0.01) {
        vec2 maskUV1 = vec2(fract(mP.x * params.OutputSize.x / max(params.png_width , 1.0)), 
                            fract(mP.y * params.OutputSize.y / max(params.png_height , 1.0)));
        vec3 png1 = texture(OverlayTexture, maskUV1).rgb;
        
        vec3 ovl1 = overlay_logic(res, png1);
        res = mix(res, clamp(ovl1, 0.0, 1.0), params.overlay_str);
    }

    FragColor = vec4(clamp(res, 0.0, 1.0), 1.0);
}
