# ST Edge Driver - Dreame Vacuum via Home Assistant WebSocket 

## Visão Geral

Este projeto implementa um ST Edge Driver para integração de robôs aspiradores Dreame expostos no Home Assistant.

A comunicação é realizada diretamente via WebSocket do Home Assistant, permitindo:

- Atualizações quase em tempo real
- Controle bidirecional
- Seleção de cômodos
- Modos de limpeza
- Controle de potência
- Controle de volume de água
- Persistência de seleção de áreas
- Status dos consumíveis do robô, como: filtro e escovas
- Integração com automações do SmartThings

O objetivo do projeto é aproximar a experiência do ecossistema Dreame/Home Assistant da experiência nativa do SmartThings.

---

#### Arquitetura

```
Dreame Vacuum
↓
Home Assistant
↓ WebSocket API
ST Edge Driver
↓
SmartThings App
```

O driver:

- autentica no Home Assistant via Long-Lived Access Token
- consome estados do aspirador via WebSocket
- envia comandos diretamente para serviços do Home Assistant
- traduz estados/capabilities entre Home Assistant e SmartThings

---

#### Funcionalidades

**Estados operacionais**

Mapeamento do estado do robô para:

- stopped
- running
- paused
- seekingCharger
- charging
- docked
- unableToCompleteOperation

**Modos de limpeza**

Suporte para:

- Aspirar
- Passar pano
- Aspirar + passar pano

Mapeados dinamicamente a partir do Home Assistant.

**Potência de sucção**

Integração usando:

robotCleanerTurboMode

Mapeamentos:

Home Assistant SmartThings
Silent extraSilence
Standard silence
Strong off
Turbo on


**Volume de água**

Capability custom:

signalprogram56169.volumeDeAgua

Modos suportados:

- Baixo
- Médio
- Alto

**Seleção de cômodos**

Capability utilizada:

serviceArea

Funcionalidades:

- descoberta dinâmica de cômodos
- persistência de seleção
- limpeza segmentada
- suporte a múltiplos cômodos

Os cômodos são obtidos dinamicamente via:

entity.attributes.rooms

#### Requisitos

SmartThings

- Hub SmartThings compatível com Edge Drivers
- SmartThings CLI instalada (para instalação em modo de desenvolvimento)

Home Assistant

- Home Assistant com WebSocket API habilitada
- Token Long-Lived
- Integração Dreame funcionando

---

#### Configuração

Preferences do Driver

Após instalar o driver, configure:

Preference Descrição
- Home Assistant Host IP/Hostname do HA
- Home Assistant Port Porta do HA
- Home Assistant Token Long-Lived Access Token
- Vacuum Entity ID Ex: vacuum.max
- Cleaning Mode Entity ID Ex: select.max_cleaning_mode
- Water Volume Entity ID Ex: select.max_water_volume

---

#### Instalação

Package

smartthings edge:drivers:package

Install

smartthings edge:drivers:install

Discovery

Após instalação:

1. Remova dispositivos antigos
2. Execute nova descoberta
3. Configure as preferences

---

#### Estrutura do Projeto

```
ha-dreame-vacuum/
├── README.md
├── config.yaml
├── fingerprints.yaml
└── capabilities/
└── profiles/
└── src/
```

Fluxo de Comunicação

Refresh

ST → WebSocket → Home Assistant → Entity State → ST

Comandos

ST → call_service → Home Assistant → Dreame

⸻

Serviços Home Assistant Utilizados

Start/Stop/Home

vacuum.start
vacuum.stop
vacuum.return_to_base

Potência

vacuum.set_fan_speed

Limpeza segmentada

dreame_vacuum.vacuum_clean_segment

Selects

select.select_option

⸻

Seleção de Áreas

O driver mantém persistência local da seleção de cômodos.

Quando todos os cômodos estão selecionados:

vacuum.start

Quando apenas alguns cômodos estão selecionados:

dreame_vacuum.vacuum_clean_segment

⸻

Limitações Conhecidas

SmartThings Rotinas

As capabilities:

- mode
- serviceArea

não aparecem corretamente em Rotinas no ecossistema Edge custom.

Isso parece depender de presentations/VID internos utilizados pelo driver Matter RVC oficial do SmartThings.

⸻

UI dinâmica

O SmartThings possui limitações para:

- disabled states
- visible conditions
- comportamento dinâmico em capabilities custom

Algumas capabilities continuam clicáveis durante execução.

O bloqueio é tratado no handler do driver.

⸻

Roadmap

Próximos passos possíveis

- suporte a múltiplos robôs
- auto discovery de entities
- remoção completa de hardcodes
- custom capabilities para rotinas
- streaming de mapa
- status detalhado de limpeza
- integração com MatterBridge
- publicação em channel Edge

⸻

Créditos

Projeto experimental desenvolvido para integração entre:

- Dreame
- Home Assistant
- SmartThings Edge

Utilizando:

- Lua Edge Drivers
- Home Assistant WebSocket API
- SmartThings Capabilities

⸻

Licença

Projeto experimental para estudos e uso pessoal.
