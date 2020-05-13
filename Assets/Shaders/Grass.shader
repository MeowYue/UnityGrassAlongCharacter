Shader "Roystan/Grass"
{
    Properties
    {
		[Header(Shading)]
		_TopColor("Top Color", Color) = (1,1,1,1)
		_BottomColor("Bottom Color", Color) = (1,1,1,1)
		_TranslucentGain("Translucent Gain", Range(0,1)) = 0.5
		_BendRotationRandom("Bend Rotation Random", Range(0, 1)) = 0.2
		_BladeWidth("Blade Width", Float) = 0.05
		_BladeWidthRandom("Blade Width Random", Float) = 0.02
		_BladeHeight("Blade Height", Float) = 0.5
		_BladeHeightRandom("Blade Height Random", Float) = 0.3
		_TessellationUniform("Tessellation Uniform", Range(1, 64)) = 1
	}

		CGINCLUDE
	#include "UnityCG.cginc"
	#include "Autolight.cginc"
	#include "CustomTessellation.cginc"

	float _BendRotationRandom;
	float _BladeHeight;
	float _BladeHeightRandom;
	float _BladeWidth;
	float _BladeWidthRandom;

	//struct vertexInput {
	//		float4 vertex : POSITION;
	//		float3 normal : NORMAL;
	//		float4 tangent : TANGENT;
	//};
	//struct vertexOutput {
	//		float4 vertex : SV_POSITION;
	//		float3 normal : NORMAL;
	//		float4 tangent : TANGENT;
	//};
	struct geometryOutput {
		float4 pos : SV_POSITION;
		float2 uv : TEXCOORD0;
	};

	geometryOutput VertexOutput(float3 pos, float2 uv) {
		geometryOutput o;
		o.pos = UnityObjectToClipPos(pos);
		o.uv = uv;
		return o;
	}

	// Simple noise function, sourced from http://answers.unity.com/answers/624136/view.html
	// Extended discussion on this function can be found at the following link:
	// https://forum.unity.com/threads/am-i-over-complicating-this-random-function.454887/#post-2949326
	// Returns a number in the 0...1 range.
	float rand(float3 co)
	{
		return frac(sin(dot(co.xyz, float3(12.9898, 78.233, 53.539))) * 43758.5453);
	}


	float4x4 AngleAxis4x4(float angle, float3 axis)
	{
		float c, s;
		sincos(angle, s, c);

		float t = 1 - c;
		float x = axis.x;
		float y = axis.y;
		float z = axis.z;

		return float4x4(
			t * x * x + c, t * x * y - s * z, t * x * z + s * y, 0,
			t * x * y + s * z, t * y * y + c, t * y * z - s * x, 0,
			t * x * z - s * y, t * y * z + s * x, t * z * z + c, 0,
			0,0,0,1
			);
	}

	//vertexOutput vert(vertexInput v)
	//{
	//	vertexOutput o;
	//	o.vertex = v.vertex;
	//	o.normal = v.normal;
	//	o.tangent = v.tangent;
	//	return o;
	//}

	

	[maxvertexcount(3)]
	void geo(triangle vertexOutput IN[3] : SV_POSITION, inout TriangleStream<geometryOutput> triStream) {
		float4 pos = IN[0].vertex;

		float3 vNormal = IN[0].normal;
		float4 vTangent = IN[0].tangent;
		float3 vBinormal = cross(vNormal, vTangent) * vTangent.w;
		float4x4 tangentToLocal = float4x4(
			vTangent.x, vBinormal.x, vNormal.x,pos.x,
			vTangent.y, vBinormal.y, vNormal.y,pos.y,
			vTangent.z, vBinormal.z, vNormal.z,pos.z,
			0,0,0,1
		);

		float4x4 facingRotationMatrix = AngleAxis4x4(rand(pos) * UNITY_TWO_PI, float3(0, 0, 1));
		float4x4 bendRotationMatrix = AngleAxis4x4(rand(pos.zzx) * _BendRotationRandom * UNITY_PI * 0.5, float3(-1, 0, 0));
		float4x4 transformationMatrix = mul(mul(tangentToLocal, facingRotationMatrix),bendRotationMatrix);

		float height = (rand(pos.yyz) *2 - 1) * _BladeHeightRandom + _BladeHeight;
		float width = (rand(pos.xzy) * 2 - 1) * _BladeWidthRandom + _BladeWidth;

		triStream.Append(VertexOutput(mul(transformationMatrix, float4(width, 0, 0,1)),float2(0,0)));
		triStream.Append(VertexOutput(mul(transformationMatrix, float4(-width, 0, 0,1)),float2(1,0)));
		triStream.Append(VertexOutput(mul(transformationMatrix, float4(0, 0,height,1)),float2(0.5,1)));

	}

	ENDCG

    SubShader
    {
		Cull Off

        Pass
        {
			Tags
			{
				"RenderType" = "Opaque"
				"LightMode" = "ForwardBase"
			}

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
			#pragma geometry geo
			#pragma target 4.6
			#pragma hull hull
			#pragma domain domain
			#include "Lighting.cginc"

			float4 _TopColor;
			float4 _BottomColor;
			float _TranslucentGain;

			float4 frag (geometryOutput i, fixed facing : VFACE) : SV_Target
            {	
				return lerp(_BottomColor,_TopColor,i.uv.y);
            }
            ENDCG
        }
    }
}