<template>
  <div
    class="context-menu"
    ref="contextMenu"
    v-show="show"
    :style="{
      top: `${top}px`,
      left: `${left}px`,
    }"
  >
    <slot />
  </div>
</template>

<script setup lang="ts">
import { ref, watch, computed, onUnmounted } from "vue";

const emit = defineEmits(["hide"]);
const props = defineProps<{ show: boolean; pos: { x: number; y: number } }>();
const contextMenu = ref<HTMLElement | null>(null);

const left = computed(() => {
  const menuWidth = contextMenu.value?.clientWidth ?? 0;
  const maxLeft = window.scrollX + window.innerWidth - menuWidth;
  return Math.min(props.pos.x, maxLeft);
});

const top = computed(() => {
  const menuHeight = contextMenu.value?.clientHeight ?? 0;
  const minTop = window.scrollY;
  const maxTop = window.scrollY + window.innerHeight - menuHeight;
  return Math.min(Math.max(props.pos.y, minTop), maxTop);
});

const hideContextMenu = () => {
  emit("hide");
};

watch(
  () => props.show,
  (val) => {
    if (val) {
      document.addEventListener("click", hideContextMenu);
    } else {
      document.removeEventListener("click", hideContextMenu);
    }
  }
);

onUnmounted(() => {
  document.removeEventListener("click", hideContextMenu);
});
</script>
