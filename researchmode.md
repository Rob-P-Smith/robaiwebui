# Research Mode Button Implementation for Open WebUI

This document details all changes made to add a research mode button to Open WebUI that prepends `<research_request>` to user prompts when active.

## Date: 2025-11-17

## Overview

The research mode button sits directly to the right of the integration menu button in the message input area. When active, it automatically prepends `<research_request>\n` to all user prompts before sending them to the backend.

---

## File 1: MessageInput.svelte

**Path:** `robaiwebui/open-webui/src/lib/components/chat/MessageInput.svelte`

### Change 1.1: Add researchModeEnabled state variable

**Location:** Line 108-111 (after codeInterpreterEnabled declaration)

**Original Code:**
```typescript
	export let imageGenerationEnabled = false;
	export let webSearchEnabled = false;
	export let codeInterpreterEnabled = false;
```

**Updated Code:**
```typescript
	export let imageGenerationEnabled = false;
	export let webSearchEnabled = false;
	export let codeInterpreterEnabled = false;
	export let researchModeEnabled = false;
```

---

### Change 1.2: Update onChange reactive statement

**Location:** Line 127-144

**Original Code:**
```typescript
	$: onChange({
		prompt,
		files: files
			.filter((file) => file.type !== 'image')
			.map((file) => {
				return {
					...file,
					user: undefined,
					access_control: undefined
				};
			}),
		selectedToolIds,
		selectedFilterIds,
		imageGenerationEnabled,
		webSearchEnabled,
		codeInterpreterEnabled
	});
```

**Updated Code:**
```typescript
	$: onChange({
		prompt,
		files: files
			.filter((file) => file.type !== 'image')
			.map((file) => {
				return {
					...file,
					user: undefined,
					access_control: undefined
				};
			}),
		selectedToolIds,
		selectedFilterIds,
		imageGenerationEnabled,
		webSearchEnabled,
		codeInterpreterEnabled,
		researchModeEnabled
	});
```

---

### Change 1.3: Add preparePromptForSubmit helper function

**Location:** Line 296-301 (after replaceVariables function)

**Original Code:**
```typescript
	const replaceVariables = (variables: Record<string, any>) => {
		console.log('Replacing variables:', variables);

		const chatInput = document.getElementById('chat-input');

		if (chatInput) {
			chatInputElement.replaceVariables(variables);
			chatInputElement.focus();
		}
	};

	export const setText = async (text?: string, cb?: (text: string) => void) => {
```

**Updated Code:**
```typescript
	const replaceVariables = (variables: Record<string, any>) => {
		console.log('Replacing variables:', variables);

		const chatInput = document.getElementById('chat-input');

		if (chatInput) {
			chatInputElement.replaceVariables(variables);
			chatInputElement.focus();
		}
	};

	const preparePromptForSubmit = (text: string): string => {
		if (researchModeEnabled && text.trim() !== '') {
			return `<research_request>\n${text}`;
		}
		return text;
	};

	export const setText = async (text?: string, cb?: (text: string) => void) => {
```

---

### Change 1.4: Update speech auto-send dispatch

**Location:** Line 1050-1052

**Original Code:**
```typescript
								if ($settings?.speechAutoSend ?? false) {
									dispatch('submit', prompt);
								}
```

**Updated Code:**
```typescript
								if ($settings?.speechAutoSend ?? false) {
									dispatch('submit', preparePromptForSubmit(prompt));
								}
```

---

### Change 1.5: Update form submit dispatch

**Location:** Line 1056-1062

**Original Code:**
```typescript
					<form
						class="w-full flex flex-col gap-1.5 {recording ? 'hidden' : ''}"
						on:submit|preventDefault={() => {
							// check if selectedModels support image input
							dispatch('submit', prompt);
						}}
					>
```

**Updated Code:**
```typescript
					<form
						class="w-full flex flex-col gap-1.5 {recording ? 'hidden' : ''}"
						on:submit|preventDefault={() => {
							// check if selectedModels support image input
							dispatch('submit', preparePromptForSubmit(prompt));
						}}
					>
```

---

### Change 1.6: Update Enter key press dispatch

**Location:** Line 1310-1315

**Original Code:**
```typescript
																if (enterPressed) {
																	e.preventDefault();
																	if (prompt !== '' || files.length > 0) {
																		dispatch('submit', prompt);
																	}
																}
```

