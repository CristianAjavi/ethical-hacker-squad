import OpenAI from "openai";

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

// The dashboard assistant.
export async function POST(req: Request) {
  const { messages } = await req.json();
  const completion = await openai.chat.completions.create({
    model: "gpt-4o",
    messages,
  });
  return Response.json(completion.choices[0].message);
}
