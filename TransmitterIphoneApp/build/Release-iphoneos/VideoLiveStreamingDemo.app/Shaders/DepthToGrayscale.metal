/*
See LICENSE.txt for this sample’s licensing information.

Abstract:
Metal compute shader that translates depth values to grayscale RGB values.
*/

#include <metal_stdlib>
using namespace metal;

/**
 TODO add here
 - Authors: [Apple](https://www.apple.com/)
 - Note: Based on [VideoLiveStreaming](https://developer.apple.com/library/content/samplecode/AVCamPhotoFilter/) from [Apple](https://www.apple.com/)
 */
struct converterParameters {
	float offset;
    float range;
    int interleavedDepthCoding;
};

/**
 Computes kernel
 - Authors: [Apple](https://www.apple.com/), Michael Pointner
 - Note: Based on [VideoLiveStreaming](https://developer.apple.com/library/content/samplecode/AVCamPhotoFilter/) from [Apple](https://www.apple.com/)
 */
kernel void depthToGrayscale(texture2d<float, access::read>  inputTexture      [[ texture(0) ]],
						     texture2d<float, access::write> outputTexture     [[ texture(1) ]],
							 constant converterParameters& converterParameters [[ buffer(0) ]],
							 uint2 gid [[ thread_position_in_grid ]])
{
	// Ensure we don't read or write outside of the texture
	if ((gid.x >= inputTexture.get_width()) || (gid.y >= inputTexture.get_height())) {
		return;
	}
	
	float depth = inputTexture.read(gid).x;
    
    
	// Normalize the value between 0 and 1
	depth = (depth - converterParameters.offset) / (converterParameters.range);
    
    
    int bits[3 * 8];
    
    float channel[3];
    
    for (int c = 0; c < 3; c++) {
        channel[c] = 0;
    }
    
    float d = depth;
    for (int b = 1; b <= 3 * 8; b++) {
        float s = pow(2.0, -b);
        if (d >= s) {
            bits[b - 1] = 1;
            d = d - s;
        }
        else {
            bits[b - 1] = 0;
        }
    }
    
    for (int i = 15; i <= 17; i++) {
        bits[i] = 1;
    }
    for (int i = 18; i <= 23; i++) {
        bits[i] = 0;
    }
    
    if(converterParameters.interleavedDepthCoding == 1)
    {
        // Interleaved encoding
        for (int b = 0; b < 3 * 5; b++) {
            channel[b % 3] = channel[b % 3] + pow(2.0, -b/3 - 1) * bits[b];
        }
    }
    else
    {
        // Normal encoding
        for (int b = 0; b < 3 * 5; b++) {
            channel[b / 5] = channel[b / 5] + pow(2.0, -(b % 5) - 1) * bits[b];
        }
    }
    
    // End bits (100) to ensure rounding doesnt infect the MSB 5 bits
    for (int b = 3 * 5; b < 3 * 8; b++) {
        channel[b % 3] = channel[b % 3] + pow(2.0, -b/3 - 1) * bits[b];
        //cout << "channel " << b % 3 << ": " << pow(2, -b / 3 - 1) << "*" << bits[b] << endl;
    }
    
    
    float4 outputColor = float4(float3(channel[0], channel[1], channel[2]), 1.0);
	//float4 outputColor = float4(float3(depth), 1.0);
	
	outputTexture.write(outputColor, gid);
}
