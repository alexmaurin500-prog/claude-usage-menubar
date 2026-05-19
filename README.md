# claude-usage-menubar

Petits utilitaires macOS pour afficher ton usage Claude (fenêtre 5 heures, 7 jours, et crédits extra) directement dans la barre de menus.

Deux variantes :

- `claude-usage.5m.py` — **plugin SwiftBar** (rafraîchi toutes les 5 min).
- `claude-menubar.py` — **app menubar autonome** basée sur `rumps`, sans dépendance à SwiftBar.

## Comment ça marche

Les scripts ne s'authentifient **pas** avec une clé API Anthropic. À la place, ils lisent les cookies de session de **Safari** pour `claude.ai` via [`browser-cookie3`](https://pypi.org/project/browser-cookie3/), puis appellent l'endpoint interne `https://claude.ai/api/organizations/{org_id}/usage` en se faisant passer pour le client web.

> ⚠️ **Non officiel.** Cet endpoint n'est pas une API publique d'Anthropic. Il peut changer ou disparaître à tout moment, et ce projet n'est pas affilié à Anthropic. Utilisation à vos risques.

## Prérequis

- macOS
- Python 3.9+
- Une session active sur [claude.ai](https://claude.ai) dans **Safari**
- **Accès complet au disque** accordé à SwiftBar (variante 1) ou au terminal/app qui lance le script (variante 2), dans *Réglages Système → Confidentialité et sécurité → Accès complet au disque*

## Installation

```bash
pip3 install -r requirements.txt
```

### Variante 1 : plugin SwiftBar

1. Installer [SwiftBar](https://github.com/swiftbar/SwiftBar).
2. Copier `claude-usage.5m.py` dans le dossier de plugins SwiftBar.
3. Le rendre exécutable :
   ```bash
   chmod +x claude-usage.5m.py
   ```
4. Rafraîchir SwiftBar.

### Variante 2 : app autonome

```bash
python3 claude-menubar.py
```

Pour la lancer automatiquement au démarrage, tu peux la packager avec [`py2app`](https://py2app.readthedocs.io/) puis l'ajouter aux éléments d'ouverture macOS.

## Licence

MIT — voir [LICENSE](LICENSE).
