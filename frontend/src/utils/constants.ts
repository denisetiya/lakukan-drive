const name: string = window.LakukanDrive.Name || "Lakukan Drive";
const disableExternal: boolean = window.LakukanDrive.DisableExternal;
const disableUsedPercentage: boolean =
  window.LakukanDrive.DisableUsedPercentage;
const baseURL: string = window.LakukanDrive.BaseURL;
const staticURL: string = window.LakukanDrive.StaticURL;
const recaptcha: string = window.LakukanDrive.ReCaptcha;
const recaptchaKey: string = window.LakukanDrive.ReCaptchaKey;
const signup: boolean = window.LakukanDrive.Signup;
const version: string = window.LakukanDrive.Version;
const logoURL = `${staticURL}/img/logo.svg`;
const noAuth: boolean = window.LakukanDrive.NoAuth;
const authMethod = window.LakukanDrive.AuthMethod;
const logoutPage: string = window.LakukanDrive.LogoutPage;
const loginPage: boolean = window.LakukanDrive.LoginPage;
const theme: UserTheme = window.LakukanDrive.Theme;
const enableThumbs: boolean = window.LakukanDrive.EnableThumbs;
const resizePreview: boolean = window.LakukanDrive.ResizePreview;
const enableExec: boolean = window.LakukanDrive.EnableExec;
const tusSettings = window.LakukanDrive.TusSettings;
const origin = window.location.origin;
const tusEndpoint = `/api/tus`;
const hideLoginButton = window.LakukanDrive.HideLoginButton;

export {
  name,
  disableExternal,
  disableUsedPercentage,
  baseURL,
  logoURL,
  recaptcha,
  recaptchaKey,
  signup,
  version,
  noAuth,
  authMethod,
  logoutPage,
  loginPage,
  theme,
  enableThumbs,
  resizePreview,
  enableExec,
  tusSettings,
  origin,
  tusEndpoint,
  hideLoginButton,
};
