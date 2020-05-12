using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class PositionReporterContro : MonoBehaviour
{
    [Header("Planes")]
    [SerializeField]
    GameObject grassPlane;
    MeshRenderer grassRenderer;

    [SerializeField]
    GameObject lastPlane;
    MeshRenderer DebugRenderer;
    [Header("Shader")]
    [SerializeField]
    ComputeShader textureCompute;
    [Header("Behaviours")]
    [SerializeField]
    [Range(0, 1)]
    float circleDistance = 0.5f;
    [SerializeField]
    [Range(0, 1)]
    float speed = 0.5f;
    [SerializeField]
    [Range(0, 1)]
    float tailLength;
    //Render Textures
    public RenderTexture grassTexCurr;
    public RenderTexture grassTexLast;
    public RenderTexture slopeTexture;

    //Properties IDs
    int grassTexID = 0;
    int debugTexID = 0;
    
    //Movement Reset Control
    Vector3 initPosition = new Vector3(0.0f, 0.0f, 0.0f);

    //Kernel IDs
    int positionComputeID = 0;
    int texCopyID = 0;
    int slopeComputeID = 0;

    //Movement state
    Vector3 posAfterWritingTex;
    float deltaMovement = 0.0f;
    private void Awake()
    {
        //Set the grass renderer mat and set texture
        grassRenderer = grassPlane.GetComponent<MeshRenderer>();
        grassTexID = grassRenderer.material.shader.FindPropertyIndex("_MainTex");
        
        //Initialize all compute shader kernel IDs
        positionComputeID = textureCompute.FindKernel("CSMain");
        texCopyID = textureCompute.FindKernel("CopyTexture");
        slopeComputeID = textureCompute.FindKernel("ComputeSlope");

        //Create all render texture references used to store infomation of current frame,
        //last frame and final slop map
        grassTexCurr = new RenderTexture(1024, 1024, 0, RenderTextureFormat.R8);
        grassTexCurr.enableRandomWrite = true;
        grassTexCurr.Create();

        grassTexLast = new RenderTexture(1024, 1024, 0, RenderTextureFormat.R8);
        grassTexLast.enableRandomWrite = true;
        grassTexLast.Create();

        slopeTexture = new RenderTexture(1024, 1024, 0, RenderTextureFormat.RG16);
        slopeTexture.enableRandomWrite = true;
        slopeTexture.Create();

        //Set the properties of the texture compute kernel
        textureCompute.SetTexture(positionComputeID, "Result", grassTexCurr);
        textureCompute.SetFloat("gradientDistance", circleDistance);
        textureCompute.SetFloat("tailLength", tailLength);
        textureCompute.SetTexture(positionComputeID, "LastTex", grassTexLast);

        //Set the properties of texture copy kernel
        textureCompute.SetTexture(texCopyID, "Result", grassTexCurr);
        textureCompute.SetTexture(texCopyID, "LastTex", grassTexLast);

        //Set the properties of Compute Slope kernel
        textureCompute.SetTexture(slopeComputeID, "Result", grassTexCurr);
        textureCompute.SetTexture(slopeComputeID, "OutputSlope", slopeTexture);

        //Assign the debug plane
        DebugRenderer = lastPlane.GetComponent<MeshRenderer>();
        debugTexID = DebugRenderer.material.shader.FindPropertyIndex("_MainTex");
    }
    void Start()
    {
        initPosition = this.gameObject.transform.position;
    }

    void Update()
    {
        SimpleMovement();
        PositionTransfer();
        SetPlaneTex();
        deltaMovement = (this.gameObject.transform.position - posAfterWritingTex).magnitude;

        textureCompute.Dispatch(positionComputeID, 1024 / 16, 1024 / 16, 1);
        textureCompute.Dispatch(texCopyID, 1024 / 16, 1024 / 16, 1);
        textureCompute.Dispatch(slopeComputeID, 1024 / 16, 1024 / 16, 1);

        posAfterWritingTex = this.gameObject.transform.position;
    }

    void SimpleMovement()
    {
        this.gameObject.transform.Translate(new Vector3(Input.GetAxis("Horizontal") * speed,0.0f , Input.GetAxis("Vertical") * speed));
        if (Input.GetKey(KeyCode.R))
            this.gameObject.transform.position = initPosition;
    }
    void PositionTransfer()
    {
        Vector4 currPos = this.transform.position;
        currPos.y = currPos.z;
        Vector3 topRight = grassRenderer.bounds.max;
        Vector3 buttomLeft = grassRenderer.bounds.min;
        float width = topRight.x - buttomLeft.x;
        float height = topRight.z - buttomLeft.z;
        currPos = new Vector4((currPos.x + width / 2.0f) / width, (currPos.y + height / 2.0f) / height, 0, 0);
        textureCompute.SetVector("currentPosition", currPos);
    }
    void SetPlaneTex()
    {
        grassRenderer.material.SetTexture(grassTexID, grassTexCurr);
        DebugRenderer.material.SetTexture(debugTexID, slopeTexture);
    }
}
