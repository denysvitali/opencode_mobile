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

const sseClients = new Set<ReadableStreamDefaultController>();

function generateId(prefix: string): string {
  return `${prefix}-${Date.now()}-${++sessionCounter}`;
}

function createSession(body: any, directory?: string) {
  const id = generateId('session');
  const now = Date.now();
  const sessionPath = directory || body?.directory || '/test';
  const session = {
    id,
    parentID: body?.parentID || null,
    title: body?.title || 'New Session',
    description: null,
    status: 'idle',
    time: {
      created: now,
    },
    path: { cwd: sessionPath },
    projectID: null,
    permission: body?.permission || null,
  };
  sessions.set(id, session);
  messages.set(id, []);
  
  emitEvent('session.created', { session });
  
  return session;
}

function emitEvent(eventType: string, data: any) {
  const sseData = `event: ${eventType}\ndata: ${JSON.stringify(data)}\n\n`;
  const encoder = new TextEncoder();
  const encoded = encoder.encode(sseData);
  
  for (const client of sseClients) {
    try {
      client.enqueue(encoded);
    } catch (e) {
      sseClients.delete(client);
    }
  }
}

function sseHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, PATCH, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, Accept',
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache',
    'Connection': 'keep-alive',
  };
}

function handleSSE(req: Request): Response {
  const stream = new ReadableStream({
    start(controller) {
      sseClients.add(controller);
      
      // Send initial connection event
      const encoder = new TextEncoder();
      controller.enqueue(encoder.encode('event: connected\ndata: {"status":"connected"}\n\n'));
      
      // Heartbeat every 30 seconds to keep connection alive
      const heartbeat = setInterval(() => {
        try {
          controller.enqueue(encoder.encode(': heartbeat\n\n'));
        } catch (e) {
          clearInterval(heartbeat);
          sseClients.delete(controller);
        }
      }, 30000);
      
      req.signal.addEventListener('abort', () => {
        clearInterval(heartbeat);
        sseClients.delete(controller);
        try {
          controller.close();
        } catch (e) {}
      });
    },
    cancel() {
      // Client disconnected
    }
  });

  return new Response(stream, {
    headers: sseHeaders(),
  });
}

function corsHeaders(extraHeaders: Record<string, string> = {}) {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, PATCH, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, Accept',
    ...extraHeaders,
  };
}

function createMessage(sessionId: string, role: string, parts: any[], options: any = {}) {
  const now = Date.now();
  return {
    id: generateId('msg'),
    sessionID: sessionId,
    role: role,
    parts: parts.map((p: any) => ({
      id: generateId('part'),
      type: p.type || 'text',
      text: p.text || '',
      ...(p.tool ? { tool: p.tool } : {}),
      ...(p.file ? { file: p.file } : {}),
    })),
    time: {
      created: now,
      ...(options.completed ? { completed: now } : {}),
    },
    ...(options.parentID ? { parentID: options.parentID } : {}),
    ...(options.modelID ? { modelID: options.modelID } : {}),
    ...(options.providerID ? { providerID: options.providerID } : {}),
    ...(options.cost ? { cost: options.cost } : {}),
    ...(options.tokens ? { tokens: options.tokens } : {}),
    ...(options.error ? { error: options.error } : {}),
    ...(options.finish ? { finish: options.finish } : {}),
  };
}