**Updated Code:**
```typescript
																if (enterPressed) {
																	e.preventDefault();
																	if (prompt !== '' || files.length > 0) {
																		dispatch('submit', preparePromptForSubmit(prompt));
																	}
																}
```

---

### Change 1.7: Update Escape key handler

**Location:** Line 1319-1329

**Original Code:**
```typescript
														if (e.key === 'Escape') {
															console.log('Escape');
															atSelectedModel = undefined;
															selectedToolIds = [];
															selectedFilterIds = [];

															webSearchEnabled = false;
															imageGenerationEnabled = false;
															codeInterpreterEnabled = false;
														}
```

**Updated Code:**
```typescript
														if (e.key === 'Escape') {
															console.log('Escape');
															atSelectedModel = undefined;
															selectedToolIds = [];
															selectedFilterIds = [];

															webSearchEnabled = false;
															imageGenerationEnabled = false;
															codeInterpreterEnabled = false;
															researchModeEnabled = false;
														}
```

---

### Change 1.8: Add research mode button UI

**Location:** Line 1484-1521 (after IntegrationsMenu closing tag)

**Original Code:**
```svelte
											<div
												id="integration-menu-button"
												class="bg-transparent hover:bg-gray-100 text-gray-700 dark:text-white dark:hover:bg-gray-800 rounded-full size-8 flex justify-center items-center outline-hidden focus:outline-hidden"
											>
												<Component className="size-4.5" strokeWidth="1.5" />
											</div>
										</IntegrationsMenu>
									{/if}

									{#if selectedModelIds.length === 1 && $models.find((m) => m.id === selectedModelIds[0])?.has_user_valves}
```

**Updated Code:**
```svelte
											<div
												id="integration-menu-button"
												class="bg-transparent hover:bg-gray-100 text-gray-700 dark:text-white dark:hover:bg-gray-800 rounded-full size-8 flex justify-center items-center outline-hidden focus:outline-hidden"
											>
												<Component className="size-4.5" strokeWidth="1.5" />
											</div>
										</IntegrationsMenu>

										<Tooltip content={$i18n.t('Research Mode')} placement="top">
											<button
												id="research-mode-button"
												type="button"
												on:click|preventDefault={() => (researchModeEnabled = !researchModeEnabled)}
												class="rounded-full size-8 flex justify-center items-center outline-hidden focus:outline-hidden transition-colors duration-200 {researchModeEnabled
													? 'text-blue-600 dark:text-blue-400 border border-blue-600 dark:border-blue-400 bg-transparent hover:bg-blue-50 dark:hover:bg-blue-950/30'
													: 'bg-transparent hover:bg-gray-100 text-gray-700 dark:text-white dark:hover:bg-gray-800 border border-transparent'}"
												aria-label={researchModeEnabled
													? $i18n.t('Disable Research Mode')
													: $i18n.t('Enable Research Mode')}
												aria-pressed={researchModeEnabled}
											>
												<svg
													xmlns="http://www.w3.org/2000/svg"
													fill="none"
													viewBox="0 0 24 24"
													stroke-width="1.5"
													stroke="currentColor"
													class="size-4.5"
												>
													<path
														stroke-linecap="round"
														stroke-linejoin="round"
														d="M9.75 3.104v5.714a2.25 2.25 0 01-.659 1.591L5 14.5M9.75 3.104c-.251.023-.501.05-.75.082m.75-.082a24.301 24.301 0 014.5 0m0 0v5.714c0 .597.237 1.17.659 1.591L19.8 15.3M14.25 3.104c.251.023.501.05.75.082M19.8 15.3l-1.57.393A9.065 9.065 0 0112 15a9.065 9.065 0 00-6.23-.693L5 14.5m14.8.8l1.402 1.402c1.232 1.232.65 3.318-1.067 3.611A48.309 48.309 0 0112 21c-2.773 0-5.491-.235-8.135-.687-1.718-.293-2.3-2.379-1.067-3.61L5 14.5"
													/>
												</svg>
											</button>
										</Tooltip>
									{/if}

									{#if selectedModelIds.length === 1 && $models.find((m) => m.id === selectedModelIds[0])?.has_user_valves}
```

---

## File 2: Chat.svelte

**Path:** `robaiwebui/open-webui/src/lib/components/chat/Chat.svelte`

### Change 2.1: Add researchModeEnabled state variable

**Location:** Line 131-136

