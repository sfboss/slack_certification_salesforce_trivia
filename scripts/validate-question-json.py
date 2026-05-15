#!/usr/bin/env python3
"""
Validate a Cert Game question pack JSON file against the contract in README §7.

Usage:
    python3 scripts/validate-question-json.py sample_data/adm201-question-pack.sample.json
Exit code 0 on success, non-zero on validation error.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

try:
    from jsonschema import Draft202012Validator
except ImportError:
    print("jsonschema not installed. Run: pip install -r scripts/requirements.txt", file=sys.stderr)
    sys.exit(2)


SCHEMA = {
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "type": "object",
    "required": ["exam", "questionBank", "questions"],
    "properties": {
        "exam": {
            "type": "object",
            "required": ["name", "code"],
            "properties": {
                "name": {"type": "string", "minLength": 1},
                "code": {"type": "string", "minLength": 1},
            },
        },
        "questionBank": {
            "type": "object",
            "required": ["name", "version", "sourceType", "status"],
            "properties": {
                "name": {"type": "string"},
                "version": {"type": "string"},
                "sourceType": {"enum": ["Manual", "Generated", "Imported", "OfficialNotesDerived"]},
                "status": {"enum": ["Draft", "Review", "Published", "Retired"]},
                "externalId": {"type": "string"},
            },
        },
        "questions": {
            "type": "array",
            "minItems": 1,
            "items": {
                "type": "object",
                "required": [
                    "externalId", "domain", "difficulty", "questionType",
                    "question", "choices", "explanation",
                ],
                "properties": {
                    "externalId": {"type": "string", "minLength": 1},
                    "domain": {"type": "string", "minLength": 1},
                    "difficulty": {"enum": ["Beginner", "Intermediate", "Advanced", "Expert"]},
                    "questionType": {"enum": ["Single Select", "Multi Select", "True False"]},
                    "scenario": {"type": ["string", "null"]},
                    "question": {"type": "string", "minLength": 1},
                    "choices": {
                        "type": "array",
                        "minItems": 2,
                        "items": {
                            "type": "object",
                            "required": ["label", "text", "isCorrect"],
                            "properties": {
                                "label": {"type": "string", "minLength": 1, "maxLength": 4},
                                "text": {"type": "string", "minLength": 1},
                                "isCorrect": {"type": "boolean"},
                                "explanation": {"type": "string"},
                            },
                        },
                    },
                    "explanation": {"type": "string"},
                    "citations": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "required": ["title", "url", "sourceType"],
                            "properties": {
                                "title": {"type": "string"},
                                "url": {"type": "string", "format": "uri"},
                                "sourceType": {"type": "string"},
                                "relevanceNote": {"type": "string"},
                            },
                        },
                    },
                },
            },
        },
    },
}


def business_rules(pack: dict) -> list[str]:
    errs: list[str] = []
    for i, q in enumerate(pack.get("questions", [])):
        prefix = f"questions[{i}] ({q.get('externalId', '?')})"
        choices = q.get("choices", [])
        correct = [c for c in choices if c.get("isCorrect")]
        qtype = q.get("questionType")

        if qtype == "Single Select":
            if len(choices) < 3:
                errs.append(f"{prefix}: Single Select requires >= 3 choices, got {len(choices)}")
            if len(correct) != 1:
                errs.append(f"{prefix}: Single Select requires exactly 1 correct choice, got {len(correct)}")
        elif qtype == "Multi Select":
            if len(correct) < 2:
                errs.append(f"{prefix}: Multi Select requires >= 2 correct choices, got {len(correct)}")
        elif qtype == "True False":
            if len(choices) != 2:
                errs.append(f"{prefix}: True False requires exactly 2 choices")
            if len(correct) != 1:
                errs.append(f"{prefix}: True False requires exactly 1 correct choice")

        labels = [c.get("label") for c in choices]
        if len(set(labels)) != len(labels):
            errs.append(f"{prefix}: duplicate choice labels {labels}")

        if not q.get("citations"):
            errs.append(f"{prefix}: at least one citation is required (drafts without citations are blocked)")
    return errs


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: validate-question-json.py <pack.json>", file=sys.stderr)
        return 2
    path = Path(argv[1])
    if not path.is_file():
        print(f"file not found: {path}", file=sys.stderr)
        return 2
    pack = json.loads(path.read_text(encoding="utf-8"))

    validator = Draft202012Validator(SCHEMA)
    schema_errors = sorted(validator.iter_errors(pack), key=lambda e: e.path)
    rule_errors = business_rules(pack)

    if schema_errors:
        print(f"Schema validation failed for {path.name}:")
        for e in schema_errors:
            loc = "/".join(str(p) for p in e.path) or "<root>"
            print(f"  - {loc}: {e.message}")
    if rule_errors:
        print(f"Business rule violations for {path.name}:")
        for r in rule_errors:
            print(f"  - {r}")

    if schema_errors or rule_errors:
        return 1
    print(f"OK: {path.name} — {len(pack['questions'])} questions valid.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
