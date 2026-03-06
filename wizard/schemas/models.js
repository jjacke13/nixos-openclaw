const SCHEMA_MODELS = {
  id: "models",
  titleKey: "section.models.title",
  descKey: "section.models.desc",
  stepKey: "stepModels",
  fields: [
    {
      key: "models.providers.__name__",
      labelKey: "field.provider.label",
      helpKey: "field.provider.help",
      type: "select",
      options: [
        { value: "ppq", labelKey: "opt.ppq" },
        { value: "openrouter", labelKey: "opt.openrouter" },
        { value: "openai", labelKey: "opt.openai" },
        { value: "anthropic", labelKey: "opt.anthropic" },
        { value: "custom", labelKey: "opt.custom" },
      ],
    },
    {
      key: "models.providers.__name__.baseUrl",
      labelKey: "field.baseUrl.label",
      helpKey: "field.baseUrl.help",
      type: "text",
      placeholder: "https://api.example.com/v1",
      showWhen: { key: "models.providers.__name__", value: "custom" },
      providerDefaults: {
        ppq: "https://api.ppq.ai",
        openrouter: "https://openrouter.ai/api/v1",
        openai: "https://api.openai.com/v1",
        anthropic: "https://api.anthropic.com",
        custom: "",
      },
    },
    {
      key: "models.providers.__name__.apiKey",
      labelKey: "field.apiKey.label",
      helpKey: "field.apiKey.help",
      placeholderKey: "field.apiKey.placeholder",
      type: "password",
      hideWhen: { key: "models.providers.__name__", value: "ppq" },
    },
    {
      key: "models.providers.__name__.api",
      labelKey: "field.apiFormat.label",
      helpKey: "field.apiFormat.help",
      type: "select",
      options: [
        { value: "openai-completions", labelKey: "opt.openai-completions" },
        { value: "anthropic", labelKey: "opt.anthropic-native" },
      ],
      providerDefaults: {
        ppq: "openai-completions",
        openrouter: "openai-completions",
        openai: "openai-completions",
        anthropic: "anthropic",
        custom: "openai-completions",
      },
    },
    {
      key: "models.providers.__name__.models",
      labelKey: "field.model.label",
      helpKey: "field.model.help",
      type: "model-select",
      fallbackModels: {
        ppq: [
          { id: "gemini-2.5-flash", name: "Gemini 2.5 Flash", descKey: "model.fast", reasoning: false, contextWindow: 200000 },
          { id: "gemini-2.5-pro", name: "Gemini 2.5 Pro", descKey: "model.capable", reasoning: true, contextWindow: 200000 },
          { id: "claude-sonnet-4-5", name: "Claude Sonnet 4.5", descKey: "model.balanced", reasoning: false, contextWindow: 200000 },
          { id: "gpt-4.1", name: "GPT-4.1", descKey: "model.latest", reasoning: false, contextWindow: 128000 },
        ],
        openrouter: [
          { id: "google/gemini-2.5-flash", name: "Gemini 2.5 Flash", descKey: "model.fast", reasoning: false, contextWindow: 200000 },
          { id: "anthropic/claude-sonnet-4-5", name: "Claude Sonnet 4.5", descKey: "model.balanced", reasoning: false, contextWindow: 200000 },
          { id: "openai/gpt-4.1", name: "GPT-4.1", descKey: "model.latest", reasoning: false, contextWindow: 128000 },
        ],
        openai: [
          { id: "gpt-4.1", name: "GPT-4.1", descKey: "model.most-capable", reasoning: false, contextWindow: 128000 },
          { id: "gpt-4.1-mini", name: "GPT-4.1 Mini", descKey: "model.cheaper", reasoning: false, contextWindow: 128000 },
        ],
        anthropic: [
          { id: "claude-sonnet-4-5", name: "Claude Sonnet 4.5", descKey: "model.balanced", reasoning: false, contextWindow: 200000 },
          { id: "claude-opus-4-5", name: "Claude Opus 4.5", descKey: "model.most-capable", reasoning: false, contextWindow: 200000 },
        ],
      },
    },
  ],
};
