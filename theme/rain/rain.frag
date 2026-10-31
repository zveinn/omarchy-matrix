#version 440
// Movie-style digital rain, fully on the GPU.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float cell;
    float atlasCols;
    float atlasCount;
    vec2 res;
};
layout(binding = 1) uniform sampler2D atlas;

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void main() {
    vec2 px = qt_TexCoord0 * res;
    float rows = ceil(res.y / cell);
    float row = floor(px.y / cell);
    float c0 = floor(px.x / cell);
    float glow = 0.0;
    bool head = false;
    vec2 gid = vec2(0.0);   // which glyph cell this pixel shows
    float glx = 0.0;        // horizontal position inside that glyph (0..1)

    // Each drop lives on a column but gets its own sideways offset, re-rolled
    // every time it wraps, so streams never retrace the same vertical path.
    // Check neighbouring columns too, since a drop can drift into this one.
    for (int dc = -1; dc <= 1; dc++) {
        float c = c0 + float(dc);
        for (int k = 0; k < 3; k++) {
            float fk = float(k);
            float s1 = h(vec2(c, 3.0 + fk * 17.0));
            float s2 = h(vec2(c, 41.0 + fk * 29.0));
            float s3 = h(vec2(c, 97.0 + fk * 13.0));
            float speed = 9.0 + s1 * 16.0;            // cells per second
            float trail = 8.0 + s2 * 22.0;
            float period = rows * 0.6 + trail + 2.0 + s3 * rows * 0.6;
            float run = time * speed + s3 * 997.0;
            float cyc = floor(run / period);
            float off = (h(vec2(c * 1.37 + fk * 7.1, cyc * 0.917 + 3.3)) - 0.5) * 1.1;
            float lx = px.x / cell - (c + off);
            if (lx < 0.0 || lx >= 1.0) continue;
            float hd = floor(mod(run, period));
            float d = hd - row;
            if (d >= 0.0 && d < trail) {
                float b = pow(1.0 - d / trail, 1.6);
                if (b > glow) {
                    glow = b; head = (d < 1.0); glx = lx;
                    gid = vec2(c * 3.0 + fk + cyc * 0.31, row);
                }
            }
        }
    }
    if (glow <= 0.0) { fragColor = vec4(0.0, 0.0, 0.0, 1.0); return; }

    // every cell mutates its glyph at its own pace
    float rate = 0.6 + h(gid + 7.0) * 7.0;
    float tick = floor(time * rate + h(gid) * 50.0);
    float idx = floor(h(gid + tick * 0.731) * atlasCount);
    vec2 lu = vec2(1.0 - glx, fract(px.y / cell));   // mirrored glyphs, like the film
    vec2 uv = (vec2(mod(idx, atlasCols), floor(idx / atlasCols)) + lu) / atlasCols;
    float a = texture(atlas, uv).a;

    vec3 col;
    if (head) col = vec3(0.86, 1.0, 0.9);
    else      col = mix(vec3(0.0, 0.42, 0.1), vec3(0.2, 1.0, 0.38), glow);
    fragColor = vec4(col * a * max(glow, head ? 1.0 : 0.0), 1.0) * qt_Opacity;
}
