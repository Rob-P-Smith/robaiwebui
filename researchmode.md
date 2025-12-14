# Research & Agentic Mode Buttons - Open WebUI Implementation Guide

This document details all changes made to add Research and Agentic mode buttons to Open WebUI with admin-controlled toggles.

## Last Updated: 2025-11-27

## Overview

Two button groups are added to the message input area:

1. **Research Button** - Cycles through: Off → Research → Research+
2. **Agentic Button** - Toggles: Pure LLM ↔ Agentic (default: Pure LLM)

When active, these buttons prepend `[[tag]]` markers to user prompts:
- `[[research_request]]` - Research mode
- `[[research_deeply]]` - Research+ mode
- `[[pure_llm]]` - Pure LLM mode (default, no tools, direct LLM)
- `[[autonomous]]` - Agentic mode (tools enabled)

Admin can enable/disable these buttons globally via Settings → Interface.

---

## Files Modified

### Frontend (Svelte)
1. `src/lib/components/chat/MessageInput.svelte` - Button UI and tag injection
2. `src/lib/components/chat/Chat.svelte` - State management and config fetch
3. `src/lib/components/admin/Settings/Interface.svelte` - Admin toggles

### Backend (Python)
4. `backend/open_webui/config.py` - PersistentConfig entries
5. `backend/open_webui/routers/tasks.py` - API endpoints
6. `backend/open_webui/main.py` - App state initialization

---

## Frontend Changes

### File 1: MessageInput.svelte

**Path:** `src/lib/components/chat/MessageInput.svelte`

#### 1.1 Add feature toggle and state variables

**Location:** After `codeInterpreterEnabled` declaration (~line 110)

```typescript
export let imageGenerationEnabled = false;
export let webSearchEnabled = false;
export let codeInterpreterEnabled = false;

// Feature toggles - set to true to enable custom buttons and tag injection
export let enableResearchButton = true;
export let enableAgenticButton = true;

export let researchModeEnabled = 0; // 0 = disabled, 1 = research, 2 = research+
export let agenticMode = 1; // 1 = pure llm (default), 2 = agentic
```

#### 1.2 Add preparePromptForSubmit function

**Location:** After `replaceVariables` function (~line 298)

```typescript
const preparePromptForSubmit = (text: string): string => {
    if (text.trim() === '') {
        return text;
    }

    let prepend = '';

    // Research mode tags (prepended first) - only if feature is enabled
    if (enableResearchButton) {
        if (researchModeEnabled === 1) {
            prepend += '[[research_request]]\n';
        } else if (researchModeEnabled === 2) {
            prepend += '[[research_deeply]]\n';
        }
    }

    // Agentic/Pure LLM tags (prepended after research tags) - only if feature is enabled
    if (enableAgenticButton) {
        if (agenticMode === 1) {
            prepend += '[[pure_llm]]\n';
        } else if (agenticMode === 2) {
            prepend += '[[autonomous]]\n';
        }
    }

    return prepend + text;
};
```

#### 1.3 Update all dispatch('submit') calls

Replace `dispatch('submit', prompt)` with `dispatch('submit', preparePromptForSubmit(prompt))` in:
- Speech auto-send handler
- Form submit handler
- Enter key press handler

#### 1.4 Add Research button UI

**Location:** After IntegrationsMenu closing tag, wrap with conditional:

```svelte
{#if enableResearchButton}
    <Tooltip content={$i18n.t(researchModeEnabled === 0 ? 'Research Mode' : researchModeEnabled === 1 ? 'Deep Research Mode' : 'Disable Research')} placement="top">
        <button
            id="research-mode-button"
            type="button"
            on:click|preventDefault={() => (researchModeEnabled = (researchModeEnabled + 1) % 3)}
            class="ml-[10px] rounded-full px-2 md:px-3 py-1.5 flex items-center gap-1.5 outline-hidden focus:outline-hidden transition-colors duration-200 {researchModeEnabled === 1
                ? 'text-blue-600 dark:text-blue-400 border border-blue-600 dark:border-blue-400 bg-transparent hover:bg-blue-50 dark:hover:bg-blue-950/30'
                : researchModeEnabled === 2
                ? 'text-red-600 dark:text-red-400 border border-red-600 dark:border-red-400 bg-transparent hover:bg-red-50 dark:hover:bg-red-950/30'
                : 'bg-transparent hover:bg-gray-100 text-gray-700 dark:text-white dark:hover:bg-gray-800 border border-transparent'}"
            aria-label={researchModeEnabled === 0
                ? $i18n.t('Enable Research Mode')
                : researchModeEnabled === 1
                ? $i18n.t('Enable Deep Research Mode')
                : $i18n.t('Disable Research Mode')}
            aria-pressed={researchModeEnabled > 0}
        >
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-4">
                <path stroke-linecap="round" stroke-linejoin="round" d="M9.75 3.104v5.714a2.25 2.25 0 01-.659 1.591L5 14.5M9.75 3.104c-.251.023-.501.05-.75.082m.75-.082a24.301 24.301 0 014.5 0m0 0v5.714c0 .597.237 1.17.659 1.591L19.8 15.3M14.25 3.104c.251.023.501.05.75.082M19.8 15.3l-1.57.393A9.065 9.065 0 0112 15a9.065 9.065 0 00-6.23-.693L5 14.5m14.8.8l1.402 1.402c1.232 1.232.65 3.318-1.067 3.611A48.309 48.309 0 0112 21c-2.773 0-5.491-.235-8.135-.687-1.718-.293-2.3-2.379-1.067-3.61L5 14.5"/>
            </svg>
            <span class="hidden md:inline text-sm font-medium">{researchModeEnabled === 1 ? 'Research' : researchModeEnabled === 2 ? 'Research+' : 'Research'}</span>
        </button>
    </Tooltip>
{/if}
```

#### 1.5 Add Agentic button UI

**Location:** After Research button, wrap with conditional:

```svelte
{#if enableAgenticButton}
    <Tooltip content={$i18n.t(agenticMode === 1 ? 'Pure LLM Mode (no tools)' : 'Agentic Mode (tools enabled)')} placement="top">
        <button
            id="agentic-mode-button"
            type="button"
            on:click|preventDefault={() => (agenticMode = agenticMode === 1 ? 2 : 1)}
            class="ml-[10px] rounded-full px-2 md:px-3 py-1.5 flex items-center gap-1.5 outline-hidden focus:outline-hidden transition-colors duration-200 {agenticMode === 1
                ? 'bg-transparent hover:bg-gray-100 text-gray-700 dark:text-white dark:hover:bg-gray-800 border border-gray-300 dark:border-gray-600'
                : 'text-blue-600 dark:text-blue-400 border border-blue-600 dark:border-blue-400 bg-transparent hover:bg-blue-50 dark:hover:bg-blue-950/30'}"
            aria-label={agenticMode === 1 ? $i18n.t('Pure LLM Mode') : $i18n.t('Agentic Mode')}
            aria-pressed={agenticMode === 2}
        >
            <!-- Icons: fire (Pure LLM default), lightbulb (Agentic) -->
            {#if agenticMode === 1}
                <!-- Fire icon - Pure LLM mode (default) -->
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-4">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M15.362 5.214A8.252 8.252 0 0112 21 8.25 8.25 0 016.038 7.048 8.287 8.287 0 009 9.6a8.983 8.983 0 013.361-6.867 8.21 8.21 0 003 2.48z"/>
                    <path stroke-linecap="round" stroke-linejoin="round" d="M12 18a3.75 3.75 0 00.495-7.467 5.99 5.99 0 00-1.925 3.546 5.974 5.974 0 01-2.133-1A3.75 3.75 0 0012 18z"/>
                </svg>
            {:else}
                <!-- Light bulb icon - Agentic mode with tools -->
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-4">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M12 18v-5.25m0 0a6.01 6.01 0 001.5-.189m-1.5.189a6.01 6.01 0 01-1.5-.189m3.75 7.478a12.06 12.06 0 01-4.5 0m3.75 2.383a14.406 14.406 0 01-3 0M14.25 18v-.192c0-.983.658-1.823 1.508-2.316a7.5 7.5 0 10-7.517 0c.85.493 1.509 1.333 1.509 2.316V18"/>
                </svg>
            {/if}
            <span class="hidden md:inline text-sm font-medium">{agenticMode === 1 ? 'Pure LLM' : 'Agentic'}</span>
        </button>
    </Tooltip>
{/if}
```

---

### File 2: Chat.svelte

**Path:** `src/lib/components/chat/Chat.svelte`

#### 2.1 Add getTaskConfig import

