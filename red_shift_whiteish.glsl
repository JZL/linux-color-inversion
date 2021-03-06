uniform bool invert_color;
uniform float opacity;
uniform sampler2D tex;

/**
 * based on shift.glsl https://github.com/vn971/linux-color-inversion
 */
vec4 shift_invert(vec4 c) {
	float white_bias = 0.0;
	/* float white_bias = -.27; */

	/* vec4 c = texture2D(tex, gl_TexCoord[0].st); */
	if (invert_color) {
		float m = 1.0 + white_bias;
		float shift = white_bias + c.a - min(c.r, min(c.g, c.b)) - max(c.r, max(c.g, c.b));
		c = vec4((shift + c.r) / m, (shift + c.g) / m, (shift + c.b) / m, c.a);
	}
	c *= opacity;
  return c;
}

/*
 * Below copied From https://www.shadertoy.com/view/lsSXW1
 *
 * ported by Renaud Bédard (@renaudbedard) from original code from Tanner Helland
 * http://www.tannerhelland.com/4435/convert-temperature-rgb-algorithm-code/
 * color space functions translated from HLSL versions on Chilli Ant (by Ian Taylor)
 * http://www.chilliant.com/rgb2hsv.html
 * licensed and released under Creative Commons 3.0 Attribution
 * https://creativecommons.org/licenses/by/3.0/

 * Playing with the #define'd constants tweaks how dim or bright the resulting image is
 * See also factor and colorTempK values for tweaking amount and temp
 */

#define LUMINANCE_PRESERVATION 0.55

#define EPSILON 1e-10

float saturate(float v) { return clamp(v, 0.0,       1.0);       }
vec2  saturate(vec2  v) { return clamp(v, vec2(0.0), vec2(1.0)); }
vec3  saturate(vec3  v) { return clamp(v, vec3(0.0), vec3(1.0)); }
vec4  saturate(vec4  v) { return clamp(v, vec4(0.0), vec4(1.0)); }

vec3 ColorTemperatureToRGB(float temperatureInKelvins)
{
	vec3 retColor;
	
    temperatureInKelvins = clamp(temperatureInKelvins, 1000.0, 40000.0) / 100.0;
    
    if (temperatureInKelvins <= 66.0)
    {
        retColor.r = 1.0;
        retColor.g = saturate(0.39008157876901960784 * log(temperatureInKelvins) - 0.63184144378862745098);
    }
    else
    {
    	float t = temperatureInKelvins - 60.0;
        retColor.r = saturate(1.29293618606274509804 * pow(t, -0.1332047592));
        retColor.g = saturate(1.12989086089529411765 * pow(t, -0.0755148492));
    }
    
    if (temperatureInKelvins >= 66.0)
        retColor.b = 1.0;
    else if(temperatureInKelvins <= 19.0)
        retColor.b = 0.0;
    else
        retColor.b = saturate(0.54320678911019607843 * log(temperatureInKelvins - 10.0) - 1.19625408914);

    return retColor;
}

float Luminance(vec3 color)
{
  float fmin = min(min(color.r, color.g), color.b);
  float fmax = max(max(color.r, color.g), color.b);
	return (fmax + fmin) / 2.0;
}

vec3 HUEtoRGB(float H)
{
    float R = abs(H * 6.0 - 3.0) - 1.0;
    float G = 2.0 - abs(H * 6.0 - 2.0);
    float B = 2.0 - abs(H * 6.0 - 4.0);
    return saturate(vec3(R,G,B));
}

vec3 HSLtoRGB(in vec3 HSL)
{
    vec3 RGB = HUEtoRGB(HSL.x);
    float C = (1.0 - abs(2.0 * HSL.z - 1.0)) * HSL.y;
    return (RGB - 0.5) * C + vec3(HSL.z);
}
 
vec3 RGBtoHCV(vec3 RGB)
{
    // Based on work by Sam Hocevar and Emil Persson
    vec4 P = (RGB.g < RGB.b) ? vec4(RGB.bg, -1.0, 2.0/3.0) : vec4(RGB.gb, 0.0, -1.0/3.0);
    vec4 Q = (RGB.r < P.x) ? vec4(P.xyw, RGB.r) : vec4(RGB.r, P.yzx);
    float C = Q.x - min(Q.w, Q.y);
    float H = abs((Q.w - Q.y) / (6.0 * C + EPSILON) + Q.z);
    return vec3(H, C, Q.x);
}

vec3 RGBtoHSL(vec3 RGB)
{
    vec3 HCV = RGBtoHCV(RGB);
    float L = HCV.z - HCV.y * 0.5;
    float S = HCV.y / (1.0 - abs(L * 2.0 - 1.0) + EPSILON);
    return vec3(HCV.x, S, L);
}

void main() {

	vec4 c = texture2D(tex, gl_TexCoord[0].st);
  
	c = shift_invert(c);

  float factor = saturate(1.0);
  float colorTempK = 1000.0;
    
  //Don't want alpha in color temp processing (TODO?)
  vec3 image = vec3(c);
  vec3 colorTempRGB = ColorTemperatureToRGB(colorTempK);
    
  /* vec4 fragColor = vec4(ColorTemperatureToRGB(1000.0), 1.0); */
  /* vec4 fragColor = vec4(0,0,0,0); */
  float originalLuminance = Luminance(image);

  vec3 blended = mix(image, image * colorTempRGB, factor);
  vec3 resultHSL = RGBtoHSL(blended);

  vec3 luminancePreservedRGB = HSLtoRGB(vec3(resultHSL.x, resultHSL.y, originalLuminance));

  vec4 fragColor = vec4(mix(blended, luminancePreservedRGB, LUMINANCE_PRESERVATION), c[3]);

	gl_FragColor = fragColor;
}

