# To Do List MVP

Application mobile minimaliste de to-do list construite avec Expo, React Native et TypeScript.

## Choix techniques

- `Expo` : permet de lancer très vite l'application sur iPhone avec Expo Go ou un build Expo.
- `TypeScript` : apporte un typage strict et un code plus maintenable.
- `@react-native-async-storage/async-storage` : assure la persistance locale simple des tâches sans backend.

## Fonctionnalités

- Ajouter une tâche
- Marquer une tâche comme terminée ou non terminée
- Supprimer une tâche
- Persistance automatique en local
- Rechargement automatique au démarrage
- Tri des tâches : non terminées d'abord, terminées ensuite

## Installation

```bash
npm install
npx expo install @react-native-async-storage/async-storage
```

## Lancement

```bash
npx expo start
```

## Test rapide sur iPhone

1. Installer l'application Expo Go sur l'iPhone.
2. Connecter l'iPhone et l'ordinateur au même réseau Wi-Fi.
3. Lancer `npx expo start`.
4. Scanner le QR code affiché dans le terminal ou dans l'interface Expo.

## Structure

```text
.
├── App.tsx
├── README.md
├── app.json
├── package.json
├── tsconfig.json
└── src
    ├── components
    │   └── TaskItem.tsx
    ├── types
    │   └── task.ts
    └── utils
        └── storage.ts
```
# expo-apple-fundation-test
