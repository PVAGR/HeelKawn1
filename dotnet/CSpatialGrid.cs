using Godot;
using System;
using System.Collections.Generic;

namespace HeelKawn;

/// <summary>
/// C# implementation of SpatialGrid for O(1) neighbor queries
/// Migrated from GDScript for performance optimization
/// </summary>
public partial class CSpatialGrid : Node
{
    private Dictionary<int, List<int>> _spatialIndex = new();
    private int _chunkSize = 16;
    
    public override void _Ready()
    {
        GD.Print("CSpatialGrid C# initialized successfully");
    }
    
    public void InsertPawn(int pawnId, Vector2I position)
    {
        int chunkX = position.X / _chunkSize;
        int chunkY = position.Y / _chunkSize;
        int chunkKey = chunkX * 10000 + chunkY;
        
        if (!_spatialIndex.ContainsKey(chunkKey))
        {
            _spatialIndex[chunkKey] = new List<int>();
        }
        _spatialIndex[chunkKey].Add(pawnId);
    }
    
    public List<int> GetPawnsInChunk(Vector2I position)
    {
        int chunkX = position.X / _chunkSize;
        int chunkY = position.Y / _chunkSize;
        int chunkKey = chunkX * 10000 + chunkY;
        
        if (_spatialIndex.ContainsKey(chunkKey))
        {
            return _spatialIndex[chunkKey];
        }
        return new List<int>();
    }
    
    public void Clear()
    {
        _spatialIndex.Clear();
    }
    
    public int GetChunkSize()
    {
        return _chunkSize;
    }
    
    public void SetChunkSize(int size)
    {
        _chunkSize = size;
    }
}
