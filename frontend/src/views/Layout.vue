<template>
  <div>
    <div v-if="uploadStore.totalBytes" class="progress">
      <div
        v-bind:style="{
          width: sentPercent + '%',
        }"
      ></div>
    </div>
    <sidebar></sidebar>
    <main>
      <router-view></router-view>
      <shell
        v-if="
          enableExec && authStore.isLoggedIn && authStore.user?.perm.execute
        "
      />
    </main>
    <prompts></prompts>
    <upload-files></upload-files>
  </div>
</template>

<script setup lang="ts">
import { useAuthStore } from "@/stores/auth";
import { useLayoutStore } from "@/stores/layout";
import { useFileStore } from "@/stores/file";
import { useUploadStore } from "@/stores/upload";
import Sidebar from "@/components/Sidebar.vue";
import Prompts from "@/components/prompts/Prompts.vue";
import Shell from "@/components/Shell.vue";
import UploadFiles from "@/components/prompts/UploadFiles.vue";
import { enableExec } from "@/utils/constants";
import { computed, onBeforeUnmount, ref, watch } from "vue";
import { useRoute } from "vue-router";

const layoutStore = useLayoutStore();
const authStore = useAuthStore();
const fileStore = useFileStore();
const uploadStore = useUploadStore();
const route = useRoute();
const previousSelectedCount = ref<number>(0);

const sentPercent = computed(() =>
  ((uploadStore.sentBytes / uploadStore.totalBytes) * 100).toFixed(2)
);

const syncMultiplePadding = (active: boolean) => {
  const app = document.getElementById("app");
  app?.classList.toggle("multiple", active);
};

watch(route, () => {
  fileStore.selected = [];
  fileStore.multiple = false;
  if (layoutStore.currentPromptName !== "success") {
    layoutStore.closeHovers();
  }
});

watch(
  () => fileStore.multiple,
  (active) => syncMultiplePadding(active),
  { immediate: true }
);

watch(
  () => fileStore.selectedCount,
  (count) => {
    if (fileStore.multiple && previousSelectedCount.value > 0 && count === 0) {
      fileStore.multiple = false;
    }
    previousSelectedCount.value = count;
  }
);

onBeforeUnmount(() => {
  syncMultiplePadding(false);
});
</script>
