# Histórico de alterações

## 0.1.0 — 2026-11-14

- Fase 1: núcleo físico em `sim/` (vento, raia com corpo rígido e painéis de
  placa plana, cabresto, linha XPBD, rabiola, chão), calibrado num protótipo
  Python guardado em `tools/prototipo/`.
- Laboratório de voo como cena principal: setas de força, painel com números e
  controles de vento, cabresto, linha, zoom, turbulência, rabiola, rajada e
  câmeras.
- 30 novos testes: unitários e 11 experimentos de voo com critério numérico.
- CI grava capturas de tela do laboratório (renderização por software) e
  publica no ramo `capturas`.

## 0.0.1 — 2026-11-14

- Estrutura inicial do repositório e documentação (especificação original,
  decisões, arquitetura, progresso).
- Projeto Godot mínimo com tela de teste (céu de fim de tarde, versão e FPS).
- Executor de testes próprio e testes de configuração e de abertura da cena.
- GitHub Actions: testes automáticos e builds Android, Windows e Web, publicados
  na release `ultima-versao`.
