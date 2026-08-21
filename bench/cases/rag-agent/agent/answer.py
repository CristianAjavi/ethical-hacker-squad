"""Support assistant: retrieves tickets and answers with tools."""

import os
import subprocess
from anthropic import Anthropic

client = Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])
SYSTEM = "You are the support assistant for Acme Billing. Be concise."


def build_prompt(question: str, docs: list[str]) -> str:
    joined = "\n".join(docs)
    return f"{SYSTEM}\n\nKnowledge:\n{joined}\n\nCustomer question: {question}"


def build_prompt_marked(question: str, docs: list[dict]) -> list[dict]:
    blocks = []
    for d in docs:
        blocks.append({
            "type": "text",
            "text": f"<document source={d['origin']!r} trust={d['trust']!r}>{d['text']}</document>",
        })
    blocks.append({"type": "text", "text": f"<question>{question}</question>"})
    return [{"role": "user", "content": blocks}]


def run_tool(decision: dict, session: dict) -> str:
    """Executes the tool the model asked for."""
    if decision["tool"] == "refund":
        return issue_refund(decision["account_id"], decision["amount"])
    if decision["tool"] == "lookup":
        return lookup(decision["account_id"])
    return "unknown tool"


def run_tool_scoped(decision: dict, session: dict) -> str:
    """Executes a tool against the caller's own account, whatever the model says."""
    account_id = session["authenticated_account_id"]
    if decision["tool"] == "lookup":
        return lookup(account_id)
    if decision["tool"] == "refund":
        raise PermissionError("refunds are not available to the assistant")
    return "unknown tool"


def summarize_and_run(model_output: str) -> str:
    """Runs the shell snippet the model produced for the operator."""
    return subprocess.run(model_output, shell=True, capture_output=True, text=True).stdout


def summarize_and_render(model_output: dict) -> str:
    """Renders a summary from a closed set of operations."""
    allowed = {"total", "count", "average"}
    if model_output.get("op") not in allowed:
        raise ValueError("operation not allowed")
    return f"{model_output['op']}: {model_output['value']}"


def issue_refund(account_id: str, amount: int) -> str:
    return f"refunded {amount} to {account_id}"


def lookup(account_id: str) -> str:
    return f"account {account_id}"
