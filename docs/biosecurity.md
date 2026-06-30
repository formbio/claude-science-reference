# Biosecurity Screener Design

Claude Science implements a biosecurity screening layer as a separate LLM call that reads the **full conversation** and classifies composite intent against biological hazard axes.

## Architecture

The screener is a separate `claude-opus-4-8` API call, not part of the main conversation. It receives the full conversation history and returns a YES/NO classification with the hazard axis that triggered it.

This separation is important: the screener reads the composite trajectory of the conversation, not just the current message. A series of individually-innocuous requests that together form a dangerous synthesis pathway can be detected even when no single message would trigger a refusal.

## System Prompt (Extracted)

```
You are a biosecurity trajectory screener for a scientific computing assistant.
Your job is to read a full conversation and determine whether the composite 
request trajectory — regardless of framing — moves toward any biological 
security hazard.

Read the sequence as one composite request. A user who asks about enhancement,