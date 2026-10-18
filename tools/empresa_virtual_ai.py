#!/usr/bin/env python3
"""Agente local opcional da Empresa Virtual. Requer Python 3.10+ e Ollama no host.

Escuta somente UDP em 127.0.0.1:47800 e grava recomendações em agent-inbox.json.
Não abre portas na rede e não executa comandos do modelo.
"""
from __future__ import annotations

import argparse
import json
import os
import socket
import time
import urllib.error
import urllib.request
from pathlib import Path

OLLAMA_URL = "http://127.0.0.1:11434/api/generate"
MAX_PACKET = 8192
PROMPT_COOLDOWN = 45


def ask_ollama(model: str, state: dict) -> str:
    prompt = (
        "Você é a IA de operações de uma empresa virtual de ônibus no simulador openOMSI. "
        "Analise apenas o estado fornecido. Responda em português brasileiro com UMA recomendação "
        "curta e prática, sem inventar fatos. Não emita comandos, código, punições automáticas, "
        "ordens perigosas nem alterações de arquivos. Se faltarem dados, diga isso. Estado JSON: "
        + json.dumps(state, ensure_ascii=False, separators=(",", ":"))
    )
    body = json.dumps({
        "model": model,
        "prompt": prompt,
        "stream": False,
        "options": {"temperature": 0.2, "num_predict": 100},
    }).encode("utf-8")
    req = urllib.request.Request(
        OLLAMA_URL, data=body, headers={"Content-Type": "application/json"}, method="POST"
    )
    with urllib.request.urlopen(req, timeout=90) as response:
        result = json.loads(response.read().decode("utf-8"))
    text = str(result.get("response", "")).strip()
    return text[:180]


def atomic_write(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(".tmp")
    temp.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    os.replace(temp, path)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plugin-dir", required=True, help="Pasta plugins/empresa_virtual do openOMSI")
    parser.add_argument("--model", default=os.environ.get("OPENOMSI_AI_MODEL", "qwen2.5:3b"))
    parser.add_argument("--port", type=int, default=47800)
    args = parser.parse_args()
    plugin_dir = Path(args.plugin_dir).expanduser().resolve()
    inbox = plugin_dir / "agent-inbox.json"
    if not plugin_dir.is_dir():
        parser.error(f"A pasta do plugin não existe: {plugin_dir}")

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(("127.0.0.1", args.port))
    sock.settimeout(1.0)
    last_call = 0.0
    last_signature = ""
    print(f"Empresa Virtual IA escutando em 127.0.0.1:{args.port}; modelo={args.model}")
    print("Somente recomendações são publicadas; nenhuma ação de jogo é executada.")

    while True:
        try:
            packet, address = sock.recvfrom(MAX_PACKET)
        except socket.timeout:
            continue
        if address[0] != "127.0.0.1":
            continue
        try:
            state = json.loads(packet.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            continue
        if not isinstance(state, dict) or state.get("kind") != "state" or not state.get("host"):
            continue
        signature = json.dumps(state, sort_keys=True, ensure_ascii=False)
        now = time.monotonic()
        if signature == last_signature or now - last_call < PROMPT_COOLDOWN:
            continue
        last_signature = signature
        last_call = now
        try:
            recommendation = ask_ollama(args.model, state)
            if recommendation:
                atomic_write(inbox, {
                    "updated": int(time.time()),
                    "model": args.model,
                    "recommendation": recommendation,
                })
                print("Recomendação atualizada:", recommendation)
        except (OSError, urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
            print(f"IA indisponível; jogo continua sem IA: {exc}")


if __name__ == "__main__":
    raise SystemExit(main())
