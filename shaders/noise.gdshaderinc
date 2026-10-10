// Procedural noise shared by planet and sky shaders (no textures).

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

// Smooth value noise in [0, 1].
float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash13(i + vec3(0, 0, 0)), hash13(i + vec3(1, 0, 0)), u.x),
			mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), u.x), u.y),
		mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), u.x),
			mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), u.x), u.y), u.z);
}

// Four-octave fractal noise in roughly [0, 1].
float fbm(vec3 p) {
	float sum = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		sum += amplitude * value_noise(p);
		p = p * 2.03 + vec3(17.1, 9.2, 4.7);
		amplitude *= 0.5;
	}
	return sum / 0.9375;
}

// Cellular noise: x = distance to nearest feature point, y = second nearest,
// z = random id of the nearest cell.
vec3 voronoi(vec3 p) {
	vec3 cell = floor(p);
	vec3 local = fract(p);
	float f1 = 8.0;
	float f2 = 8.0;
	float id = 0.0;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 offset = vec3(float(x), float(y), float(z));
				vec3 point = offset + hash33(cell + offset);
				float d = length(point - local);
				if (d < f1) {
					f2 = f1;
					f1 = d;
					id = hash13(cell + offset);
				} else if (d < f2) {
					f2 = d;
				}
			}
		}
	}
	return vec3(f1, f2, id);
}
