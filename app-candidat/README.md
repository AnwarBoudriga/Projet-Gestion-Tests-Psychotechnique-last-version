# PsyTech Pro - Espace Candidat (Flutter)

Application séparée pour les candidats (clé `PSY-XXXXXXXX`), connectée au backend (`/api/candidat/*`).

## Lancer (port 5003)
```
flutter create . --platforms=web      # une seule fois, génère les fichiers manquants (sans écraser lib/)
flutter pub get
flutter run -d chrome --web-port=5003 --dart-define=API_URL=http://localhost:3000
```
Backend `.env` :
```
CORS_ORIGIN=http://localhost:5001,http://localhost:5002,http://localhost:5003
CANDIDAT_URL=http://localhost:5003
```
Parcours : connexion -> présentation -> test (une question à la fois, réponses enregistrées sur le serveur, chrono serveur) -> soumission -> résultat.
Clé candidat : espace Entreprise -> Invitations (ou `npm run seed:demo:reset`). Le test doit être publié.