```typescript
import {
    chatCompleted,
    generateQueries,
    chatAction,
    generateMoACompletion,
    stopTask,
    getTaskIdsByChatId,
    getTaskConfig  // Add this
} from '$lib/apis';
```

#### 2.2 Add state variables

**Location:** After existing state variable declarations

```typescript
let researchModeEnabled = 0; // 0 = disabled, 1 = research, 2 = research+
let agenticMode = 1; // 1 = pure llm (default, gray), 2 = agentic (blue)

// Feature toggles from admin settings (taskConfig)
let enableResearchButton = true;
let enableAgenticButton = true;
```

#### 2.3 Fetch taskConfig on mount

**Location:** Inside `onMount`, after `loading = true`

```typescript
onMount(async () => {
    loading = true;
    console.log('mounted');

    // Fetch taskConfig to get admin settings for research/agentic buttons
    try {
        const taskConfig = await getTaskConfig(localStorage.token);
        if (taskConfig) {
            enableResearchButton = taskConfig.ENABLE_RESEARCH_MODE ?? true;
            enableAgenticButton = taskConfig.ENABLE_AGENTIC_MODE ?? true;
        }
    } catch (e) {
        console.error('Failed to fetch task config:', e);
    }

    // ... rest of onMount
});
```

#### 2.4 Pass props to MessageInput

```svelte
<MessageInput
    bind:researchModeEnabled
    bind:agenticMode
    {enableResearchButton}
    {enableAgenticButton}
    ...
/>
```

---

### File 3: Interface.svelte (Admin Settings)

**Path:** `src/lib/components/admin/Settings/Interface.svelte`

#### 3.1 Add to taskConfig object

```typescript
let taskConfig = {
    // ... existing fields ...
    TOOLS_FUNCTION_CALLING_PROMPT_TEMPLATE: '',
    ENABLE_RESEARCH_MODE: true,
    ENABLE_AGENTIC_MODE: true
};
```

#### 3.2 Add toggle switches in UI section

**Location:** After Banners section, before Default Prompt Suggestions

```svelte
<div class="mb-2.5 flex w-full items-center justify-between">
    <div class=" self-center text-xs font-medium">
        {$i18n.t('Research Mode Button')}
    </div>

    <Tooltip content={$i18n.t('Enable Research and Research+ buttons in chat input')}>
        <Switch bind:state={taskConfig.ENABLE_RESEARCH_MODE} />
    </Tooltip>
</div>

<div class="mb-2.5 flex w-full items-center justify-between">
    <div class=" self-center text-xs font-medium">
        {$i18n.t('Agentic Mode Button')}
    </div>

    <Tooltip content={$i18n.t('Enable Agentic, Agentic+, and Pure LLM buttons in chat input')}>
        <Switch bind:state={taskConfig.ENABLE_AGENTIC_MODE} />
    </Tooltip>
</div>
```

---

## Backend Changes

### File 4: config.py

**Path:** `backend/open_webui/config.py`

**Location:** After `ENABLE_AUTOCOMPLETE_GENERATION`

```python
ENABLE_RESEARCH_MODE = PersistentConfig(
    "ENABLE_RESEARCH_MODE",
    "ui.research_mode.enable",
    os.environ.get("ENABLE_RESEARCH_MODE", "True").lower() == "true",
)

ENABLE_AGENTIC_MODE = PersistentConfig(
    "ENABLE_AGENTIC_MODE",
    "ui.agentic_mode.enable",
    os.environ.get("ENABLE_AGENTIC_MODE", "True").lower() == "true",
)
```

---

### File 5: tasks.py

**Path:** `backend/open_webui/routers/tasks.py`

#### 5.1 Add to get_task_config response

```python
@router.get("/config")
async def get_task_config(request: Request, user=Depends(get_verified_user)):
    return {
        # ... existing fields ...
        "TOOLS_FUNCTION_CALLING_PROMPT_TEMPLATE": request.app.state.config.TOOLS_FUNCTION_CALLING_PROMPT_TEMPLATE,
        "ENABLE_RESEARCH_MODE": request.app.state.config.ENABLE_RESEARCH_MODE,
        "ENABLE_AGENTIC_MODE": request.app.state.config.ENABLE_AGENTIC_MODE,
    }
```

#### 5.2 Add to TaskConfigForm Pydantic model

