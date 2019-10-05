using System;
using System.Collections.Generic;
using System.Linq;
using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Assertions;
using Random = System.Random;

[RequireComponent(typeof(MeshFilter))]
public class MeshGenerator : MonoBehaviour
{
    private MeshFilter _filter;
    private Mesh _mesh;
    private List<Vector3> _centerPoints;

    private List<Vector3> _vertices;
    private List<int> _triangles;
    private List<Vector3> _normals;

    /// <summary>
    /// Executed by Unity upon object initialization. <see cref="https://docs.unity3d.com/Manual/ExecutionOrder.html"/>
    /// </summary>
    private void Awake()
    {
        _filter = GetComponent<MeshFilter>();
        _mesh = _filter.mesh = new Mesh();
        _mesh.MarkDynamic();

        _centerPoints = new List<Vector3>();
        var rng = new Random();
        for (int i = 0; i < 4; i++)
        {
            _centerPoints.Add(new Vector3(
                (float) rng.NextDouble() * 0.5f + 0.25f, 
                (float) rng.NextDouble() * 0.5f + 0.25f, 
                (float) rng.NextDouble() * 0.5f + 0.25f));
        }

        _vertices = new List<Vector3>();
        _triangles = new List<int>();
        _normals = new List<Vector3>();
        
        const float minCoord = 0.0f;
        const float maxCoord = 1.0f;
        const int cubesCount = 100;
        const float coordStep = (maxCoord - minCoord) / cubesCount;
        
        for (var ci = 0; ci < cubesCount; ci++)
        {
            for (var cj = 0; cj < cubesCount; cj++)
            {
                for (var ck = 0; ck < cubesCount; ck++)
                {
                    float3 cubeStartCoords = new Vector3(
                        minCoord + ci * coordStep,
                        minCoord + cj * coordStep,
                        minCoord + ck * coordStep);

                    var cubeValues = new List<float>();
                    int caseMask = 0;
                    for (int vertexId = 0; vertexId < CubeVertices.Length; vertexId++)
                    {
                        float3 cubeVertex = CubeVertices[vertexId];
                        float3 coords = cubeStartCoords + cubeVertex * coordStep;
                        float value = MarchingCubesFunction(coords);
                        int caseMaskDelta = (value >= 0 ? 1 : 0) << vertexId;
                        Assert.IsTrue((caseMask & caseMaskDelta) == 0);
                        
                        if (cubesCount <= 2)
                        {
                            Debug.Log($"" +
                                      $"Cube [{ci} {cj} {ck}]" +
                                      $"Id: {vertexId}, " +
                                      $"Coords: {coords}, " +
                                      $"Value: {value}");
                        }
                        
                        cubeValues.Add(value);
                        caseMask |= caseMaskDelta;
                    }
                    Assert.IsTrue(caseMask < 256);

                    int trianglesCount = MarchingCubes.Tables.CaseToTrianglesCount[caseMask];
                    var caseVertices = MarchingCubes.Tables.CaseToVertices[caseMask];

                    if (cubesCount == 1)
                    {
                        Debug.Log(caseMask);
                    }
                    
                    for (int caseTriangleIdx = 0; caseTriangleIdx < trianglesCount; caseTriangleIdx++)
                    {
                        int3 triangleEdges = caseVertices[caseTriangleIdx];
                        for (int edgeIdx = 0; edgeIdx < 3; edgeIdx++)
                        {
                            int edgeId = triangleEdges[edgeIdx];
                            float3 vertexCoords = cubeStartCoords + InterpolateOnEdge(cubeValues, edgeId) * coordStep;
                            _triangles.Add(_vertices.Count);
                            _vertices.Add(vertexCoords);
                            _normals.Add(ComputeNormal(vertexCoords, coordStep));
                            if (cubesCount <= 2)
                            {
                                Debug.Log($"" +
                                          $"Cube: [{ci} {cj} {ck}]," +
                                          $"Vertex: {vertexCoords}, " +
                                          $"Triangle:  {caseTriangleIdx}, " +
                                          $"Edge: {edgeIdx}");
                            }
                        }
                    }
                }
            }
        }
    }
    
    private static readonly float3[] CubeVertices =
    {
        new float3(0, 0, 0), // 0
        new float3(0, 1, 0), // 1
        new float3(1, 1, 0), // 2
        new float3(1, 0, 0), // 3
        new float3(0, 0, 1), // 4
        new float3(0, 1, 1), // 5
        new float3(1, 1, 1), // 6
        new float3(1, 0, 1), // 7
    };
    
    private static readonly int2[] EdgeIdToVertices =
    {
        new int2(0, 1), // 0
        new int2(1, 2), // 1
        new int2(2, 3), // 2
        new int2(3, 0), // 3
        new int2(4, 5), // 4
        new int2(5, 6), // 5
        new int2(6, 7), // 6
        new int2(7, 4), // 7
        new int2(0, 4), // 8
        new int2(1, 5), // 9
        new int2(2, 6), // 10
        new int2(3, 7), // 11
    };

    private float MarchingCubesFunction(Vector3 point)
    {
        const float radius = 0.1f;
        const float radiusSqr = radius * radius;

        // return 0.5f - point.y;
        float result = 0f;
        foreach (var center in _centerPoints)
        {
            float distSqr = (center - point).sqrMagnitude;
            if (distSqr == 0f)
            {
                result = 1e9f;
                break;
            }

            result += radiusSqr / distSqr;
        }
        return result - 1f;
    }

    /// <summary>
    /// Executed by Unity on every first frame <see cref="https://docs.unity3d.com/Manual/ExecutionOrder.html"/>
    /// </summary>
    private void Update()
    {
        // Here unity automatically assumes that vertices are points and hence will be represented as (x, y, z, 1) in homogenous coordinates
        _mesh.SetVertices(_vertices);
        _mesh.SetNormals(_normals);
        _mesh.SetTriangles(_triangles, 0);

        // Upload mesh data to the GPU
        _mesh.UploadMeshData(false);
    }
    
    private static float3 InterpolateOnEdge(List<float> cubeValues, int edgeId)
    {
        int zeroVertex = EdgeIdToVertices[edgeId].x;
        int oneVertex = EdgeIdToVertices[edgeId].y;
        float valueAtZero = cubeValues[zeroVertex];
        float valueAtOne = cubeValues[oneVertex];
        Assert.AreNotEqual(valueAtOne >= 0, valueAtZero >= 0);
        float shift = Math.Abs(valueAtZero / (valueAtOne - valueAtZero));
//        Debug.Log(shift);
        Assert.IsTrue(shift >= 0);
        Assert.IsTrue(shift <= 1.0f);
        
        float3 zeroCoords = new float3(CubeVertices[zeroVertex]);
        float3 oneCoords = new float3(CubeVertices[oneVertex]);
        return zeroCoords + (oneCoords - zeroCoords) * shift;
    }

    private float3 ComputeNormal(float3 point, float coordStep)
    {
        float3 dx = new Vector3(coordStep / 10f, 0f, 0f);
        float3 dy = new Vector3(0f, coordStep / 10f, 0f);
        float3 dz = new Vector3(0f, 0f, coordStep / 10f);
        return new Vector3(
            MarchingCubesFunction(point - dx) - MarchingCubesFunction(point + dx),
            MarchingCubesFunction(point - dy) - MarchingCubesFunction(point + dy),
            MarchingCubesFunction(point - dz) - MarchingCubesFunction(point + dz)
        ).normalized;
    }
}