<!--
  Wraps an image in the deck's ah-card (styled white card) and centers it.
  The recurring "header + card-wrapped screenshot" slide idiom.

    <Framed src="/images/page-structure.png" alt="..." />

  `imgClass` overrides the default sizing (block max-h-[340px] w-auto) for
  images that need width-based sizing instead, e.g. the wide discord reply.
  Stack multiple by passing the default slot instead of `src`.
-->
<script setup>
defineProps({
  src: { type: String, default: "" },
  alt: { type: String, default: "" },
  imgClass: { type: String, default: "block max-h-[340px] w-auto" },
})
</script>

<template>
  <div class="flex flex-col items-center gap-3 mt-6">
    <slot>
      <div class="ah-card bg-white p-2 leading-none">
        <img :src="src" :class="imgClass" :alt="alt" />
      </div>
    </slot>
  </div>
</template>
