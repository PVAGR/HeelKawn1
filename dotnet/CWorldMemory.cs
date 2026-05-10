using Godot;
using System;
using System.Collections.Generic;

namespace HeelKawn;

/// <summary>
/// C# implementation of WorldMemory for event processing
/// Migrated from GDScript for performance optimization
/// </summary>
public partial class CWorldMemory : Node
{
    private List<Dictionary> _events = new();
    private Dictionary<int, List<int>> _tileEvents = new();
    private int _nextEventId = 1;
    
    public override void _Ready()
    {
        GD.Print("CWorldMemory C# initialized successfully");
    }
    
    public int RecordEvent(Dictionary eventData)
    {
        int eventId = _nextEventId++;
        eventData["id"] = eventId;
        _events.Add(eventData);
        
        // Index by tile if position exists
        if (eventData.ContainsKey("tile_pos"))
        {
            Vector2I pos = (Vector2I)eventData["tile_pos"];
            int tileKey = pos.X * 100000 + pos.Y;
            
            if (!_tileEvents.ContainsKey(tileKey))
            {
                _tileEvents[tileKey] = new List<int>();
            }
            _tileEvents[tileKey].Add(eventId);
        }
        
        return eventId;
    }
    
    public List<Dictionary> GetEventsForTile(Vector2I position)
    {
        int tileKey = position.X * 100000 + position.Y;
        
        if (_tileEvents.ContainsKey(tileKey))
        {
            List<Dictionary> result = new();
            foreach (int eventId in _tileEvents[tileKey])
            {
                if (eventId >= 1 && eventId <= _events.Count)
                {
                    result.Add(_events[eventId - 1]);
                }
            }
            return result;
        }
        return new List<Dictionary>();
    }
    
    public List<Dictionary> GetAllEvents()
    {
        return _events;
    }
    
    public int GetEventCount()
    {
        return _events.Count;
    }
    
    public void Clear()
    {
        _events.Clear();
        _tileEvents.Clear();
        _nextEventId = 1;
    }
}
