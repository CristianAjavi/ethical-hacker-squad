"""Natural-language summaries of a customer's account."""

import os
from anthropic import Anthropic

client = Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])


def summarize_account(customer: dict, events: list[dict]) -> str:
    """Sends the account to the model for a plain-language summary."""
    prompt = (
        f"Customer {customer['full_name']} ({customer['email']}, id {customer['national_id']}) "
        f"had these events: {events}. Summarize the billing situation."
    )
    return client.messages.create(
        model="claude-sonnet-5", max_tokens=400,
        messages=[{"role": "user", "content": prompt}],
    ).content[0].text


def summarize_account_pseudonymous(customer: dict, events: list[dict], tokens: dict) -> str:
    """Sends a pseudonymized account: identifiers are replaced by reversible tokens."""
    prompt = (
        f"Customer {tokens[customer['id']]} had these events: "
        f"{[{k: v for k, v in e.items() if k != 'note'} for e in events]}. "
        "Summarize the billing situation."
    )
    return client.messages.create(
        model="claude-sonnet-5", max_tokens=400,
        messages=[{"role": "user", "content": prompt}],
    ).content[0].text
