// Lango — AI tutor backend (US-090, US-091, US-092).
//
// Why this exists as an Edge Function: a model API key cannot ship inside a
// Flutter client. The key lives here as a Supabase secret and never reaches
// the device. Supabase verifies the caller's JWT before this function runs, so
// only signed-in learners can reach it.
//
// Provider: Groq (OpenAI-compatible chat completions). Called over plain
// `fetch` rather than an SDK — the request is one POST, and a dependency-free
// function cold-starts faster.
//
// Deploy:
//   supabase secrets set GROQ_API_KEY=gsk_...
//   supabase functions deploy tutor
//
// Until it is deployed the app degrades honestly: `TutorService` reports the
// endpoint as not configured and the Tutor screen says so rather than faking a
// conversation (CLAUDE.md invariant).

const GROQ_URL = 'https://api.groq.com/openai/v1/chat/completions';

// 131k context, strong at instruction following and structured output, and
// fast enough that a chat turn does not feel like a page load.
const MODEL = Deno.env.get('GROQ_MODEL') ?? 'openai/gpt-oss-120b';

// A tutor turn is one or two sentences plus its gloss and an optional
// correction. Generous relative to that, because reasoning models spend
// tokens before they answer.
const MAX_TOKENS = 2048;

// Longest history we will send back. A conversation past this drops its
// oldest turns rather than growing the request without bound.
const MAX_HISTORY = 24;

// Beyond this the request is not a tutor turn any more. Bounds both cost and
// the blast radius of a caller sending arbitrary text.
const MAX_MESSAGE_CHARS = 2000;

type Role = 'user' | 'tutor';

interface TutorContext {
  language: string;
  language_name: string;
  level: string;
  level_label: string;
  goals: string[];
  vocabulary: string[];
  grammar: string[];
  recent_mistakes: string[];
  scenario?: string;
}

interface TurnRequest {
  context: TutorContext;
  messages: { role: Role; content: string }[];
}

// The reply shape is enforced by the provider rather than parsed out of prose,
// so the client never has to guess whether a correction was offered.
const RESPONSE_SCHEMA = {
  name: 'tutor_turn',
  strict: true,
  schema: {
    type: 'object',
    properties: {
      reply: {
        type: 'string',
        description:
          "The tutor's next turn, written in the target language only.",
      },
      reply_translation: {
        type: 'string',
        description: 'A plain English translation of `reply`.',
      },
      correction: {
        description:
          "A correction of the learner's most recent turn, or null when " +
          'nothing meaningful was wrong.',
        anyOf: [
          { type: 'null' },
          {
            type: 'object',
            properties: {
              original: {
                type: 'string',
                description: "The learner's sentence, quoted exactly.",
              },
              corrected: {
                type: 'string',
                description: 'The same sentence written correctly.',
              },
              explanation: {
                type: 'string',
                description:
                  'One or two sentences of English explaining what changed.',
              },
              example: {
                description:
                  'An optional extra sentence using the same pattern, or null.',
                anyOf: [{ type: 'string' }, { type: 'null' }],
              },
            },
            required: ['original', 'corrected', 'explanation', 'example'],
            additionalProperties: false,
          },
        ],
      },
    },
    required: ['reply', 'reply_translation', 'correction'],
    additionalProperties: false,
  },
} as const;