```python
class TaskConfigForm(BaseModel):
    # ... existing fields ...
    TOOLS_FUNCTION_CALLING_PROMPT_TEMPLATE: str
    ENABLE_RESEARCH_MODE: bool
    ENABLE_AGENTIC_MODE: bool
```

#### 5.3 Add to update_task_config handler

```python
@router.post("/config/update")
async def update_task_config(
    request: Request, form_data: TaskConfigForm, user=Depends(get_admin_user)
):
    # ... existing assignments ...
    request.app.state.config.TOOLS_FUNCTION_CALLING_PROMPT_TEMPLATE = (
        form_data.TOOLS_FUNCTION_CALLING_PROMPT_TEMPLATE
    )

    request.app.state.config.ENABLE_RESEARCH_MODE = form_data.ENABLE_RESEARCH_MODE
    request.app.state.config.ENABLE_AGENTIC_MODE = form_data.ENABLE_AGENTIC_MODE

    return {
        # ... existing fields ...
        "TOOLS_FUNCTION_CALLING_PROMPT_TEMPLATE": request.app.state.config.TOOLS_FUNCTION_CALLING_PROMPT_TEMPLATE,
        "ENABLE_RESEARCH_MODE": request.app.state.config.ENABLE_RESEARCH_MODE,
        "ENABLE_AGENTIC_MODE": request.app.state.config.ENABLE_AGENTIC_MODE,
    }
```

---

### File 6: main.py

**Path:** `backend/open_webui/main.py`

#### 6.1 Add imports

```python
from open_webui.config import (
    # ... existing imports ...
    ENABLE_AUTOCOMPLETE_GENERATION,
    ENABLE_RESEARCH_MODE,
    ENABLE_AGENTIC_MODE,
    TITLE_GENERATION_PROMPT_TEMPLATE,
    # ...
)
```

#### 6.2 Add app.state.config initialization

```python
app.state.config.ENABLE_TAGS_GENERATION = ENABLE_TAGS_GENERATION
app.state.config.ENABLE_TITLE_GENERATION = ENABLE_TITLE_GENERATION
app.state.config.ENABLE_FOLLOW_UP_GENERATION = ENABLE_FOLLOW_UP_GENERATION
app.state.config.ENABLE_RESEARCH_MODE = ENABLE_RESEARCH_MODE
app.state.config.ENABLE_AGENTIC_MODE = ENABLE_AGENTIC_MODE
```

---

## Summary

### Button Behavior

| Button | States | Tags Injected | Colors |
|--------|--------|---------------|--------|
| Research | Off → Research → Research+ | None / `[[research_request]]` / `[[research_deeply]]` | Gray → Blue → Red |
| Agentic | Pure LLM ↔ Agentic | `[[pure_llm]]` (default) / `[[autonomous]]` | Gray (default) → Blue |

### Admin Controls

- **Settings → Interface → Research Mode Button** - Toggles visibility and tag injection for Research/Research+
- **Settings → Interface → Agentic Mode Button** - Toggles visibility and tag injection for Pure LLM/Agentic

### Environment Variables (Optional)

Can be set in `.env` or Docker environment:
```
ENABLE_RESEARCH_MODE=True   # Default: True
ENABLE_AGENTIC_MODE=True    # Default: True
```

---

## Rebuilding

After making changes, rebuild the container:

```bash
cd /path/to/robaitools
docker compose up -d --build open-webui
```

---

## Testing

1. Open Admin Settings → Interface
2. Verify "Research Mode Button" and "Agentic Mode Button" toggles appear in UI section
3. Toggle them off and click Save
4. Open a new chat - buttons should be hidden
5. Toggle them back on, Save, refresh - buttons should appear
6. Click Research button to cycle through modes (check colors change)
7. Click Agentic button to cycle through modes
8. Send a message and verify backend receives the `[[tag]]` prefix

---

**Document Version:** 3.0
**Updated:** 2025-11-27
**Author:** Claude Code

## Changelog

### v3.0 (2025-11-27)
- Removed Agentic+ mode (was `[[autonomous_plus]]`)
- Changed Agentic button to 2-state toggle: Pure LLM ↔ Agentic
- Changed default to Pure LLM (gray) instead of Agentic
- Agentic mode now highlighted in blue when active
- Renamed variable from `pureLlmEnabled` to `agenticMode`

### v2.0 (2025-11-25)
- Initial implementation with 3-state Agentic button
