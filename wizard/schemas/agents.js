const SCHEMA_AGENTS = {
  id: "agents",
  titleKey: "section.agents.title",
  descKey: "section.agents.desc",
  stepKey: "stepAgents",
  fields: [
    {
      key: "agents.defaults.model.primary",
      labelKey: "field.primary.label",
      helpKey: "field.primary.help",
      type: "auto",
      readonly: true,
    },
    {
      key: "agents.defaults.heartbeat.every",
      labelKey: "field.heartbeat.label",
      helpKey: "field.heartbeat.help",
      type: "select",
      options: [
        { value: "1h", labelKey: "opt.1h" },
        { value: "2h", labelKey: "opt.2h" },
        { value: "4h", labelKey: "opt.4h" },
        { value: "8h", labelKey: "opt.8h" },
        { value: "off", labelKey: "opt.off" },
      ],
    },
    {
      key: "agents.defaults.maxConcurrent",
      labelKey: "field.maxConcurrent.label",
      helpKey: "field.maxConcurrent.help",
      type: "select",
      options: [
        { value: 2, labelKey: "opt.concurrent2" },
        { value: 4, labelKey: "opt.concurrent4" },
        { value: 8, labelKey: "opt.concurrent8" },
      ],
    },
  ],
};
