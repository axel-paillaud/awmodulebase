#!/bin/bash

# Rename a module created from the awmodulebase template.
#
# NOTE: You have to be in the bin directory to run this script
# cd <presta-root>/modules/<module-name>/bin
#
# What it does:
#   1. Detects the current technical name (main PHP file) and class name (class X extends Module)
#   2. Prompts for the new technical name and class name
#   3. Replaces every occurrence in the files of the module (4 variants):
#        awmodulebase   -> awnewmodule     (technical name, routes, services, paths)
#        AwModuleBase   -> AwNewModule     (class, namespace, autoloader suffix)
#        Awmodulebase   -> Awnewmodule     (translation domain Modules.Awnewmodule.Admin)
#        AWMODULEBASE   -> AWNEWMODULE     (configuration keys)
#   4. Renames the files and directories whose name contains the old name
#   5. Optionally renames the module directory itself
#
# Excluded from the search: .git, vendor, node_modules and this script.

set -euo pipefail

MODULE_DIR="$(dirname "$PWD")"
MODULE_NAME="$(basename "$MODULE_DIR")"
SCRIPT_PATH="$PWD/$(basename "$0")"

# Check bash shell
if [ -z "${BASH_VERSION:-}" ]; then
  echo -e "\033[31m\033[1m\n✖ ERREUR : Ce script doit être exécuté avec bash.\033[0m" >&2
  echo -e "\033[31mUtilisez : bash rename-module.sh ou ./rename-module.sh\033[0m" >&2
  exit 1
fi

# --- Console color ---
if command -v tput >/dev/null 2>&1; then
  RED="$(tput setaf 1)"
  GREEN="$(tput setaf 2)"
  YELLOW="$(tput setaf 3)"
  BOLD="$(tput bold)"
  RESET="$(tput sgr0)"
else
  RED=$'\033[31m'
  GREEN=$'\033[32m'
  YELLOW=$'\033[33m'
  BOLD=$'\033[1m'
  RESET=$'\033[0m'
fi

die() {
  echo -e "${RED}${BOLD}\n✖ ERREUR : $1${RESET}" >&2
  exit 1
}

# Portable in-place sed (GNU and BSD/macOS)
sed_inplace() {
  if sed --version >/dev/null 2>&1; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}

# --- Detect current names ---
MAIN_FILE="$MODULE_DIR/$MODULE_NAME.php"
[ -f "$MAIN_FILE" ] || die "Fichier principal introuvable : $MAIN_FILE\nLe dossier du module doit porter le nom technique du module."

OLD_NAME="$MODULE_NAME"
OLD_CLASS="$(grep -oE "^class[[:space:]]+[A-Za-z0-9_]+[[:space:]]+extends[[:space:]]+Module" "$MAIN_FILE" | head -n 1 | awk '{print $2}')"
[ -n "$OLD_CLASS" ] || die "Impossible de détecter la classe principale dans $MAIN_FILE (attendu : class X extends Module)."

OLD_UCFIRST="$(tr '[:lower:]' '[:upper:]' <<< "${OLD_NAME:0:1}")${OLD_NAME:1}"
OLD_UPPER="$(tr '[:lower:]' '[:upper:]' <<< "$OLD_NAME")"

echo -e "${BOLD}Module actuel${RESET}"
echo "  Nom technique : $OLD_NAME"
echo "  Classe        : $OLD_CLASS"
echo "  Domaine trad  : Modules.$OLD_UCFIRST.Admin"
echo "  Clés config   : ${OLD_UPPER}_*"
echo

# --- Prompt new names ---
read -r -p "Nouveau nom technique (minuscules, ex. awcustomerapproval) : " NEW_NAME
[[ "$NEW_NAME" =~ ^[a-z][a-z0-9_]*$ ]] || die "Nom technique invalide : '$NEW_NAME'. Attendu : minuscules, chiffres et _ (ex. awcustomerapproval)."
[ "$NEW_NAME" != "$OLD_NAME" ] || die "Le nouveau nom est identique à l'ancien."

DEFAULT_CLASS="$(tr '[:lower:]' '[:upper:]' <<< "${NEW_NAME:0:1}")${NEW_NAME:1}"
read -r -p "Nouvelle classe principale (CamelCase, ex. AwCustomerApproval) [$DEFAULT_CLASS] : " NEW_CLASS
NEW_CLASS="${NEW_CLASS:-$DEFAULT_CLASS}"
[[ "$NEW_CLASS" =~ ^[A-Z][A-Za-z0-9]*$ ]] || die "Nom de classe invalide : '$NEW_CLASS'. Attendu : CamelCase commençant par une majuscule."

if [ "$(tr '[:upper:]' '[:lower:]' <<< "$NEW_CLASS")" != "$(tr -d '_' <<< "$NEW_NAME")" ]; then
  echo -e "${YELLOW}⚠ La classe '$NEW_CLASS' ne correspond pas au nom technique '$NEW_NAME' une fois en minuscules.${RESET}"
  read -r -p "Continuer quand même ? [o/N] " CONFIRM
  [[ "$CONFIRM" =~ ^[oOyY]$ ]] || { echo "Abandon."; exit 1; }
