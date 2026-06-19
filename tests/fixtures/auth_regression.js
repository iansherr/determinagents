// Mock Auth Regression Fixture for REGRESSION_SURFACE audit tests

export async function loginFlow(credentials) {
  try {
    const response = await fetch('/api/v1/auth/login', {
      method: 'POST',
      body: JSON.stringify(credentials)
    });
    
    if (response.ok) {
      const data = await response.json();
      
      // 1. Loose contract / API response parsing without fallback defaults
      const token = data.token;
      const sessionId = data.session.id; // Potential crash if 'session' object is missing or partial
      const user = data.user;
      
      // 2. Duplicated storage state / credential aliases
      localStorage.setItem('authToken', token);
      localStorage.setItem('sessionId', sessionId);
      localStorage.setItem('fleetcrewSessionId', sessionId); // Duplicate alias
      localStorage.setItem('userName', user.name || user.email);
      
      return true;
    }
  } catch (e) {
    // 3. Broad Catch swallowing error and triggering aggressive global side-effects (erasure)
    console.error("Login failed", e);
    localStorage.removeItem('authToken');
    localStorage.removeItem('sessionId');
    localStorage.removeItem('fleetcrewSessionId');
    window.location.href = '/login';
  }
  return false;
}

// 4. Overlapping state & fallback ladder pattern
export function getSessionHeaders() {
  // Fallback ladder resolving credential aliases
  const token = localStorage.getItem('authToken');
  const sessionId = localStorage.getItem('sessionId') || localStorage.getItem('fleetcrewSessionId') || '';
  
  if (token) {
    return { 'Authorization': `Bearer ${token}` };
  } else if (sessionId) {
    return { 'X-Session-ID': sessionId };
  }
  return {};
}

export async function passiveProfileRefresh() {
  try {
    const headers = getSessionHeaders();
    const resp = await fetch('/api/v1/users/me', { headers });
    
    // 5. Loose response boundary
    const me = await resp.json();
    return me.user || me;
  } catch (e) {
    // Broad catch triggers global logout on passive failure (regression trap!)
    console.warn("Could not refresh profile:", e);
    localStorage.removeItem('authToken');
    localStorage.removeItem('sessionId');
    localStorage.removeItem('fleetcrewSessionId');
    window.location.href = '/login?expired=true';
  }
}
