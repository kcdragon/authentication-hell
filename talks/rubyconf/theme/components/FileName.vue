<!--
  A filename tab that fuses to the top of the code block that follows it.
  Place immediately BEFORE a code block or a ````md magic-move fence:

    <FileName>main.rb</FileName>

    ```ruby
    def tick(args)
    end
    ```

  It never wraps the code, so it stays compatible with magic-move (which is a
  compile-time markdown transform on the top-level fence).
-->
<template>
  <div class="ah-filename"><slot /></div>
</template>

<style scoped>
.ah-filename {
  display: inline-block;
  position: relative;
  z-index: 1;
  margin-bottom: -3px;           /* overlap the code block's top border */
  padding: 0.15em 0.7em;
  font-family: var(--font-mono);
  font-size: 0.8rem;
  font-weight: 700;
  color: var(--color-muted);
  background: var(--color-faint);
  border: 3px solid var(--color-ink);
  border-bottom: none;
  border-radius: 3px 3px 0 0;
}
</style>
