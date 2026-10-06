# Movix pour iPhone

Application Swift/UIKit pour iOS 16 et versions suivantes. Une `WKWebView` ouvre automatiquement [movix.luxe](https://movix.luxe), avec retour, avance, accueil, rechargement, progression du chargement et une vue d’erreur permettant de réessayer.

Les cookies et les sessions utilisent le stockage persistant de WebKit. La lecture vidéo en ligne, le plein écran, le paysage et Picture in Picture dépendent également des possibilités et des règles du lecteur du site. Les protections HTTPS d’iOS restent actives : aucune exception ATS et aucun contournement des certificats.

## Téléchargement

Après une compilation réussie : [Movix-unsigned.ipa](https://github.com/sshpro111/movix-ios/releases/latest/download/Movix-unsigned.ipa). Les [Releases](https://github.com/sshpro111/movix-ios/releases) contiennent aussi la somme SHA-256 et les informations de compilation.

Le fichier IPA est un paquet d’application iPhone contenant `Payload/Movix.app`, avec un exécutable Mach-O arm64 pour iPhoneOS. Il est **non signé** et nécessite une signature pour être installé. Le téléchargement du code source proposé séparément par GitHub n’est pas un IPA.

## Compilation automatisée

Le workflow [Build Movix iPhone IPA](https://github.com/sshpro111/movix-ios/actions/workflows/build-ipa.yml) s’exécute sur le runner macOS 15 de GitHub, avec Xcode installé. Il compile la configuration Release pour `generic/platform=iOS`, SDK `iphoneos`, architecture arm64 et signature désactivée. Il vérifie ensuite le type de binaire, la version minimale d’iOS, les protections réseau et la structure du paquet.

Chaque compilation réussie publie un IPA dans une Release et le conserve aussi comme artifact GitHub Actions. Les journaux Xcode et le résultat `.xcresult` sont conservés séparément. Aucun identifiant Apple ni secret de signature n’est requis pour cette compilation. Les contrôles de compilation ne constituent pas un test sur iPhone physique.

Le workflow se lance automatiquement après un envoi sur `main`. Il peut aussi être relancé depuis l’onglet Actions avec **Run workflow**.

## Installation depuis Windows

1. Téléchargez l’IPA puis [Sideloadly pour Windows](https://sideloadly.io/) depuis son site officiel. Sideloadly demande les versions web d’iTunes et d’iCloud pour Windows ; son site fournit les liens.
2. Connectez l’iPhone par USB, déverrouillez-le et acceptez **Faire confiance à cet ordinateur**.
3. Ouvrez Sideloadly, sélectionnez l’iPhone, glissez `Movix-unsigned.ipa`, renseignez votre identifiant Apple et lancez **Start**. Sideloadly signe l’application pour votre appareil.
4. Suivez, si nécessaire, les instructions de confiance du profil et de mode développeur affichées par iOS/Sideloadly. Lancez Movix.

Avec un compte Apple gratuit, la signature est valable 7 jours ; Sideloadly propose un renouvellement automatique. La compilation GitHub ne requiert pas de compte Apple ; la signature Sideloadly en requiert un. [Instructions et conditions officielles Sideloadly](https://sideloadly.io/).

## Compilation locale sur un Mac

```bash
xcodebuild -project Movix.xcodeproj -scheme Movix -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath build/DerivedData ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' build
bash scripts/package-ipa.sh
```

Le résultat est `dist/Movix-unsigned.ipa`. Ce dépôt n’a aucune dépendance tierce à installer.
