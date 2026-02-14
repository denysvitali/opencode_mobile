#!/usr/bin/env bun
/**
 * Mock OpenCode Server for testing OpenCode Mobile Client
 * 
 * Provides a minimal REST API compatible with OpenCode client.
 * Returns fake sessions, messages, and handles basic operations.
 */

const PORT = parseInt(process.env.OPENCODE_SERVER_PORT || "4096");

const sessions = new Map<string, any>();
const messages = new Map<string, any[]>();
let sessionCounter = 0;
let messageCounter = 0;

function generateId(prefix: string): string {
  return `${prefix}-${Date.now()}-${++sessionCounter}`;
}

function createSession(body: any) {
  const id = generateId('session');
  const session = {
    id,
    title: body?.title || 'New Session',
    status: 'idle',
    time: {
      created: Date.now(),
    },
    path: { cwd: '/test' },
    parentID: body?.parentID || null,
  };
  sessions.set(id, session);
  messages.set(id, []);
  return session;
}

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  };
}

async function handleRequest(req: Request): Promise<Response> {
  const url = new URL(req.url);
  const path = url.pathname;
  const method = req.method;

  if (method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders() });
  }

  const headers = corsHeaders();

  try {
    // Health check
    if (path === '/global/health') {
      return new Response(JSON.stringify({ status: 'ok' }), { 
        headers: { ...headers, 'Content-Type': 'application/json' } 
      });
    }

    // Session list
    if (path === '/session' && method === 'GET') {
      const allSessions = Array.from(sessions.values());
      return new Response(JSON.stringify(allSessions), {
        headers: { ...headers, 'Content-Type': 'application/json' },
      });
    }

    // Create session
    if (path === '/session' && method === 'POST') {
      const body = await req.json();
      const session = createSession(body);
      return new Response(JSON.stringify(session), {
        status: 201,
        headers: { ...headers, 'Content-Type': 'application/json' },
      });
    }

    // Get session
    if (path.match(/^\/session\/[\w-]+$/) && method === 'GET') {
      const id = path.split('/')[2];
      const session = sessions.get(id);
      if (!session) {
        return new Response(JSON.stringify({ error: 'Session not found' }), {
          status: 404,
          headers: { ...headers, 'Content-Type': 'application/json' },
        });
      }
      return new Response(JSON.stringify(session), {
        headers: { ...headers, 'Content-Type': 'application/json' },
      });
    }

    // Update session
    if (path.match(/^\/session\/[\w-]+$/) && method === 'PUT') {
      const id = path.split('/')[2];
      const session = sessions.get(id);
      if (!session) {
        return new Response(JSON.stringify({ error: 'Session not found' }), {
          status: 404,
          headers: { ...headers, 'Content-Type': 'application/json' },
        });
      }
      const body = await req.json();
      if (body.title) session.title = body.title;
      if (body.time?.archived) {
        session.time.archived = body.time.archived;
        session.status = 'archived';
      }
      return new Response(JSON.stringify(session), {
        headers: { ...headers, 'Content-Type': 'application/json' },
      });
    }

    // Delete session
    if (path.match(/^\/session\/[\w-]+$/) && method === 'DELETE') {
      const id = path.split('/')[2];
      sessions.delete(id);
      messages.delete(id);
      return new Response(JSON.stringify(true), {
        headers: { ...headers, 'Content-Type': 'application/json' },
      });
    }

    // Get session messages
    if (path.match(/^\/session\/[\w-]+\/message$/) && method === 'GET') {
      const id = path.split('/')[2];
      const sessionMessages = messages.get(id) || [];
      return new Response(JSON.stringify(sessionMessages), {
        headers: { ...headers, 'Content-Type': 'application/json' },
      });
    }

    // Send message (create message)
    if (path.match(/^\/session\/[\w-]+\/message$/) && method === 'POST') {
      const id = path.split('/')[2];
      const body = await req.json();
      const messageId = generateId('msg');
      const message = {
        id: messageId,
        sessionID: id,
        role: 'user',
        parts: [{ type: 'text', text: body.content || '' }],
        time: { created: Date.now() },
      };
      const sessionMessages = messages.get(id) || [];
      sessionMessages.push(message);
      messages.set(id, sessionMessages);
      
      // Create mock assistant response
      const assistantMessage = {
        id: generateId('msg'),
        sessionID: id,
        role: 'assistant',
        parts: [{ type: 'text', text: `Mock response to: ${body.content}` }],
        time: { created: Date.now() },
      };
      sessionMessages.push(assistantMessage);
      
      return new Response(JSON.stringify(message), {
        status: 201,
        headers: { ...headers, 'Content-Type': 'application/json' },
      });
    }

    // Config endpoint
    if (path === '/config' && method === 'GET') {
      return new Response(JSON.stringify({
        provider: { type: 'mock' },
      }), {
        headers: { ...headers, 'Content-Type': 'application/json' },
      });
    }

    // Projects endpoint
    if (path === '/project' && method === 'GET') {
      return new Response(JSON.stringify([
        { id: 'proj-1', name: 'Test Project', worktree: '/test' }
      ]), {
        headers: { ...headers, 'Content-Type': 'application/json' },
      });
    }

    // Session status
    if (path === '/sessionStatus' && method === 'GET') {
      const statusMap: Record<string, string> = {};
      for (const [id, session] of sessions) {
        statusMap[id] = session.status;
      }
      return new Response(JSON.stringify(statusMap), {
        headers: { ...headers, 'Content-Type': 'application/json' },
      });
    }

    // Default: 404
    return new Response(JSON.stringify({ error: 'Not found', path }), {
      status: 404,
      headers: { ...headers, 'Content-Type': 'application/json' },
    });

  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...headers, 'Content-Type': 'application/json' },
    });
  }
}

console.log(`Mock OpenCode Server starting on port ${PORT}...`);

// Create initial session for testing
createSession({ title: 'Test Session' });

Bun.serve({
  port: PORT,
  fetch: handleRequest,
});

console.log(`Mock OpenCode Server running on http://localhost:${PORT}`);
