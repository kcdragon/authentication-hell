// The live-demo slide embeds the game from localhost:3000, whose WASM needs
// SharedArrayBuffer. That requires the *top-level* page (this deck) to be
// cross-origin isolated too. `credentialless` (not `require-corp`) so remote
// images in the deck keep loading without CORP headers.
export default {
  server: {
    headers: {
      "Cross-Origin-Opener-Policy": "same-origin",
      "Cross-Origin-Embedder-Policy": "credentialless",
    },
  },
}
