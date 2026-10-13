// The AI model, reached through OpenRouter's chat completions API. Kept to
// this one file so the provider or model can change without touching the rest.

export interface ToolCall {
  id: string;
  type: "function";
  function: { name: string; arguments: string };
}

export type ChatMessage =
  | { role: "system"; content: string | ContentPart[] }
  | { role: "user"; content: string | ContentPart[] }
  | { role: "assistant"; content: string | null; tool_calls?: ToolCall[] }
  | { role: "tool"; tool_call_id: string; content: string };

export interface ContentPart {
  type: "text";
  text: string;
  /** Marks the end of the part of the prompt worth caching between messages. */
  cache_control?: { type: "ephemeral" };
}

export interface ToolDefinition {
  type: "function";
  function: { name: string; description: string; parameters: Record<string, unknown> };
}

export interface ChatResult {
  /** The text to send, when the model is done. */
  text: string | null;
  toolCalls: ToolCall[];
  usage: { inputTokens: number; cachedInputTokens: number; outputTokens: number; costUsd: number };
}

export interface Ai {
  model: string;
  chat(messages: ChatMessage[], tools: ToolDefinition[]): Promise<ChatResult>;
}

export function openRouter(
  config: { apiKey: string; model: string },
  fetcher: typeof fetch = fetch,
): Ai {
  return {
    model: config.model,
    async chat(messages, tools) {
      const res = await fetcher("https://openrouter.ai/api/v1/chat/completions", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${config.apiKey}`,
          "Content-Type": "application/json",
          "HTTP-Referer": "https://isangotech.co.za",
          "X-Title": "IsangoTech WhatsApp Assistant",
        },
        body: JSON.stringify({
          model: config.model,
          messages,
          tools,
          tool_choice: "auto",
          max_tokens: 1024,
          // Short customer chats don't need much thinking; keeps replies fast and cheap.
          reasoning: { effort: "low" },
          // Asks OpenRouter to report what each call cost.
          usage: { include: true },
          // Only providers that don't store customers' messages or train on them,
          // as the privacy policy promises.
          provider: { data_collection: "deny" },
        }),
        signal: AbortSignal.timeout(45_000),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(`AI request failed (${res.status}): ${data?.error?.message ?? "unknown error"}`);
      const message = data?.choices?.[0]?.message ?? {};
      const usage = data?.usage ?? {};
      return {
        text: typeof message.content === "string" && message.content.trim() ? message.content.trim() : null,
        toolCalls: Array.isArray(message.tool_calls) ? message.tool_calls : [],
        usage: {
          inputTokens: Number(usage.prompt_tokens ?? 0),
          cachedInputTokens: Number(usage.prompt_tokens_details?.cached_tokens ?? 0),
          outputTokens: Number(usage.completion_tokens ?? 0),
          costUsd: Number(usage.cost ?? 0),
        },
      };
    },
  };
}
