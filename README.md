# PIPA BRASIL 🪁

Simulador brasileiro de pipas em 3D, para Windows e Android, feito com Godot 4.
A prioridade é a física: a pipa, a linha e a rabiola respondem de verdade ao
vento e aos comandos do pipeiro, e o combate (1 contra 1 e combate livre) é uma
extensão desse mesmo núcleo físico. Combate apenas virtual.

## Situação

Fase 0 — infraestrutura. Veja `docs/progresso.md`.

## Como testar a versão mais recente

1. Abra a página de releases do repositório e entre em **Última versão (automática)**.
2. Baixe o arquivo do seu aparelho:
   - Android: `pipa-brasil.apk`
   - Windows: `pipa-brasil-windows.zip` (descompacte e abra o `.exe`)
3. Detalhes em `docs/como-testar.md`.

Cada envio de código roda os testes automáticos e gera essa versão de novo.

## Organização

| Pasta | Conteúdo |
| --- | --- |
| `sim/` | Núcleo físico puro (KitePhysicsCore), testável sem gráficos |
| `game/` | Tudo o que aparece na tela: visuais, câmeras, controles, bots, modos |
| `scenes/` | Cenas do Godot |
| `tests/` | Testes automáticos e experimentos de voo |
| `docs/` | Especificação, decisões, arquitetura, progresso |
| `.github/workflows/` | Testes e builds automáticos (GitHub Actions) |

## Ferramentas

Godot 4 (MIT), GDScript, GitHub Actions. Custo zero.
