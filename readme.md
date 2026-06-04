# Audiobookphile Mobile App

Audiobookphile is a self-hosted audiobook and podcast server.

### Android (beta)

Get the Android app on the [Google Play Store](https://play.google.com/store/apps/details?id=com.audiobookphile.app)

### iOS (early beta)

**Beta is currently full. Apple has a hard limit of 10k beta testers. Updates will be posted in Discord.**

Using Test Flight: https://testflight.apple.com/join/wiic7QIW **_(beta is full)_**

---

[Go to the main project repo github.com/advplyr/audiobookphile](https://github.com/advplyr/audiobookphile) or the project site [audiobookphile.org](https://audiobookphile.org)

Join us on [discord](https://discord.gg/pJsjuNCKRq)

**Requires an Audiobookphile server to connect with**

<img alt="Screenshot" src="https://github.com/advplyr/audiobookphile-app/raw/master/screenshots/DeviceDemoScreens.png" />

## Contributing

This application is built using [NuxtJS](https://nuxtjs.org/), [Capacitor](https://capacitorjs.com/), and [Bun](https://bun.sh/) in order to run on both iOS and Android with rapid build times and native performance.

### Localization

Thank you to [Weblate](https://hosted.weblate.org/engage/audiobookphile/) for hosting our localization infrastructure pro-bono. If you want to see Audiobookphile in your language, please help us localize. Additional information on helping with the translations [here](https://www.audiobookphile.org/faq#how-do-i-help-with-translations). <a href="https://hosted.weblate.org/engage/audiobookphile/"> <img src="https://hosted.weblate.org/widget/audiobookphile/abs-mobile-app/horizontal-auto.svg" alt="Translation status" /> </a>

### Windows Environment Setup for Android

Required Software:

- [Git](https://git-scm.com/downloads)
- [Bun](https://bun.sh/) (or Node.js version 20 as fallback)
- Code editor of choice([VSCode](https://code.visualstudio.com/download), etc)
- [Android Studio](https://developer.android.com/studio)
- [Android SDK](https://developer.android.com/studio)

<details>
<summary>Install the required software with <a href=(https://docs.microsoft.com/en-us/windows/package-manager/winget/#production-recommended)>winget</a></summary>

<p>
Note: This requires a PowerShell prompt with winget installed.  You should be able to copy and paste the code block to install.  If you use an elevated PowerShell prompt, UAC will not pop up during the installs.

```PowerShell
winget install -e --id Git.Git; `
winget install -e --id Microsoft.VisualStudioCode; `
winget install -e --id  Google.AndroidStudio; `
winget install -e --id JarredSumner.Bun;
```

</p>
</details>
<br>

Your Windows environment should now be set up and ready to proceed!

### Mac Environment Setup for Android

Required Software:

- [Android Studio](https://developer.android.com/studio)
- [Bun](https://bun.sh/)
- [Cocoapods](https://guides.cocoapods.org/using/getting-started.html#installation)
- [Android SDK](https://developer.android.com/studio)

<details>
<summary>Install the required software with <a href=(https://brew.sh/)>homebrew</a></summary>

<p>

```zsh
brew install android-studio oven-sh/bun/bun cocoapods
```

</p>
</details>

### Start working on the Android app

Clone or fork the project from terminal or powershell and `cd` into the project directory.

Install the required node packages:

```shell
bun install
```

<br>

Generate static web app:

```shell
bun run generate
```

<br>

Copy web app into native android/ios folders:

```shell
bunx cap sync
```

<br>

Open Android Studio:

```shell
bunx cap open android
```

<br>

Start coding!

After making changes to the JS layer you need to rebuild the nuxt pages and sync them to the native shells:

```shell
bun run sync
```

### Mac Environment Setup for iOS

Required Software:

- [Xcode](https://developer.apple.com/xcode/)
- [Bun](https://bun.sh/)
- [Cocoapods](https://guides.cocoapods.org/using/getting-started.html#installation)

### Start working on the iOS app

Clone or fork the project in the terminal and `cd` into the project directory.

Install the required packages:

```shell
bun install
```

<br>

Generate static web app:

```shell
bun run generate
```

<br>

Copy web app into native android/ios folders:

```shell
bunx cap sync
```

<br>

Open Xcode:

```shell
bunx cap open ios
```

<br>

Start coding!

After making changes to the JS layer you need to rebuild the nuxt pages and sync them to the native shells:

```shell
bun run sync
```

---

## Xcode Cloud Build Pipeline

The iOS client uses **Xcode Cloud** for automated TestFlight building and distribution. The pipeline uses **Bun** in combination with Node.js in the post-clone script step for rapid compilation.

### How it Works (Post-Clone Shell)
When Xcode Cloud triggers a build, it executes the custom post-clone script located at `ios/App/ci_scripts/ci_post_clone.sh`. This script:
1. Installs Node.js via Homebrew (required to support capacitor shebang environments).
2. Installs Bun natively on the Apple build container.
3. Runs `bun install --frozen-lockfile` to install all packages.
4. Executes `bun run generate` to compile Nuxt static pages.
5. Runs `bunx cap sync ios` to move compile outputs into Xcode.
6. Installs CocoaPods dependencies via `pod install`.

### Environment Variables Setup
To allow Nuxt to bake the Supabase credentials into the client bundle at build-time, you **MUST** configure the following environment variables in your Xcode Cloud Workflow settings under the **Environment** tab:

| Variable | Description |
|---|---|
| `NUXT_ENV_SUPABASE_URL` | Your Supabase Project API URL (e.g. `https://xxxx.supabase.co`) |
| `NUXT_ENV_SUPABASE_ANON_KEY` | Your Supabase publishable anonymous key |

Ensure both are marked as **Required** in your Xcode Cloud workflow parameters so the build pipeline has access to them.

