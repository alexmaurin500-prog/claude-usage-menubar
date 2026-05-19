# claude-usage-menubar

Utilitaires pour afficher ton usage Claude (fenêtre 5 heures, 7 jours, et crédits extra) directement dans la barre de menus / system tray.

Trois variantes :

- `claude-usage.5m.py` — **plugin SwiftBar** (macOS, rafraîchi toutes les 5 min).
- `claude-menubar.py` — **app menubar autonome** basée sur `rumps` (macOS, sans dépendance à SwiftBar).
- `claude-tray.py` — **app system tray cross-platform** basée sur `pystray` (macOS / Windows / Linux).

## Comment ça marche

Les scripts ne s'authentifient **pas** avec une clé API Anthropic. À la place, ils lisent les cookies de session pour `claude.ai` via [`browser-cookie3`](https://pypi.org/project/browser-cookie3/), puis appellent l'endpoint interne `https://claude.ai/api/organizations/{org_id}/usage` en se faisant passer pour le client web.

Les navigateurs suivants sont détectés automatiquement (dans cet ordre) : **Safari**, **Chrome**, **Firefox** (+ **Edge** sur Windows). Le premier navigateur connecté à claude.ai est utilisé.

> ⚠️ **Non officiel.** Cet endpoint n'est pas une API publique d'Anthropic. Il peut changer ou disparaître à tout moment, et ce projet n'est pas affilié à Anthropic. Utilisation à vos risques.

## Prérequis

- **macOS**, **Windows** ou **Linux**
- Python 3.9+
- Une session active sur [claude.ai](https://claude.ai) dans **Safari**, **Chrome**, **Firefox** ou **Edge**
- macOS : **Accès complet au disque** accordé à SwiftBar ou au terminal/app qui lance le script (*Réglages Système → Confidentialité et sécurité → Accès complet au disque*)

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

### Variante 2 : app menubar autonome (macOS)

```bash
python3 claude-menubar.py
```

Pour la lancer automatiquement au démarrage, tu peux la packager avec [`py2app`](https://py2app.readthedocs.io/) puis l'ajouter aux éléments d'ouverture macOS.

### Variante 3 : app system tray cross-platform (macOS / Windows / Linux)

```bash
python3 claude-tray.py
```

Affiche une icône dans le system tray avec le pourcentage d'usage et un code couleur (vert/orange/rouge). Clic droit pour voir le détail, rafraîchir, ou ouvrir la page d'usage.

## Licence

MIT — voir [LICENSE](LICENSE).
