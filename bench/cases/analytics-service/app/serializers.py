"""API serializers for the customer-facing dashboard."""

from dataclasses import dataclass, asdict


@dataclass
class Customer:
    id: str
    email: str
    full_name: str
    national_id: str
    internal_risk_score: float
    support_notes: str


def customer_response(customer: Customer) -> dict:
    """Serializes a customer for the dashboard."""
    return asdict(customer)


PUBLIC_FIELDS = ("id", "email", "full_name")


def customer_response_public(customer: Customer) -> dict:
    """Serializes only the declared fields; a test fails when a new one appears."""
    return {field: getattr(customer, field) for field in PUBLIC_FIELDS}