**Original Code:**
```typescript
	let selectedToolIds = [];
	let selectedFilterIds = [];
	let imageGenerationEnabled = false;
	let webSearchEnabled = false;
	let codeInterpreterEnabled = false;
```

**Updated Code:**
```typescript
	let selectedToolIds = [];
	let selectedFilterIds = [];
	let imageGenerationEnabled = false;
	let webSearchEnabled = false;
	let codeInterpreterEnabled = false;
	let researchModeEnabled = false;
```

---

### Change 2.2: Reset research mode in navigateHandler

**Location:** Line 169-175

**Original Code:**
```typescript
		files = [];
		selectedToolIds = [];
		selectedFilterIds = [];
		webSearchEnabled = false;
		imageGenerationEnabled = false;

		const storageChatInput = sessionStorage.getItem(
```

**Updated Code:**
```typescript
		files = [];
		selectedToolIds = [];
		selectedFilterIds = [];
		webSearchEnabled = false;
		imageGenerationEnabled = false;
		researchModeEnabled = false;

		const storageChatInput = sessionStorage.getItem(
```

---

### Change 2.3: Restore research mode from sessionStorage (first occurrence)

**Location:** Line 187-198

**Original Code:**
```typescript
				if (!$temporaryChatEnabled) {
					messageInput?.setText(input.prompt);
					files = input.files;
					selectedToolIds = input.selectedToolIds;
					selectedFilterIds = input.selectedFilterIds;
					webSearchEnabled = input.webSearchEnabled;
					imageGenerationEnabled = input.imageGenerationEnabled;
					codeInterpreterEnabled = input.codeInterpreterEnabled;
				}
```

**Updated Code:**
```typescript
				if (!$temporaryChatEnabled) {
					messageInput?.setText(input.prompt);
					files = input.files;
					selectedToolIds = input.selectedToolIds;
					selectedFilterIds = input.selectedFilterIds;
					webSearchEnabled = input.webSearchEnabled;
					imageGenerationEnabled = input.imageGenerationEnabled;
					codeInterpreterEnabled = input.codeInterpreterEnabled;
					researchModeEnabled = input.researchModeEnabled ?? false;
				}
```

---

### Change 2.4: Reset research mode in resetInput function

**Location:** Line 255-264

**Original Code:**
```typescript
	const resetInput = () => {
		selectedToolIds = [];
		selectedFilterIds = [];
		webSearchEnabled = false;
		imageGenerationEnabled = false;
		codeInterpreterEnabled = false;

		setDefaults();
	};
```

**Updated Code:**
```typescript
	const resetInput = () => {
		selectedToolIds = [];
		selectedFilterIds = [];
		webSearchEnabled = false;
		imageGenerationEnabled = false;
		codeInterpreterEnabled = false;
		researchModeEnabled = false;

		setDefaults();
	};
```

---

### Change 2.5: Reset research mode in second sessionStorage restore

**Location:** Line 576-583

**Original Code:**
```typescript
			files = [];
			selectedToolIds = [];
			selectedFilterIds = [];
			webSearchEnabled = false;
			imageGenerationEnabled = false;
			codeInterpreterEnabled = false;

			try {
```

**Updated Code:**
```typescript
			files = [];
			selectedToolIds = [];
			selectedFilterIds = [];
			webSearchEnabled = false;
			imageGenerationEnabled = false;
			codeInterpreterEnabled = false;
			researchModeEnabled = false;

			try {
```

---

### Change 2.6: Restore research mode from sessionStorage (second occurrence)

**Location:** Line 587-594

**Original Code:**
```typescript
				if (!$temporaryChatEnabled) {
					messageInput?.setText(input.prompt);
					files = input.files;
					selectedToolIds = input.selectedToolIds;
					selectedFilterIds = input.selectedFilterIds;
					webSearchEnabled = input.webSearchEnabled;
					imageGenerationEnabled = input.imageGenerationEnabled;
					codeInterpreterEnabled = input.codeInterpreterEnabled;
				}
```

**Updated Code:**
```typescript
				if (!$temporaryChatEnabled) {
					messageInput?.setText(input.prompt);
					files = input.files;
					selectedToolIds = input.selectedToolIds;
					selectedFilterIds = input.selectedFilterIds;
					webSearchEnabled = input.webSearchEnabled;
					imageGenerationEnabled = input.imageGenerationEnabled;
					codeInterpreterEnabled = input.codeInterpreterEnabled;
					researchModeEnabled = input.researchModeEnabled ?? false;
				}
```

