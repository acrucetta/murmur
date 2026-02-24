---
marp: true
theme: default
paginate: true
title: Murmur Demo - Architecture, Speech Recognition, and Pipeline
description: Presentation-ready deck for Murmur architecture, Moonshine Voice, cleaning pipeline, and language-model rewrite layer.
style: |
  section {
    font-family: "Avenir Next", "Avenir", "Trebuchet MS", sans-serif;
    background: linear-gradient(145deg, #f8fafc 0%, #eef2ff 55%, #ecfeff 100%);
    color: #0f172a;
    padding: 50px;
  }
  h1, h2, h3 {
    color: #0b3b56;
    letter-spacing: 0.2px;
  }
  h1 {
    font-size: 54px;
    margin-bottom: 8px;
  }
  h2 {
    font-size: 38px;
    margin-bottom: 10px;
  }
  p, li, table {
    font-size: 26px;
    line-height: 1.28;
  }
  ul {
    margin-top: 10px;
  }
  strong {
    color: #0b5c7a;
  }
  .small {
    font-size: 18px;
    color: #475569;
  }
  .kicker {
    font-size: 20px;
    letter-spacing: 2px;
    color: #0e7490;
    text-transform: uppercase;
    margin-bottom: 4px;
  }
---

<!-- _class: lead -->
![bg right:40% contain opacity:.92](../assets/jazz-murmur-ai.svg)
# Murmur
## Local-first dictation that feels instant

### What this talk covers
- System architecture
- Moonshine Voice: what it is and how it works
- Cleaning pipeline and optional rewrite model

---

## Agenda

1. Product experience in one minute
2. Architecture and reliability design
3. Moonshine Voice deep dive
4. Cleaning pipeline and rewrite safety
5. Demo flow

---

## The Product Loop

Hold shortcut -> Speak -> Release -> Text appears

Why this is hard:
- Must feel fast
- Must work across apps
- Must recover safely when something fails

---

## Murmur Architecture (Visual)

![w:1220](../assets/presentations/mermaid/murmur-architecture.png)

---

## Runtime Reliability Model

![w:1100](../assets/presentations/mermaid/runtime-states.png)

---

## Moonshine Voice: What It Is

![bg right:33% h:320](../assets/moonshine/logo.png)
- Open-source toolkit for live voice interfaces
- Designed for on-device speech recognition
- Optimized for low-latency streaming use cases

---

## Moonshine Voice: How It Works

![bg right:45% contain](../assets/moonshine/moonshine-voice-architecture.png)
- Audio enters through microphone capture
- Voice activity detection segments speech in real time
- Speech-to-text + intent stages produce app actions

<div class="small">Source: Moonshine open-source architecture diagram.</div>

---

## Why We Chose Moonshine for Murmur

![w:1120](../assets/presentations/moonshine-latency-readme-matplotlib.png)

---

## How Murmur Uses Moonshine in Practice

![w:1100](../assets/presentations/mermaid/moonshine-path.png)

---

## Deterministic Cleaning Pipeline

![w:1100](../assets/presentations/mermaid/cleaning-pipeline.png)

---

## Cleaning Examples (Before -> After)

- `i i i think we should should ship this`
  -> `I think we should ship this.`

- `send it tomorrow scratch that send it friday`
  -> `Send it friday.`

- `send this to jane at sign example.com`
  -> `Send this to jane@example.com.`

---

## Optional Rewrite Model With Guardrails

![w:1100](../assets/presentations/mermaid/rewrite-guardrails.png)

---

## What "Safe by Default" Means Here

![w:1000](../assets/presentations/mermaid/safe-by-default.png)

---

## Demo Plan (Live)

1. Show press-hold-release insertion loop
2. Show one noisy input cleaned to stable text
3. Toggle deterministic mode vs smart mode
4. Show logs for timing and insertion path

---

## Takeaways

- Murmur is designed as a reliable real-time system
- Moonshine gives a strong local speech-recognition backbone
- Deterministic cleanup provides predictable quality
- The rewrite layer adds polish without risking core behavior

---

## Q&A

Thanks.
