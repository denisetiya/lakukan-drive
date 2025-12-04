<template>
  <div id="login" :class="{ recaptcha: recaptcha }">
    <!-- Background decoration -->
    <div class="login__background">
      <div class="login__bg-shapes">
        <div class="login__shape login__shape--1"></div>
        <div class="login__shape login__shape--2"></div>
        <div class="login__shape login__shape--3"></div>
      </div>
    </div>

    <!-- Main login container -->
    <div class="login__container">
      <div class="login__card">
        <!-- Logo and title -->
        <div class="login__header">
          <div class="login__logo-container">
            <img :src="logoURL" alt="Lakukan Drive" class="login__logo" />
            <div class="login__logo-glow"></div>
          </div>
          <h1 class="login__title">{{ name }}</h1>
          <p class="login__subtitle">
            {{
              createMode
                ? t("login.createAccountSubtitle")
                : t("login.welcomeSubtitle")
            }}
          </p>
        </div>

        <!-- Logout message -->
        <div v-if="reason != null" class="login__message login__message--info">
          <div class="login__message-icon">
            <i class="material-icons">info</i>
          </div>
          <div class="login__message-content">
            {{ t(`login.logout_reasons.${reason}`) }}
          </div>
        </div>

        <!-- Error message -->
        <div v-if="error !== ''" class="login__message login__message--error">
          <div class="login__message-icon">
            <i class="material-icons">error</i>
          </div>
          <div class="login__message-content">
            {{ error }}
          </div>
        </div>

        <!-- Form -->
        <form @submit="submit" class="login__form">
          <div class="login__input-group">
            <div class="login__input-wrapper">
              <i class="material-icons login__input-icon">person</i>
              <input
                autofocus
                class="login__input"
                type="text"
                autocapitalize="off"
                v-model="username"
                :placeholder="t('login.username')"
                required
              />
              <div class="login__input-border"></div>
            </div>
          </div>

          <div class="login__input-group">
            <div class="login__input-wrapper">
              <i class="material-icons login__input-icon">lock</i>
              <input
                class="login__input"
                type="password"
                v-model="password"
                :placeholder="t('login.password')"
                required
              />
              <div class="login__input-border"></div>
            </div>
          </div>

          <div v-if="createMode" class="login__input-group">
            <div class="login__input-wrapper">
              <i class="material-icons login__input-icon">lock_outline</i>
              <input
                class="login__input"
                type="password"
                v-model="passwordConfirm"
                :placeholder="t('login.passwordConfirm')"
                required
              />
              <div class="login__input-border"></div>
            </div>
          </div>

          <!-- Recaptcha -->
          <div v-if="recaptcha" class="login__recaptcha">
            <div id="recaptcha"></div>
          </div>

          <!-- Submit button -->
          <button type="submit" class="login__button" :disabled="isLoading">
            <span v-if="!isLoading" class="login__button-text">
              {{ createMode ? t("login.signup") : t("login.submit") }}
            </span>
            <div v-else class="login__spinner">
              <div class="login__spinner-dot"></div>
              <div class="login__spinner-dot"></div>
              <div class="login__spinner-dot"></div>
            </div>
            <div class="login__button-shine"></div>
          </button>
        </form>

        <!-- Toggle mode -->
        <div v-if="signup" class="login__toggle">
          <p @click="toggleMode" class="login__toggle-text">
            <span class="login__toggle-label">
              {{
                createMode
                  ? t("login.loginInstead")
                  : t("login.createAnAccount")
              }}
            </span>
            <i class="material-icons login__toggle-icon">
              {{ createMode ? "login" : "person_add" }}
            </i>
          </p>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { StatusError } from "@/api/utils";
import * as auth from "@/utils/auth";
import {
  name,
  logoURL,
  recaptcha,
  recaptchaKey,
  signup,
} from "@/utils/constants";
import { inject, onMounted, ref } from "vue";
import { useI18n } from "vue-i18n";
import { useRoute, useRouter } from "vue-router";

// Define refs
const createMode = ref<boolean>(false);
const error = ref<string>("");
const username = ref<string>("");
const password = ref<string>("");
const passwordConfirm = ref<string>("");
const isLoading = ref<boolean>(false);

const route = useRoute();
const router = useRouter();
const { t } = useI18n({});
// Define functions
const toggleMode = () => (createMode.value = !createMode.value);

const $showError = inject<IToastError>("$showError")!;

const reason = route.query["logout-reason"] ?? null;

const submit = async (event: Event) => {
  event.preventDefault();
  event.stopPropagation();

  isLoading.value = true;
  error.value = "";

  const redirect = (route.query.redirect || "/files/") as string;

  let captcha = "";
  if (recaptcha) {
    captcha = window.grecaptcha.getResponse();

    if (captcha === "") {
      error.value = t("login.wrongCredentials");
      isLoading.value = false;
      return;
    }
  }

  if (createMode.value) {
    if (password.value !== passwordConfirm.value) {
      error.value = t("login.passwordsDontMatch");
      isLoading.value = false;
      return;
    }
  }

  try {
    if (createMode.value) {
      await auth.signup(username.value, password.value);
    }

    await auth.login(username.value, password.value, captcha);
    router.push({ path: redirect });
  } catch (e: any) {
    // console.error(e);
    if (e instanceof StatusError) {
      if (e.status === 409) {
        error.value = t("login.usernameTaken");
      } else if (e.status === 403) {
        error.value = t("login.wrongCredentials");
      } else if (e.status === 400) {
        const match = e.message.match(/minimum length is (\d+)/);
        if (match) {
          error.value = t("login.passwordTooShort", { min: match[1] });
        } else {
          error.value = e.message;
        }
      } else {
        $showError(e);
      }
    }
  } finally {
    isLoading.value = false;
  }
};

// Run hooks
onMounted(() => {
  if (!recaptcha) return;

  window.grecaptcha.ready(function () {
    window.grecaptcha.render("recaptcha", {
      sitekey: recaptchaKey,
    });
  });
});
</script>
