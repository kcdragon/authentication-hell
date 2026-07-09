<!--
  Marks a slide as scaffold/placeholder content. Renders a corner badge plus
  a dashed-border overlay strip so it's impossible to miss on-screen and easy
  to grep out later: search the deck for `<Placeholder` and delete every slide
  that has one (keep the cover + the final "Let's Play!" slide).
-->
<template>
  <div class="ah-placeholder">
    <span class="ah-placeholder__badge">⚠ Placeholder — replace or remove</span>
  </div>
</template>

<style scoped>
.ah-placeholder {
  position: absolute;
  inset: 0;
  pointer-events: none;
  /* dashed red frame around the whole slide */
  border: 4px dashed var(--color-error);
  z-index: 40;
}
.ah-placeholder__badge {
  position: absolute;
  top: 0;
  right: 0;
  font-family: var(--font-sans);
  font-weight: 700;
  font-size: 0.72rem;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: #fff;
  background: var(--color-error);
  border-left: 3px solid var(--color-ink);
  border-bottom: 3px solid var(--color-ink);
  padding: 0.4em 0.7em;
}
</style>
