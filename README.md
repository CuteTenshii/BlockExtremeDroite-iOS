# Block Extreme Droite (iOS)

Appli iOS qui bloque automatiquement les comptes listés sur [onbloquelextremedroite.fun](https://onbloquelextremedroite.fun/).

Sur le site, on bloque les profils un par un à la main. L'appli fait la même chose à votre place : elle ouvre chaque profil sur le site du réseau, ouvre son menu, appuie sur « Bloquer », puis confirme. C'est la version iOS de l'[appli Android](https://github.com/CuteTenshii/BlockExtremeDroiteAndroid).

iOS n'a pas de service d'accessibilité pour piloter les applis des autres. L'appli passe donc par un navigateur intégré, connecté à votre compte, et clique sur les pages web des réseaux.

## Fonctionnement

- **La liste** est celle du site : les comptes vérifiés par l'équipe et les propositions de la communauté. Elle est téléchargée au premier lancement, enregistrée sur l'iPhone, et mise à jour quand vous appuyez sur « Mettre à jour ».
- **Les réseaux** : X, Instagram, Facebook et TikTok. YouTube figure dans la liste mais n'est pas pris en charge (voir plus bas). Chaque réseau a sa propre progression. Un compte présent sur plusieurs réseaux est reconnu comme une seule personne, comme sur le site.
- **La connexion** se fait une fois dans l'appli, depuis l'onglet Blocage. L'appli ne lit ni ne garde aucun mot de passe : elle repère seulement que la session existe.
- **Avant de bloquer**, l'appli vérifie que le profil affiché est le bon (X, Instagram, TikTok). Un compte déjà bloqué, suspendu ou supprimé est passé sans rien toucher.
- **Le rythme** est réglable dans l'onglet Réglages : une pause entre deux blocages (de 0 à 60 s) et un maximum par session (de 5 à 200, ou sans limite). Bloquer trop vite peut faire limiter votre compte.
- **Le compteur** du site est mis à jour à chaque blocage, comme quand vous bloquez depuis le site. Chaque compte affiche aussi combien de personnes l'ont déjà bloqué.
- **La progression** est enregistrée : l'appli reprend là où elle s'est arrêtée et ne rouvre jamais un compte déjà traité.

L'interface est en français, avec l'anglais si l'iPhone est en anglais.

## Limites

- **L'appli doit rester ouverte, écran allumé** pendant le blocage : iOS suspend les pages web en arrière-plan.
- **Les pages web des réseaux changent.** Les flux X et Instagram ont été essayés ; Facebook et TikTok sont expérimentaux et peuvent demander des ajustements. Si les blocages échouent tous sur un réseau, ouvrez une issue en précisant le réseau et la langue de l'iPhone.
- **YouTube** n'est pas pris en charge : le site web n'a pas d'équivalent direct au « Masquer l'utilisateur sur ma chaîne » de l'appli.

## Données envoyées

L'appli contacte onbloquelextremedroite.fun :

- pour télécharger la liste et les compteurs ;
- pour déclarer chaque blocage au compteur collectif, avec le compte bloqué et un identifiant aléatoire propre à l'appli, comme le fait le site.

Les photos des comptes viennent du site ou des sites qui les hébergent, qui voient donc passer ces requêtes.

Les pages des réseaux sont chargées dans la vue web, avec votre session : les réseaux voient les blocages comme venant de vous.

## Compiler

Il vous faut Xcode 27 et un iPhone sous iOS 27 ou plus récent.

1. Ouvrez `Block Extreme Droite.xcodeproj` dans Xcode.
2. Choisissez votre équipe de développement dans *Signing & Capabilities* et, si besoin, changez l'identifiant du bundle.
3. Lancez sur un iPhone ou un simulateur.

## Licence

[MIT](LICENSE)
