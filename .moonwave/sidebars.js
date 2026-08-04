// Order of the prose docs in the sidebar.
//
// Without this file Docusaurus autogenerates the sidebar alphabetically, which
// opens the documentation on the backlog and buries the GDD in the middle.
// Reading order is design first, then how it is built, then what is left to do.
//
// Moonwave copies this to the generated site as its `sidebarPath`. The API
// reference has its own generated sidebar and is not affected by this file.
// Ids are the file names in docs/ without the extension.

module.exports = {
  defaultSidebar: [
    "intro",
    {
      type: "category",
      label: "Diseño",
      collapsed: false,
      items: ["gdd", "arquitectura"],
    },
    {
      type: "category",
      label: "Ejecución",
      collapsed: false,
      items: ["plan-etapas", "backlog"],
    },
    {
      type: "category",
      label: "Sesiones de prueba",
      collapsed: false,
      items: ["prueba-etapa1", "prueba-diversion"],
    },
  ],
}