---

### Change 2.7: Bind researchModeEnabled to MessageInput component

**Location:** Line 2524-2543

**Original Code:**
```svelte
								<MessageInput
									bind:this={messageInput}
									{history}
									{taskIds}
									{selectedModels}
									bind:files
									bind:prompt
									bind:autoScroll
									bind:selectedToolIds
									bind:selectedFilterIds
									bind:imageGenerationEnabled
									bind:codeInterpreterEnabled
									bind:webSearchEnabled
									bind:atSelectedModel
									bind:showCommands
									toolServers={$toolServers}
									{generating}
									{stopResponse}
									{createMessagePair}
```

**Updated Code:**
```svelte
								<MessageInput
									bind:this={messageInput}
									{history}
									{taskIds}
									{selectedModels}
									bind:files
									bind:prompt
									bind:autoScroll
									bind:selectedToolIds
									bind:selectedFilterIds
									bind:imageGenerationEnabled
									bind:codeInterpreterEnabled
									bind:webSearchEnabled
									bind:researchModeEnabled
									bind:atSelectedModel
									bind:showCommands
									toolServers={$toolServers}
									{generating}
									{stopResponse}
									{createMessagePair}
```

---

## File 3: Placeholder.svelte

**Path:** `robaiwebui/open-webui/src/lib/components/chat/Placeholder.svelte`

### Change 3.1: Add researchModeEnabled export

**Location:** Line 51-56

**Original Code:**
```typescript
	export let showCommands = false;

	export let imageGenerationEnabled = false;
	export let codeInterpreterEnabled = false;
	export let webSearchEnabled = false;
```

**Updated Code:**
```typescript
	export let showCommands = false;

	export let imageGenerationEnabled = false;
	export let codeInterpreterEnabled = false;
	export let webSearchEnabled = false;
	export let researchModeEnabled = false;
```

---

### Change 3.2: Bind researchModeEnabled to MessageInput component

**Location:** Line 205-217

**Original Code:**
```svelte
				<MessageInput
					bind:this={messageInput}
					{history}
					{selectedModels}
					bind:files
					bind:prompt
					bind:autoScroll
					bind:selectedToolIds
					bind:selectedFilterIds
					bind:imageGenerationEnabled
					bind:codeInterpreterEnabled
					bind:webSearchEnabled
```

**Updated Code:**
```svelte
				<MessageInput
					bind:this={messageInput}
					{history}
					{selectedModels}
					bind:files
					bind:prompt
					bind:autoScroll
					bind:selectedToolIds
					bind:selectedFilterIds
					bind:imageGenerationEnabled
					bind:codeInterpreterEnabled
					bind:webSearchEnabled
					bind:researchModeEnabled
```

---

## Summary of Changes

### Files Modified:
1. `robaiwebui/open-webui/src/lib/components/chat/MessageInput.svelte` - 8 changes
2. `robaiwebui/open-webui/src/lib/components/chat/Chat.svelte` - 7 changes
3. `robaiwebui/open-webui/src/lib/components/chat/Placeholder.svelte` - 2 changes

### Total Changes: 17

### Key Features:
- **Button Location**: Directly to the right of the integration menu button
- **Icon**: Flask/beaker SVG (research symbol)
- **Active State**: Cornflower blue text and border (`text-blue-600 dark:text-blue-400` with `border-blue-600 dark:border-blue-400`)
- **Inactive State**: Theme-based colors with transparent border
- **Functionality**: Prepends `<research_request>\n` to all user prompts when enabled
- **Persistence**: Saved to sessionStorage along with other input state
- **Keyboard Support**: Reset with Escape key
- **Accessibility**: Full ARIA labels and pressed state

### To Apply Changes:

After making these code changes, rebuild the Open WebUI Docker container:

```bash
docker compose build open-webui
docker compose restart open-webui
```

### Testing:

1. Load Open WebUI in your browser
2. Look for the flask icon button next to the integration menu (diamond icon)
3. Click to enable research mode - button should turn blue
4. Type a message and send it
5. Verify the backend receives `<research_request>\n` prepended to the message
6. Press Escape to reset (button should return to default state)
7. Refresh page and verify state persists if saved in sessionStorage

---

**Document Version:** 1.0
**Created:** 2025-11-17
**Author:** Claude Code
