using Godot;
using System;
using System.Collections.Generic;

namespace HeelKawn;

/// <summary>
/// C# implementation of JobManager for job processing
/// Migrated from GDScript for performance optimization
/// </summary>
public partial class CJobManager : Node
{
    private List<Dictionary> _jobs = new();
    private Dictionary<int, List<int>> _jobsByType = new();
    private int _nextJobId = 1;
    
    public override void _Ready()
    {
        GD.Print("CJobManager C# initialized successfully");
    }
    
    public int PostJob(Dictionary jobData)
    {
        int jobId = _nextJobId++;
        jobData["id"] = jobId;
        _jobs.Add(jobData);
        
        // Index by type
        if (jobData.ContainsKey("type"))
        {
            int type = (int)jobData["type"];
            if (!_jobsByType.ContainsKey(type))
            {
                _jobsByType[type] = new List<int>();
            }
            _jobsByType[type].Add(jobId);
        }
        
        return jobId;
    }
    
    public List<Dictionary> GetJobsByType(int type)
    {
        if (_jobsByType.ContainsKey(type))
        {
            List<Dictionary> result = new();
            foreach (int jobId in _jobsByType[type])
            {
                if (jobId >= 1 && jobId <= _jobs.Count)
                {
                    result.Add(_jobs[jobId - 1]);
                }
            }
            return result;
        }
        return new List<Dictionary>();
    }
    
    public List<Dictionary> GetAllJobs()
    {
        return _jobs;
    }
    
    public int GetJobCount()
    {
        return _jobs.Count;
    }
    
    public void ClaimJob(int jobId, int pawnId)
    {
        if (jobId >= 1 && jobId <= _jobs.Count)
        {
            _jobs[jobId - 1]["claimed_by"] = pawnId;
        }
    }
    
    public void Clear()
    {
        _jobs.Clear();
        _jobsByType.Clear();
        _nextJobId = 1;
    }
}