fi

NEW_UCFIRST="$(tr '[:lower:]' '[:upper:]' <<< "${NEW_NAME:0:1}")${NEW_NAME:1}"
NEW_UPPER="$(tr '[:lower:]' '[:upper:]' <<< "$NEW_NAME")"

echo
echo -e "${BOLD}Remplacements${RESET}"
echo "  $OLD_NAME  ->  $NEW_NAME"
echo "  $OLD_CLASS  ->  $NEW_CLASS"
echo "  $OLD_UCFIRST  ->  $NEW_UCFIRST"
echo "  $OLD_UPPER  ->  $NEW_UPPER"
echo
read -r -p "Appliquer ? [o/N] " CONFIRM
[[ "$CONFIRM" =~ ^[oOyY]$ ]] || { echo "Abandon."; exit 1; }

# --- Files to process (text files only, excluding vendor/.git/node_modules and this script) ---
mapfile -t FILES < <(
  find "$MODULE_DIR" -type f \
    -not -path '*/.git/*' \
    -not -path '*/vendor/*' \
    -not -path '*/node_modules/*' \
    -not -path "$SCRIPT_PATH" \
    -exec grep -IlE "$OLD_NAME|$OLD_CLASS|$OLD_UCFIRST|$OLD_UPPER" {} +
)

echo
echo "📝 Remplacement dans ${#FILES[@]} fichier(s)..."
for f in "${FILES[@]}"; do
  # Order matters: longest/most specific patterns first (class before ucfirst before lower)
  sed_inplace \
    -e "s/$OLD_UPPER/$NEW_UPPER/g" \
    -e "s/$OLD_CLASS/$NEW_CLASS/g" \
    -e "s/$OLD_UCFIRST/$NEW_UCFIRST/g" \
    -e "s/$OLD_NAME/$NEW_NAME/g" \
    "$f"
  echo "   ${f#"$MODULE_DIR/"}"
done

# --- Rename files and directories inside the module (deepest first) ---
# The module directory itself is excluded here (-mindepth 1): it is handled
# separately below, with a confirmation.
echo
echo "📁 Renommage des fichiers et dossiers..."
while IFS= read -r path; do
  base="$(basename "$path")"
  dir="$(dirname "$path")"
  newbase="${base//$OLD_CLASS/$NEW_CLASS}"
  newbase="${newbase//$OLD_UCFIRST/$NEW_UCFIRST}"
  newbase="${newbase//$OLD_NAME/$NEW_NAME}"
  if [ "$base" != "$newbase" ]; then
    mv "$path" "$dir/$newbase"
    echo "   ${path#"$MODULE_DIR/"}  ->  $newbase"
  fi
done < <(
  find "$MODULE_DIR" -mindepth 1 -depth \
    -not -path '*/.git/*' \
    -not -path '*/vendor/*' \
    -not -path '*/node_modules/*' \
    \( -name "*$OLD_NAME*" -o -name "*$OLD_CLASS*" -o -name "*$OLD_UCFIRST*" \)
)

# --- Sanity check ---
echo
REMAINING="$(grep -rIlE "$OLD_NAME|$OLD_CLASS|$OLD_UCFIRST|$OLD_UPPER" "$MODULE_DIR" \
  --exclude-dir=.git --exclude-dir=vendor --exclude-dir=node_modules \
  --exclude="$(basename "$SCRIPT_PATH")" || true)"
if [ -n "$REMAINING" ]; then
  echo -e "${YELLOW}⚠ Occurrences restantes (à vérifier manuellement) :${RESET}"
  echo "$REMAINING"
else
  echo -e "${GREEN}✔ Plus aucune occurrence de l'ancien nom.${RESET}"
fi

# --- Rename the module directory itself ---
PARENT_DIR="$(dirname "$MODULE_DIR")"
NEW_MODULE_DIR="$PARENT_DIR/$NEW_NAME"
echo
read -r -p "Renommer le dossier du module en $NEW_MODULE_DIR ? [o/N] " CONFIRM
if [[ "$CONFIRM" =~ ^[oOyY]$ ]]; then
  [ ! -e "$NEW_MODULE_DIR" ] || die "Le dossier $NEW_MODULE_DIR existe déjà."
  cd "$PARENT_DIR"
  mv "$MODULE_DIR" "$NEW_MODULE_DIR"
  MODULE_DIR="$NEW_MODULE_DIR"
  echo -e "${GREEN}✔ Dossier renommé.${RESET}"
fi

echo
echo -e "${GREEN}${BOLD}✅ Renommage terminé.${RESET}"
echo
echo "Étapes suivantes :"
echo "  1. cd $MODULE_DIR && composer dump-autoload   (le suffixe d'autoloader a changé)"
echo "  2. Vérifier le remote git (.git/config) s'il pointe encore sur le template"
echo "  3. Adapter les libellés (displayName, description, onglet) dans $NEW_NAME.php"