function systemPrompt(ctx: TutorContext): string {
  // US-091: the tutor is given the learner's real level, goals, studied
  // vocabulary and grammar, and recent mistakes — all of it recorded data.
  const lines = [
    `You are a patient ${ctx.language_name} conversation partner for a ` +
      `learner at "${ctx.level_label}" level.`,
    '',
    'How to speak:',
    `- Write "reply" in ${ctx.language_name} only. All English goes in ` +
      '"reply_translation", never in "reply".',
    '- Keep replies to one or two short sentences. Ask one question back so ' +
      'the learner always has something to answer.',
    '- Stay inside the words and patterns listed below. When you must ' +
      'introduce a new word, choose the most common one and keep the rest of ' +
      'the sentence simple.',
    '- Do not use vocabulary or grammar above the stated level, even if it ' +
      'would be more natural.',
  ];

  if (ctx.goals.length > 0) {
    lines.push(
      '',
      `The learner is studying for: ${ctx.goals.join(', ')}. Steer the ` +
        'conversation toward situations that serve those goals.',
    );
  }

  if (ctx.scenario) {
    lines.push(
      '',
      `Play this situation: ${ctx.scenario}. Stay in role, and start it ` +
        'yourself if the learner has not.',
    );
  }

  if (ctx.vocabulary.length > 0) {
    lines.push(
      '',
      'Words the learner has studied (prefer these):',
      ctx.vocabulary.join(', '),
    );
  }

  if (ctx.grammar.length > 0) {
    lines.push('', 'Patterns the learner has studied:', ctx.grammar.join(', '));
  }

  if (ctx.recent_mistakes.length > 0) {
    lines.push(
      '',
      'Recently answered incorrectly — worth working back in naturally:',
      ctx.recent_mistakes.join(', '),
    );
  }

  lines.push(
    '',
    'Corrections (this is the part learners value most):',
    "- Look at the learner's most recent turn only.",
    '- Set "correction" when something is genuinely wrong: a wrong particle, ' +
      'a wrong ending, wrong word order, or a word used with the wrong ' +
      'meaning.',
    '- Set "correction" to null when the turn is correct, or when the only ' +
      'issues are typing slips or stylistic preferences. Do not invent a ' +
      'correction to seem useful, and never correct a turn you are unsure ' +
      'about.',
    '- Quote the learner exactly in "original". Write "explanation" in ' +
      'English, in one or two sentences, unless the learner asks for more.',
    '- Correcting is not the conversation: still reply to what they said.',
  );

  return lines.join('\n');
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

Deno.serve(async (req: Request) => {
  const apiKey = Deno.env.get('GROQ_API_KEY');

  // Health check. The app asks before showing a conversation UI, so a project
  // without a deployed tutor says so up front instead of failing on the
  // learner's first message. Costs nothing — no model call.
  if (req.method === 'GET') {
    return apiKey
      ? jsonResponse({ status: 'ok', model: MODEL })
      : jsonResponse({ error: 'not_configured' }, 503);
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'method_not_allowed' }, 405);
  }

  if (!apiKey) {
    // Distinct from a transient failure: the deployment is incomplete, and the
    // app should tell the learner that rather than "try again".
    return jsonResponse({ error: 'not_configured' }, 503);
  }

  let body: TurnRequest;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'invalid_request' }, 400);
  }

  const ctx = body?.context;
  const history = Array.isArray(body?.messages) ? body.messages : [];
  if (!ctx?.language_name || !ctx?.level_label || history.length === 0) {
    return jsonResponse({ error: 'invalid_request' }, 400);
  }

  const turns = history
    .slice(-MAX_HISTORY)
    .filter((m) => typeof m?.content === 'string' && m.content.trim() !== '')
    .map((m) => ({
      role: m.role === 'user' ? ('user' as const) : ('assistant' as const),
      content: m.content.slice(0, MAX_MESSAGE_CHARS),
    }));

  // The conversation has to start with the learner.
  while (turns.length > 0 && turns[0].role !== 'user') turns.shift();
  if (turns.length === 0) {
    return jsonResponse({ error: 'invalid_request' }, 400);
  }

  try {
    const upstream = await fetch(GROQ_URL, {
      method: 'POST',
      headers: {
        authorization: `Bearer ${apiKey}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        model: MODEL,
        max_completion_tokens: MAX_TOKENS,
        // Some variety turn to turn, without wandering off the level.
        temperature: 0.6,
        response_format: { type: 'json_schema', json_schema: RESPONSE_SCHEMA },
        messages: [
          { role: 'system', content: systemPrompt(ctx) },
          ...turns,
        ],
      }),
    });

    if (!upstream.ok) {
      console.error('groq error', upstream.status, await upstream.text());
      // Rate limits are worth distinguishing: the learner should wait rather
      // than assume the tutor is broken.
      return jsonResponse(
        { error: upstream.status === 429 ? 'rate_limited' : 'upstream_error' },
        upstream.status === 429 ? 429 : 502,
      );
    }

    const data = await upstream.json();
    const choice = data?.choices?.[0];
    const content = choice?.message?.content;

    // A truncated response is not a usable turn — better to say the tutor did
    // not answer than to render half a sentence as if it were the reply.
    if (choice?.finish_reason === 'length' || typeof content !== 'string') {
      return jsonResponse({ error: 'empty_response' }, 502);
    }

    const parsed = JSON.parse(content);
    if (typeof parsed?.reply !== 'string') {
      return jsonResponse({ error: 'empty_response' }, 502);
    }

    const correction = parsed.correction;
    return jsonResponse({
      reply: parsed.reply,
      translation:
        typeof parsed.reply_translation === 'string'
          ? parsed.reply_translation
          : null,
      // Only forward a correction that actually says something; the client
      // drops empty ones anyway, and this keeps the contract tight.
      correction:
        correction && typeof correction.corrected === 'string'
          ? correction
          : null,
    });
  } catch (error) {
    // Never forward the provider's error text to the client: it can carry
    // request detail, and the UI must not surface exception text anyway
    // (REDESIGN.md §28).
    console.error('tutor turn failed', error);
    return jsonResponse({ error: 'upstream_error' }, 502);
  }
});
