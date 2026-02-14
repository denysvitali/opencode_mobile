#!/usr/bin/env bun
/**
 * Mock LLM Server for testing OpenCode Mobile Client
 *
 * Provides a minimal OpenAI-compatible API that returns predictable responses.
 * No actual AI processing - just echo-style responses for integration testing.
 */

const PORT = parseInt(process.env.MOCK_LLM_PORT || "4097");

interface ChatMessage {
  role: "system" | "user" | "assistant";
  content: string;
}

interface ChatCompletionRequest {
  model: string;
  messages: ChatMessage[];
  stream?: boolean;
  tools?: unknown[];
  tool_choice?: unknown;
}

function generateResponseId(): string {
  return `mock-${Date.now()}-${Math.random().toString(36).substring(2, 9)}`;
}

function createChatResponse(request: ChatCompletionRequest): Response {
  const lastUserMessage = [...request.messages]
    .reverse()
    .find((m) => m.role === "user");
  const userContent = lastUserMessage?.content || "Hello";

  const mockResponse = `Mock response to: ${userContent.substring(0, 100)}${userContent.length > 100 ? "..." : ""}`;

  const responseBody = {
    id: generateResponseId(),
    object: "chat.completion",
    created: Math.floor(Date.now() / 1000),
    model: request.model,
    choices: [
      {
        index: 0,
        message: {
          role: "assistant",
          content: mockResponse,
        },
        finish_reason: "stop",
      },
    ],
    usage: {
      prompt_tokens: userContent.length / 4,
      completion_tokens: mockResponse.length / 4,
      total_tokens: (userContent.length + mockResponse.length) / 4,
    },
  };

  return new Response(JSON.stringify(responseBody), {
    status: 200,
    headers: {
      "Content-Type": "application/json",
    },
  });
}

async function createStreamingResponse(
  request: ChatCompletionRequest,
): Promise<Response> {
  const lastUserMessage = [...request.messages]
    .reverse()
    .find((m) => m.role === "user");
  const userContent = lastUserMessage?.content || "Hello";
  const mockResponse = `Mock response to: ${userContent.substring(0, 100)}${userContent.length > 100 ? "..." : ""}`;

  const responseId = generateResponseId();
  const encoder = new TextEncoder();

  const stream = new ReadableStream({
    start(controller) {
      // Send role first
      controller.enqueue(
        encoder.encode(
          `data: ${JSON.stringify({
            id: responseId,
            object: "chat.completion.chunk",
            created: Math.floor(Date.now() / 1000),
            model: request.model,
            choices: [
              {
                index: 0,
                delta: { role: "assistant" },
                finish_reason: null,
              },
            ],
          })}\n\n`,
        ),
      );

      // Send content word by word
      const words = mockResponse.split(" ");
      let delay = 0;

      for (const word of words) {
        setTimeout(() => {
          controller.enqueue(
            encoder.encode(
              `data: ${JSON.stringify({
                id: responseId,
                object: "chat.completion.chunk",
                created: Math.floor(Date.now() / 1000),
                model: request.model,
                choices: [
                  {
                    index: 0,
                    delta: { content: word + " " },
                    finish_reason: null,
                  },
                ],
              })}\n\n`,
            ),
          );
        }, delay);
        delay += 50;
      }

      // Send finish
      setTimeout(() => {
        controller.enqueue(
          encoder.encode(
            `data: ${JSON.stringify({
              id: responseId,
              object: "chat.completion.chunk",
              created: Math.floor(Date.now() / 1000),
              model: request.model,
              choices: [
                {
                  index: 0,
                  delta: {},
                  finish_reason: "stop",
                },
              ],
            })}\n\n`,
          ),
        );
        controller.enqueue(encoder.encode("data: [DONE]\n\n"));
        controller.close();
      }, delay + 100);
    },
  });

  return new Response(stream, {
    status: 200,
    headers: {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      "Connection": "keep-alive",
    },
  });
}

const server = Bun.serve({
  port: PORT,
  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);

    // CORS preflight
    if (request.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type, Authorization",
        },
      });
    }

    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    };

    // Health check
    if (url.pathname === "/health" && request.method === "GET") {
      return new Response(JSON.stringify({ status: "ok" }), {
        status: 200,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    // Models list (minimal)
    if (url.pathname === "/v1/models" && request.method === "GET") {
      return new Response(
        JSON.stringify({
          object: "list",
          data: [
            {
              id: "mock-gpt-4",
              object: "model",
              created: Math.floor(Date.now() / 1000),
              owned_by: "mock",
            },
          ],
        }),
        {
          status: 200,
          headers: { "Content-Type": "application/json", ...corsHeaders },
        },
      );
    }

    // Chat completions
    if (url.pathname === "/v1/chat/completions" && request.method === "POST") {
      try {
        const body = (await request.json()) as ChatCompletionRequest;

        if (body.stream) {
          const response = await createStreamingResponse(body);
          // Add CORS headers
          for (const [key, value] of Object.entries(corsHeaders)) {
            response.headers.set(key, value);
          }
          return response;
        }

        const response = createChatResponse(body);
        // Add CORS headers
        for (const [key, value] of Object.entries(corsHeaders)) {
          response.headers.set(key, value);
        }
        return response;
      } catch (error) {
        console.error("Error processing request:", error);
        return new Response(
          JSON.stringify({
            error: {
              message: "Invalid request",
              type: "invalid_request_error",
            },
          }),
          {
            status: 400,
            headers: { "Content-Type": "application/json", ...corsHeaders },
          },
        );
      }
    }

    // 404 for unknown paths
    return new Response(
      JSON.stringify({ error: "Not found" }),
      {
        status: 404,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      },
    );
  },
});

console.log(`Mock LLM Server running at http://localhost:${PORT}`);
console.log("Endpoints:");
console.log("  GET  /health - Health check");
console.log("  GET  /v1/models - List models");
console.log("  POST /v1/chat/completions - Chat completion (supports streaming)");
