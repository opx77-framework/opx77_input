# opx77_input — architecture

opx77_input est le service de formulaires d'OPX//77 : une seule surface WebUI, possédée par
cette resource, sur laquelle n'importe quelle autre resource pose une question au joueur (champs
texte, listes de choix, curseurs) et reçoit une seule réponse par event local. Elle valide la
spec, tient le formulaire ouvert, prend le clavier exactement le temps qu'il est ouvert, décide
de chaque touche et de chaque saisie, et annule le formulaire quand son propriétaire s'arrête.
Elle ne dessine pas de liste (c'est `opx77_menu`), ne traduit pas le texte de l'appelant, et n'a
pas de moitié serveur. Le mode d'emploi est dans le README ; ce document dit pourquoi le code est
écrit ainsi.

Le code est commenté en anglais par blocs d'annotation ; cette documentation est en français.

## Manifeste

L'ordre de chargement est l'ordre du manifeste, et il porte :

1. `config.lua` publie `OPX_INPUT_CONFIG` (côté client seulement) ;
2. `shared/text.lua` crée `OpxInput.Text`, que le modèle lit au chargement ;
3. `shared/locale.lua` vient **après** `config.lua`, parce que la langue est appliquée au
   chargement (`Locale.Set(OPX_INPUT_CONFIG and OPX_INPUT_CONFIG.LOCALE)`) : lue plus tard,
   `LOCALE` serait inerte. Le garde `and` est nécessaire parce que ce fichier est aussi chargé
   par la VM serveur, où `config.lua` n'existe pas ;
4. `locales/en.lua` et `locales/fr.lua` s'enregistrent juste après le module de locale, pour
   qu'aucun fichier plus bas n'appelle `locale()` contre un catalogue vide ;
5. `client/model.lua` avant `client/input.lua`, puis `client/main.lua` qui lit les deux au
   chargement, et `client/exports.lua` en dernier parce qu'il lit `OpxInput.Runtime` et
   `OpxInput.Model`.

- `reload_policy "reconnect"` : remplacer à chaud une surface CEF vivante en pleine session est
  instable ; un changement de génération reconnecte donc le client.
- `web_ui_auto_create false` : c'est `client/main.lua` qui crée la page, pour qu'un échec soit
  une ligne de log et un refus `no_surface`, pas une resource muette.
- `input.actions` — `Open77.input.isCaptured` : le formulaire refuse de s'ouvrir quand une autre
  surface tient déjà le clavier, puisqu'il s'apprête à le prendre.

La resource ne déclare pas de `dependency` et n'en a pas besoin : rien ne doit tourner pour
qu'elle démarre. La directive `version` n'est recopiée dans aucun fichier Lua : un code qui en
aurait besoin la lirait avec `Open77.resource.version()`.

## Contrats

La liste des exports, des champs d'une spec, des bornes et des raisons d'annulation est dans le
README ; elle n'est pas recopiée ici.

- **Toute export** répond une table `{ ok = boolean, ... }` construite par `response`
  (`client/exports.lua`), avec `error` quand `ok` est faux, et ne lève jamais. `error` est un code
  stable, jamais un texte montré au joueur.
- **Les exports sont client uniquement** : une resource serveur les appelle depuis sa moitié
  client.
- **Une seule réponse par formulaire**, levée sur le `event` de la spec s'il y en a un, et sur
  `opx77:input` à côté, pour qu'un seul listener puisse observer tous les formulaires. Quand le
  `event` de la spec est lui-même `opx77:input`, il n'est levé qu'une fois.
- **`state`** ne rend que `open` et `mine` à qui ne possède pas le formulaire, et ne rend jamais
  ce que le joueur a tapé : la réponse, c'est l'event, et il n'y a pas de seconde façon de la
  lire.
- **Un appelant peut remplacer son propre formulaire**, jamais celui d'un autre (`input_busy`).
  Le remplacé répond quand même, annulé avec `reason = "reopened"`.

### L'appelant est désigné par l'hôte

Une export ne prend jamais le propriétaire en argument : `caller()` le lit dans
`GetInvokingResource()` et `GetInvokingResourceGeneration()`, qu'un appelant ne peut pas
falsifier. Sans resource appelante, la réponse est `export_call_required`. `noteOwner`
(`client/main.lua`) retient la dernière génération vue par appelant : une génération qui a changé
veut dire que le code qui a ouvert le formulaire n'existe plus, et le formulaire est annulé
(`owner_reloaded`).

## Valider une spec

`OpxInput.Model.Build` construit le formulaire **en entier ou pas du tout** : chaque borne est un
refus avec un code, rien n'est coupé en silence, et rien de ce que l'appelant envoie ne revient
plus court. Le nom de l'appelant et le type de la spec sont vérifiés une seule fois, par l'export
`open`, avant d'arriver ici.

- **Le genre d'un champ vient de sa forme**, jamais d'une déclaration : `options` fait un choix,
  `slider` un curseur, le reste un champ texte.
- **Huit champs au plus** (`MAX_FIELDS`) : au-delà, ce n'est plus une question mais une liste, et
  une liste, c'est ce que dessine `opx77_menu`.
- **Longueur d'un champ texte** : 96 caractères par défaut, 512 au plus. La réponse entière
  voyage dans un seul payload d'event, donc le plafond est une borne de payload, pas un goût.
- **Les jeux de caractères sont une table fixe** (`CHARSETS`). Un appelant ne peut pas passer sa
  propre classe : une classe mal formée lève dans `string.match`, et une classe lente tournerait
  à chaque frappe.
- **`pattern` est compilé en l'essayant** (`pcall(string.match, '', pattern)`) : un motif mal
  formé lève au lieu de répondre nil, et il est refusé à `open`. Sa longueur est bornée (64).
- **Une valeur initiale que son propre champ refuserait** (longueur, charset, pattern) est un bug
  de l'appelant, pas du joueur : `invalid_value`.
- **Deux champs de même id** sont refusés (`duplicate_field_id`) : la réponse est indexée par id,
  l'un des deux perdrait sa réponse. Un champ sans id reçoit `field_<n>`.
- **Une option en chaîne nue** est le cas courant : le label est la valeur. La valeur d'une
  option est gardée exactement telle que l'appelant l'a écrite : c'est sa propre donnée qui
  revient, pas un texte que le joueur lit.
- **`data`** est comptée par `fitsInPayload` (64 nœuds, clés comprises, sur 4 niveaux), qui
  refuse plutôt que de tronquer.
- **Le texte affiché** (titre, labels, descriptions, placeholder, suffixe, statut) passe par
  `displayText` : caractères de contrôle remplacés par des espaces, et refusé plutôt que coupé
  au-delà de la borne. `OpxInput.Model.StatusText` refuse une table au lieu de la nettoyer en
  nil, ce qui effacerait la ligne en silence.
- **Un curseur** remplit ses défauts (0, 100, pas de 1, valeur = min) et ramène la valeur de
  départ dans l'intervalle ; `max <= min` est refusé.
- **Le premier champ focalisé** (`cursor`) est un id ou un index ; une valeur introuvable retombe
  sur le premier champ.

`OpxInput.Model.ValidName` est le même validateur que celui des ids, partagé avec
`client/exports.lua` pour le nom de la resource appelante.

## Mesurer le texte

Les motifs Lua travaillent en octets et les bornes sont en caractères : `shared/text.lua` dit
toujours dans quelle unité il compte. `OpxInput.Text.Span` rend la longueur en octets des
`maximum` premiers caractères ; un octet `0x80..0xBF` est un octet de continuation UTF-8 et ne
commence aucun caractère. Le parcours est aussi borné à `maximum * 4` octets (le plus large
qu'un caractère puisse être), pour qu'une suite d'octets de continuation ne le rende pas
illimité. Partout, `#value <= maximum` court-circuite la mesure : moins d'octets que de
caractères permis n'a pas besoin d'être compté.

La page compte de son côté en unités UTF-16 : `web/input.js` retire la moitié basse de chaque
paire de substitution, pour qu'un caractère compte pareil des deux côtés.

## Lua décide, la page rapporte

La page est un rendu piloté entièrement par Lua. Elle rapporte des touches (`input:key`) et des
tampons candidats (`input:edit`), elle ne décide de rien.

- `OpxInput.Input.Action` ne connaît que six noms de touche ; un autre nom est ignoré.
- `onKey` (`client/main.lua`) prend chaque décision : Échap annule, Entrée soumet, haut et bas
  changent de champ, gauche et droite changent un choix ou un curseur. Sur un refus à la
  soumission, le focus est d'abord mis sur le champ qui refuse, puis la ligne de statut dit
  pourquoi.
- `onEdit` ignore une saisie venue d'un champ qui n'a plus le focus : elle est périmée.
- `OpxInput.Model.Edit` : la longueur et le charset refusent **à la frappe**. Le tampon accepté
  ne bouge pas et la page est redessinée depuis lui, donc la frappe refusée disparaît. Le tampon
  est redessiné même quand il n'a pas bougé mais que la page montrait des frappes brutes portant
  un caractère de contrôle. `required` et `pattern` sont vérifiés à Entrée
  (`OpxInput.Model.Check`) ; un champ vide passe `pattern`, parce que le vide est ce à quoi
  répond `required`.
- `OpxInput.Model.Adjust` : un choix boucle ; un curseur est **borné, pas bouclé** (un volume
  qui saute de 0 à 100 est une plainte), puis recalé sur sa grille de pas, parce que 0.1 ajouté
  dix fois ne fait pas 1.0.
- `OpxInput.Model.Value` écrit une valeur entière sans décimale : « VOLUME 70.0% » se lit comme
  un bug. La réponse, elle, reste un flottant.
- `OpxInput.Model.View` : un drapeau absent vaut `nil`, pas `false`, pour ne pas coûter de nœud
  dans le payload ; seul le drapeau d'échec du statut traverse (`statusBad`), parce que
  `a and a.ok or nil` écraserait un `false`.

## Le clavier

`client/input.lua` tient le clavier : `held` dit si cette resource le tient, pour que le rendre
ne soit jamais une supposition.

- `OpxInput.Input.Attach` résout `Open77.input.isCaptured` une fois, au démarrage.
  `isCaptured` répond `false, "permission_denied:..."` plutôt que de lever ; il est quand même
  sondé sous `pcall`, parce qu'une levée ici abandonnerait le démarrage avant la création de la
  surface. Un lecteur absent ou refusé est journalisé, et un formulaire s'ouvrira alors par-dessus
  ce qui tient déjà le clavier.
- `OpxInput.Runtime.Open` demande `OpxInput.Input.Captured` **avant** de construire le
  formulaire : cette surface va prendre le clavier, et le prendre au composeur du chat taperait
  la ligne du joueur dans le vide (`keyboard_busy`). Tant que cette resource tient le clavier,
  la réponse est faux : la surface qui demande est celle qui l'a pris.
- `OpxInput.Input.Grab` appelle `page:setFocus(true, false)` : le clavier, pas la souris. Seul un
  `false` explicite est un refus (`no_keyboard`) ; un hôte qui ne répond rien a quand même donné
  le focus, et la réponse non `true` est journalisée.
- `OpxInput.Input.Release` est sans risque là où le clavier n'a jamais été pris, et il est appelé
  sans condition à l'arrêt : un clavier laissé capturé après un arrêt laisse le joueur incapable
  de bouger.

## Répondre une seule fois

`finish` (`client/main.lua`) répond au formulaire ouvert :

1. `record` est remis à nil **avant** l'envoi : un handler tourne en ligne et peut rappeler une
   export de ce fichier, et un formulaire ne répond qu'une fois ;
2. le clavier est rendu avant tout le reste, puis la page est cachée ;
3. l'event de la spec, puis `opx77:input`.

La touche pause de la plateforme (`open77:pauseKey`) est le filet de secours : le plugin avale
Échap et lève cet event à la place, même quand la page ne voit jamais la frappe, ce qui empêche
une page cassée d'enfermer le joueur. La page rapporte la même touche ; les deux passent par
`finish`, et la seconde ne trouve plus rien à faire.

## L'horloge et la boucle

`nowMs` lit `Open77.time.monotonic`, qui répond en **secondes**, et convertit en millisecondes.
Une lecture non finie est écartée et la dernière valeur finie est gardée : un NaN n'expirerait
rien, un infini expirerait tout.

Le thread lancé par `onClientResourceStart` passe toutes les 250 ms (`IDLE_MS`) tant que la page
existe. Avec un formulaire ouvert, chaque passe (`frameTick`) lit l'horloge une fois — c'est un
appel hôte — puis :

- `expireStatus` efface la ligne de statut après six secondes (`STATUS_MS`) ;
- `sweep` revérifie le propriétaire au plus une fois par seconde (`OWNER_SWEEP_MS`) : une
  resource qui n'est plus `running`, ou dont la génération a changé, voit son formulaire annulé
  (`owner_stopped`).

Chaque appel d'une passe est un appel hôte : `guarded` l'exécute sous `pcall`, parce qu'une
levée terminerait sinon la boucle pour toute la session, et ne journalise que le premier échec
d'une série.

## La surface WebUI

`onClientResourceStart` crée la page avec :

- `layer = 'hud'`, comme la boîte d'`opx77_chat` : la surface prend le focus explicitement, et
  seulement pendant qu'un formulaire est ouvert ;
- `fps = 60`, pas les 30 du menu : cette surface porte un curseur de saisie et le joueur tape ;
- `zIndex = 728` : au-dessus d'`opx77_menu` (725), sous la bande d'`open77_admin` (730) ;
- `visible = true` dès la création : une surface créée cachée ne téléverse jamais d'image une
  fois montrée.

`surfaceFailed` est remis à faux à chaque démarrage, pour qu'un rechargement après un échec
puisse réussir ; tant qu'il est vrai, toutes les exports sauf `state` répondent `no_surface`.

`send` ne parle à la page qu'une fois `input:ready` reçu, et sous `pcall` : `page:send` lève, et
les exports comme les handlers de la page l'atteignent. Une surface morte n'est journalisée
qu'une fois (`sendFailing`), pas à chaque frame. La mise en page (`input:config`) n'est envoyée
qu'à `input:ready` : rien de la configuration ne change pendant que la resource tourne.
`input:diag` rapporte les erreurs de la page dans le log client, puisque la console CEF n'y
arrive pas.

À l'arrêt de cette resource, le formulaire ouvert répond (`input_stopped`) tant qu'il reste un
état Lua pour le faire, puis le clavier est rendu.

## Couleurs

La page est dessinée comme la bande d'`opx77_menu` : chaque règle de `web/input.css` qui a une
jumelle dans `web/menu.css` porte les mêmes valeurs, et les deux se changent ensemble. Aucune
couleur littérale n'est écrite hors du bloc `:root` en tête de `web/input.css` : l'ombre des
plaques et les lignes de balayage lisent `--input-shade-rgb`, et le soulignement, le placeholder
et la piste du curseur du champ focalisé lisent `--input-ink-rgb` (les canaux de `--op77-ink`),
chacun avec sa propre opacité. `web/open77-ui.css` est le fichier de jetons de la plateforme,
recopié à l'identique dans chaque resource et jamais modifié.

## Locales

`shared/locale.lua` publie `OpxInput.Locale` et le raccourci global `locale`. Les lignes de log
et la sortie console restent en anglais quelle que soit la langue. `OpxInput.Locale.Set` accepte
un code inconnu, qui retombe sur `en` : les catalogues s'enregistrent après ce fichier.
`OpxInput.Locale.Get` ne rend jamais nil : une traduction manquante retombe sur `en`, puis sur la
clé elle-même, et un placeholder sans valeur reste écrit tel quel.

Le texte de l'appelant est rendu tel qu'il l'a écrit ; seules les lignes que cette resource
possède (la ligne de touches, les quatre refus) sont traduites.

## Invariants

- **Une surface WebUI par resource**, créée par son propre code (`web_ui_auto_create false`),
  canaux nommés `input:<action>`.
- **L'identité de l'appelant vient de l'hôte**, jamais d'un argument (voir Contrats).
- **Une fonction qui cède la main doit pouvoir renoncer** : il n'y a qu'un formulaire à la fois,
  et chaque réponse vérifie `record` avant d'agir ; une génération d'appelant qui a changé
  annule son formulaire.
- **Une resource qui tient un état le relâche à son arrêt** : l'arrêt répond au formulaire et
  rend le clavier ; `reload_policy "reconnect"` couvre le rechargement.
- **Une resource ne touche pas aux internes d'une autre** : les autres resources n'atteignent
  opx77_input que par ses exports et par les events de réponse.

## Limites connues

- Un `open` avec `status` envoie deux fois la même frame : `OpxInput.Runtime.SetStatus` dessine,
  puis `OpxInput.Runtime.Open` dessine encore.
- `pattern` est documenté comme devant correspondre à la réponse **entière**, mais
  `matchesPattern` appelle `string.match` sans ancre : un motif non ancré (`%d+`) accepte
  `a1b`. Tous les appelants actuels ancrent leurs motifs.
- `guarded` n'a qu'un appelant, la boucle du formulaire.
- La VM serveur charge `shared/text.lua`, `shared/locale.lua` et les deux catalogues sans
  qu'aucun script serveur ne les lise.