async function handleRequest(req: Request): Promise<Response> {
  const url = new URL(req.url);
  const path = url.pathname;
  const method = req.method;
  const acceptHeader = req.headers.get('Accept') || '';

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

    // SSE endpoints - check Accept header or path
    const accept = req.headers.get('Accept') || '';
    
    // Global SSE events - /global/event
    if (path === '/global/event' && (method === 'GET' || accept.includes('text/event-stream'))) {
      return handleSSE(req);
    }
    
    // Project SSE events - /event (with optional directory query param)
    if (path === '/event' && (method === 'GET' || accept.includes('text/event-stream'))) {
      return handleSSE(req);
    }

    // Health check
    if (path === '/global/health') {
      return new Response(JSON.stringify({ status: 'ok' }), { 
        headers: { ...headers, 'Content-Type': 'application/json' } 
      });
    }
          }, 30000);
          
          req.signal.addEventListener('abort', () => {
            clearInterval(heartbeat);
            sseClients.delete(controller);
            try {
              controller.close();
            } catch (e) {}
          });
        },
        cancel() {
          // Client disconnected
        }
      });

      return new Response(stream, {
        headers: sseHeaders(),
      });
    }

    // Session list - GET /session
    if (path === '/session' && method === 'GET') {
      const url = new URL(req.url);
      const searchQuery = url.searchParams.get('search');
      const rootsOnly = url.searchParams.get('roots') === 'true';
      const limitParam = url.searchParams.get('limit');
      const directoryParam = url.searchParams.get('directory');
      
      let filteredSessions = Array.from(sessions.values());
      
      // Filter by search query (title contains search term)
      if (searchQuery) {
        filteredSessions = filteredSessions.filter((s: any) => 
          s.title && s.title.toLowerCase().includes(searchQuery.toLowerCase())
        );
      }
      
      // Filter by roots only (sessions without parentID)
      if (rootsOnly) {
        filteredSessions = filteredSessions.filter((s: any) => !s.parentID);
      }
      
      // Filter by directory (path matches)
      if (directoryParam) {
        filteredSessions = filteredSessions.filter((s: any) => 
          s.path && s.path.cwd === directoryParam
        );
      }
      
      // Apply limit
      if (limitParam) {
        const limit = parseInt(limitParam, 10);
        if (!isNaN(limit) && limit > 0) {
          filteredSessions = filteredSessions.slice(0, limit);
        }
      }
      
      return new Response(JSON.stringify(filteredSessions), {
        headers: { ...headers, 'Content-Type': 'application/json' },
      });
    }

    // Create session - POST /session
    if (path === '/session' && method === 'POST') {
      const body = await req.json();
      const url = new URL(req.url);
      const directory = url.searchParams.get('directory') || undefined;
      const session = createSession(body, directory);
      return new Response(JSON.stringify(session), {
        status: 201,
        headers: { ...headers, 'Content-Type': 'application/json' },
      });
    }

    // Session status - GET /session/status
    if (path === '/session/status' && method === 'GET') {
      const statusMap: Record<string, string> = {};
      for (const [id, session] of sessions) {
        statusMap[id] = session.status;
      }
      return new Response(JSON.stringify(statusMap), {
        headers: { ...headers, 'Content-Type': 'application/json' },
      });
    }

    // Get single session - GET /session/{sessionId}
    const sessionMatch = path.match(/^\/session\/([\w-]+)$/);
    if (sessionMatch && method === 'GET') {
      const id = sessionMatch[1];
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

    // Update session - PATCH /session/{sessionId}
    if (sessionMatch && method === 'PATCH') {
      const id = sessionMatch[1];
      const session = sessions.get(id);
      if (!session) {
        return new Response(JSON.stringify({ error: 'Session not found' }), {
          status: 404,
          headers: { ...headers, 'Content-Type': 'application/json' },
        });
      }
      const body = await req.json();
      if (body.title !== undefined) {
        session.title = body.title;
      }
      if (body.time?.archived !== undefined) {
        session.time.archived = body.time.archived;
        session.status = 'archived';
        session.archivedAt = body.time.archived;
      }
      
      emitEvent('session.updated', { session });
      emitEvent('session.status', { sessionID: session.id, status: session.status });
      
      return new Response(JSON.stringify(session), {
        headers: { ...headers, 'Content-Type': 'application/json' },
      });
    }

    // Delete session - DELETE /session/{sessionId}
    if (sessionMatch && method === 'DELETE') {
      const id = sessionMatch[1];
      if (!sessions.has(id)) {
        return new Response(JSON.stringify({ error: 'Session not found' }), {
          status: 404,
          headers: { ...headers, 'Content-Type': 'application/json' },
        });
      }
      sessions.delete(id);
      messages.delete(id);
      
      emitEvent('session.deleted', { sessionID: id });
      
      return new Response(JSON.stringify(true), {
        headers: { ...headers, 'Content-Type': 'application/json' },
      });
    }

    // Get session children - GET /session/{sessionId}/children
    const childrenMatch = path.match(/^\/session\/([\w-]+)\/children$/);
    if (childrenMatch && method === 'GET') {
      const parentId = childrenMatch[1];
      const children = Array.from(sessions.values()).filter(
        (s) => s.parentID === parentId
      );
      return new Response(JSON.stringify(children), {
        headers: { ...headers, 'Content-Type': 'application/json' },
      });
    }

    // Init session - POST /session/{sessionId}/init
    const initMatch = path.match(/^\/session\/([\w-]+)\/init$/);
    if (initMatch && method === 'POST') {
      const id = initMatch[1];
      const session = sessions.get(id);
      if (!session) {
        return new Response(JSON.stringify({ error: 'Session not found' }), {
          status: 404,
          headers: { ...headers, 'Content-Type': 'application/json' },
        });
      }
      session.status = 'running';
      
      emitEvent('session.status', { sessionID: id, status: 'running' });
      
      return new Response(JSON.stringify(true), {
        headers: { ...headers, 'Content-Type': 'application/json' },
      });
    }

    // Cancel session - POST /session/{sessionId}/cancel
    const cancelMatch = path.match(/^\/session\/([\w-]+)\/cancel$/);
    if (cancelMatch && method === 'POST') {
      const id = cancelMatch[1];
      const session = sessions.get(id);
      if (!session) {
        return new Response(JSON.stringify({ error: 'Session not found' }), {
          status: 404,
          headers: { ...headers, 'Content-Type': 'application/json' },
        });
      }
      session.status = 'idle';
      
      emitEvent('session.status', { sessionID: id, status: 'idle' });
      
      return new Response(JSON.stringify(true), {
        headers: { ...headers, 'Content-Type': 'application/json' },
      });
    }

    // Get session messages - GET /session/{sessionId}/message
    const messageMatch = path.match(/^\/session\/([\w-]+)\/message$/);
    if (messageMatch && method === 'GET') {
      const id = messageMatch[1];
      if (!sessions.has(id)) {
        return new Response(JSON.stringify({ error: 'Session not found' }), {
          status: 404,
          headers: { ...headers, 'Content-Type': 'application/json' },
        });
      }
      const sessionMessages = messages.get(id) || [];
      
      // Check if client expects "info" wrapper format
      const returnWrapped = url.searchParams.get('wrapped') === 'true' || 
        url.searchParams.get('format') === 'wrapped';
      
      if (returnWrapped) {
        // Return in "info" wrapper format
        const wrapped = sessionMessages.map((msg: any) => ({
          info: {
            id: msg.id,
            sessionID: msg.sessionID,
            role: msg.role,
            time: msg.time,
            modelID: msg.modelID,
            providerID: msg.providerID,
            cost: msg.cost,
            tokens: msg.tokens,
            error: msg.error,
            finish: msg.finish,
          },
          parts: msg.parts,
        }));
        return new Response(JSON.stringify(wrapped), {
          headers: { ...headers, 'Content-Type': 'application/json' },
        });
      }
      
      return new Response(JSON.stringify(sessionMessages), {
        headers: { ...headers, 'Content-Type': 'application/json' },
      });
    }

    // Send message - POST /session/{sessionId}/message (with streaming support)
    if (messageMatch && method === 'POST') {
      const id = messageMatch[1];
      if (!sessions.has(id)) {
        return new Response(JSON.stringify({ error: 'Session not found' }), {
          status: 404,
          headers: { ...headers, 'Content-Type': 'application/json' },
        });
      }
      const session = sessions.get(id);
      const body = await req.json();
      
      // Handle both 'parts' and 'content' formats
      let text = '';
      if (body.parts && Array.isArray(body.parts)) {
        text = body.parts.map((p: any) => p.text || '').join('');
      } else if (body.content) {
        text = body.content;
      }
      
      const modelInfo = body.model || {};
      const inputParts = body.parts || [{ type: 'text', text: text }];
      
      // Create user message with proper format
      const userMessage = createMessage(id, 'user', inputParts, {
        modelID: modelInfo.modelID,
        providerID: modelInfo.providerID,
      });
      
      const sessionMessages = messages.get(id) || [];
      sessionMessages.push(userMessage);
      messages.set(id, sessionMessages);
      
      emitEvent('message.updated', { message: userMessage, sessionID: id });
      
      // Check for streaming request
      if (acceptHeader.includes('text/event-stream')) {
        const encoder = new TextEncoder();
        const stream = new ReadableStream({
          async start(controller) {
            // Send initial user message
            const userMsgData = JSON.stringify({
              ...userMessage,
              sessionID: id,
            });
            controller.enqueue(encoder.encode(`data: ${userMsgData}\n\n`));
            
            // Update session status to running
            if (session) {
              session.status = 'running';
              emitEvent('session.status', { sessionID: id, status: 'running' });
            }
            
            // Simulate some processing delay
            await new Promise(r => setTimeout(r, 50));
            
            // Create and send assistant message in parts
            const responseText = `Mock response to: ${text}`;
            
            // Create initial assistant message (empty)
            const assistantMessage = createMessage(id, 'assistant', [
              { type: 'text', text: '' }
            ], {
              modelID: modelInfo.modelID,
              providerID: modelInfo.providerID,
            });
            
            sessionMessages.push(assistantMessage);
            messages.set(id, sessionMessages);
            
            // Stream the response word by word
            const words = responseText.split(' ');
            let currentText = '';
            
            for (let i = 0; i < words.length; i++) {
              currentText += (i > 0 ? ' ' : '') + words[i];
              
              // Update the message with current text
              assistantMessage.parts = [{ type: 'text', text: currentText }];
              
              const isLast = i === words.length - 1;
              
              // Send streaming update
              const assistantData = JSON.stringify({
                ...assistantMessage,
                sessionID: id,
                time: isLast ? { created: assistantMessage.time.created, completed: Date.now() } : assistantMessage.time,
                ...(isLast ? { cost: 0.001, tokens: { input: 10, output: words.length, total: 10 + words.length }, finish: 'stop' } : {}),
              });
              controller.enqueue(encoder.encode(`data: ${assistantData}\n\n`));
              
              // Small delay between chunks
              await new Promise(r => setTimeout(r, 20));
            }
            
            // Set session back to idle
            if (session) {
              session.status = 'idle';
              emitEvent('session.status', { sessionID: id, status: 'idle' });
            }
            
            controller.close();
          }
        });
        
        return new Response(stream, {
          headers: {
            ...headers,
            'Content-Type': 'text/event-stream',
            'Cache-Control': 'no-cache',
            'Connection': 'keep-alive',
          },
        });
      }
      
      // Non-streaming: create mock assistant response immediately
      const responseText = `Mock response to: ${text}`;
      const assistantMessage = createMessage(id, 'assistant', [
        { type: 'text', text: responseText }
      ], {
        completed: true,
        modelID: modelInfo.modelID,
        providerID: modelInfo.providerID,
        cost: 0.001,
        tokens: { input: 10, output: responseText.split(' ').length, total: 10 + responseText.split(' ').length },
        finish: 'stop',
      });
      sessionMessages.push(assistantMessage);
      
      // Update session status briefly
      if (session) {
        session.status = 'running';
        emitEvent('session.status', { sessionID: id, status: 'running' });
        
        // After a short delay, set back to idle
        setTimeout(() => {
          session.status = 'idle';
          emitEvent('session.status', { sessionID: id, status: 'idle' });
        }, 500);
      }
      
      return new Response(JSON.stringify({ ...userMessage, sessionID: id }), {
        status: 201,
        headers: { ...headers, 'Content-Type': 'application/json' },
      });
    }

    // Get session diff - GET /session/{sessionId}/diff
    const diffMatch = path.match(/^\/session\/([\w-]+)\/diff$/);
    if (diffMatch && method === 'GET') {
      const id = diffMatch[1];
      if (!sessions.has(id)) {
        return new Response(JSON.stringify({ error: 'Session not found' }), {
          status: 404,
          headers: { ...headers, 'Content-Type': 'application/json' },
        });
      }
      
      const mockDiff = {
        files: [
          {
            path: 'test/example.txt',
            status: 'modified',
            additions: 5,
            deletions: 2,
            hunks: [
              {
                oldStart: 1,
                oldLines: 10,
                newStart: 1,
                newLines: 13,
                content: '@@ -1,10 +1,13 @@\n some content\n+added line 1\n+added line 2\n-removed line\n changed line\n'
              }
            ]
          },
          {
            path: 'test/new_file.txt',
            status: 'added',
            additions: 15,
            deletions: 0,
            hunks: [
              {
                oldStart: 0,
                oldLines: 0,
                newStart: 1,
                newLines: 15,
                content: '@@ -0,0 +1,15 @@\n+new file content\n+line 2\n'
              }
            ]
          }
        ],
        totalAdditions: 20,
        totalDeletions: 2,
      };
      
      return new Response(JSON.stringify(mockDiff), {
        headers: { ...headers, 'Content-Type': 'application/json' },
      });
    }

    // Get session todos - GET /session/{sessionId}/todo
    const todoMatch = path.match(/^\/session\/([\w-]+)\/todo$/);
    if (todoMatch && method === 'GET') {
      const id = todoMatch[1];
      if (!sessions.has(id)) {
        return new Response(JSON.stringify({ error: 'Session not found' }), {
          status: 404,
          headers: { ...headers, 'Content-Type': 'application/json' },
        });
      }
      
      const mockTodos = [
        {
          id: 'todo-1',
          content: 'Implement user authentication',
          status: 'completed',
          priority: 'high',
          time: Date.now() - 3600000,
        },
        {
          id: 'todo-2',
          content: 'Add error handling for API calls',
          status: 'in_progress',
          priority: 'medium',
          time: Date.now() - 1800000,
        },
        {
          id: 'todo-3',
          content: 'Write unit tests for models',
          status: 'pending',
          priority: 'low',
          time: Date.now(),
        },
      ];
      
      return new Response(JSON.stringify(mockTodos), {
        headers: { ...headers, 'Content-Type': 'application/json' },
      });
    }

    // Config endpoint
    if (path === '/config' && method === 'GET') {
      return new Response(JSON.stringify({
        provider: { type: 'mock' },
        theme: 'system',
      }), {
        headers: { ...headers, 'Content-Type': 'application/json' },
      });
    }

    // Config PATCH endpoint
    if (path === '/config' && method === 'PATCH') {
      return new Response(JSON.stringify({
        provider: { type: 'mock' },
        theme: 'dark',
      }), {
        headers: { ...headers, 'Content-Type': 'application/json' },
      });
    }

    // Global config endpoint
    if (path === '/global/config' && method === 'GET') {
      return new Response(JSON.stringify({
        provider: { type: 'mock' },
        theme: 'system',
      }), {
        headers: { ...headers, 'Content-Type': 'application/json' },
      });
    }

    // Global config PATCH endpoint
    if (path === '/global/config' && method === 'PATCH') {
      return new Response(JSON.stringify({
        provider: { type: 'mock' },
        theme: 'dark',
      }), {
        headers: { ...headers, 'Content-Type': 'application/json' },
      });
    }

    // Tool IDs endpoint
    if (path === '/experimental/tool/ids' && method === 'GET') {
      return new Response(JSON.stringify({
        ids: ['tool-1', 'tool-2', 'tool-3'],
      }), {
        headers: { ...headers, 'Content-Type': 'application/json' },
      });
    }

    // Providers endpoint
    if (path === '/config/providers' && method === 'GET') {
      return new Response(JSON.stringify({
        providers: [
          {
            id: 'mock',
            name: 'Mock Provider',
            configured: true,
            models: {
              'mock-gpt-4': {
                name: 'Mock GPT-4',
                limit: { context: 8192, output: 4096 },
                cost: { input: 0.001, output: 0.002 },
              },
            },
          },
        ],
        default: { provider: 'mock', model: 'mock-gpt-4' },
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

    // Current project endpoint
    if (path === '/project/current' && method === 'GET') {
      return new Response(JSON.stringify(
        { id: 'proj-1', name: 'Test Project', worktree: '/test' }
      ), {
        headers: { ...headers, 'Content-Type': 'application/json' },
      });
    }

    // Global dispose endpoint
    if (path === '/global/dispose' && method === 'POST') {
      return new Response(JSON.stringify(true), {
        headers: { ...headers, 'Content-Type': 'application/json' },
      });
    }

    // Instance dispose endpoint
    if (path === '/instance/dispose' && method === 'POST') {
      return new Response(JSON.stringify(true), {
        headers: { ...headers, 'Content-Type': 'application/json' },
      });
    }

    // Permissions endpoint
    if (path === '/permission' && method === 'GET') {
      return new Response(JSON.stringify([]), {
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
