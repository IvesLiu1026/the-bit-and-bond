#!/usr/bin/env python3

from __future__ import annotations

import re
import sys
from pathlib import Path

CRITICAL_SCHEMA_NAMES = {
    "ChatMessage",
    "PersistChatMessageRequest",
    "RealtimeTicket",
    "TelemetryEvent",
    "TelemetryIngestRequest",
    "TelemetryIngestResponse",
    "VoiceTokenRequest",
    "VoiceTokenResponse",
}

CRITICAL_PATH_SCHEMA_REFS = {
    "/api/v1/voice/token": [
        "#/components/schemas/VoiceTokenRequest",
        "#/components/schemas/VoiceTokenResponse",
    ],
    "/api/v1/chat/history": [
        "#/components/schemas/ChatMessage",
    ],
    "/api/v1/chat/messages": [
        "#/components/schemas/PersistChatMessageRequest",
        "#/components/schemas/ChatMessage",
    ],
    "/api/v1/realtime/ticket": [
        "#/components/schemas/RealtimeTicket",
    ],
    "/api/v1/telemetry/public-events": [
        "#/components/schemas/TelemetryIngestRequest",
        "#/components/schemas/TelemetryIngestResponse",
    ],
    "/api/v1/telemetry/events": [
        "#/components/schemas/TelemetryIngestRequest",
        "#/components/schemas/TelemetryIngestResponse",
    ],
}


def extract_router_paths(router_source: str) -> set[str]:
    return set(re.findall(r'"(/api/v1/[^"]+)"', router_source))


def extract_openapi_paths(openapi_source: str) -> set[str]:
    return set(re.findall(r"^\s{2}(/api/v1/[^:]+):", openapi_source, flags=re.M))


def extract_yaml_peer_block(yaml_source: str, header: str) -> str | None:
    lines = yaml_source.splitlines()
    try:
        start_index = lines.index(header)
    except ValueError:
        return None

    header_indent = len(header) - len(header.lstrip(" "))
    block_lines: list[str] = []
    for line in lines[start_index + 1 :]:
        stripped = line.strip()
        current_indent = len(line) - len(line.lstrip(" "))
        if stripped and current_indent <= header_indent:
            break
        block_lines.append(line)
    return "\n".join(block_lines)


def extract_component_schema_names(openapi_source: str) -> set[str]:
    schemas_block = extract_yaml_peer_block(openapi_source, "  schemas:")
    if schemas_block is None:
        return set()
    return set(
        re.findall(r"^\s{4}([A-Za-z0-9_]+):\s*$", schemas_block, flags=re.M)
    )


def find_missing_schema_refs(openapi_source: str) -> list[str]:
    missing: list[str] = []
    for path, expected_refs in CRITICAL_PATH_SCHEMA_REFS.items():
        path_block = extract_yaml_peer_block(openapi_source, f"  {path}:")
        if path_block is None:
            missing.append(f"{path} (path block missing)")
            continue
        for expected_ref in expected_refs:
            if expected_ref not in path_block:
                missing.append(f"{path} -> {expected_ref}")
    return missing


def main() -> int:
    repo_root = Path(__file__).resolve().parents[1]
    router_source = (repo_root / "apps/server/src/api/mod.rs").read_text()
    openapi_source = (repo_root / "packages/api-spec/openapi.yaml").read_text()

    router_paths = extract_router_paths(router_source)
    openapi_paths = extract_openapi_paths(openapi_source)
    openapi_schema_names = extract_component_schema_names(openapi_source)

    missing_in_spec = sorted(router_paths - openapi_paths)
    extra_in_spec = sorted(openapi_paths - router_paths)
    missing_schema_names = sorted(CRITICAL_SCHEMA_NAMES - openapi_schema_names)
    missing_path_refs = find_missing_schema_refs(openapi_source)

    if (
        not missing_in_spec
        and not extra_in_spec
        and not missing_schema_names
        and not missing_path_refs
    ):
        print("OpenAPI route and critical contract coverage are in sync.")
        return 0

    if missing_in_spec:
        print("Routes missing from packages/api-spec/openapi.yaml:")
        for route in missing_in_spec:
            print(f"  - {route}")
    if extra_in_spec:
        print("Routes documented in packages/api-spec/openapi.yaml but not present in router:")
        for route in extra_in_spec:
            print(f"  - {route}")
    if missing_schema_names:
        print("Critical component schemas missing from packages/api-spec/openapi.yaml:")
        for schema_name in missing_schema_names:
            print(f"  - {schema_name}")
    if missing_path_refs:
        print("Critical schema refs missing from OpenAPI path contracts:")
        for missing_ref in missing_path_refs:
            print(f"  - {missing_ref}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
