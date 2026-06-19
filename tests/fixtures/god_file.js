// Mock God-File Fixture for STRUCTURAL_ENTROPY audit tests

import React, { useState, useEffect } from 'react';
import axios from 'axios';

// Category Mix: UI + State + I/O + Dispatch + Parsing + Persistence
export function AgentWorkspace({ workspaceId }) {
  // 1. State Management
  const [workspace, setWorkspace] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [session, setSession] = useState(localStorage.getItem('sessionId'));

  // 2. Direct Side Effects & Persistence I/O
  useEffect(() => {
    async function load() {
      try {
        setLoading(true);
        // Direct I/O call
        const res = await axios.get(`/api/v1/workspaces/${workspaceId}`, {
          headers: { 'X-Session-ID': session }
        });
        
        // 3. Data Shaping / Parsing
        const parsedData = normalizeWorkspace(res.data);
        setWorkspace(parsedData);
        
        // Direct storage write
        localStorage.setItem(`ws_cache_${workspaceId}`, JSON.stringify(parsedData));
      } catch (err) {
        setError(err.message);
        // 4. Broad Catch triggering global side effects
        if (err.response && err.response.status === 401) {
          localStorage.removeItem('sessionId');
          localStorage.removeItem('fleetcrewSessionId');
          window.location.href = '/login';
        }
      } finally {
        setLoading(false);
      }
    }
    load();
  }, [workspaceId, session]);

  // 5. Data Shaping logic inside UI file
  function normalizeWorkspace(data) {
    if (!data) return {};
    return {
      id: data.id || data.uuid,
      name: data.display_name || data.name || 'Untitled Workspace',
      owner: data.owner_details ? data.owner_details.email : 'unknown'
    };
  }

  // 6. UI Rendering combined with inline state modification
  return (
    <div className="workspace-container">
      {loading ? (
        <p>Loading...</p>
      ) : error ? (
        <p className="error">Error: {error}</p>
      ) : (
        <div>
          <h1>{workspace.name}</h1>
          <p>Owner: {workspace.owner}</p>
          <button onClick={() => {
            // Inline state mutation & persistence side effect
            const newName = prompt('New Name:');
            if (newName) {
              setWorkspace({ ...workspace, name: newName });
              localStorage.setItem(`ws_cache_${workspaceId}`, JSON.stringify({ ...workspace, name: newName }));
            }
          }}>
            Rename
          </button>
        </div>
      )}
    </div>
  );
}
