#!/bin/bash

# Request the module name from the user
read -p "Enter the name of the module (example: Client): " MODULE_NAME

# Defining the base paths using the module name
MODULE_PATH="app/Modules/${MODULE_NAME}/"
CONFIG_PATH="config/"
VIEWS_PATH="resources/views/"
LANG_PATH="resources/lang/en/"
MIGRATIONS_PATH="database/migrations/"
CONTROLLERS_PATH="app/Http/Controllers/"

# Capitalize the first letter for file and folder names
MODULE_NAME_LOWER=$(echo "$MODULE_NAME" | awk '{print tolower($0)}')

# Create the necessary folder structures if they do not exist
mkdir -p "${VIEWS_PATH}${MODULE_NAME_LOWER}"

# Move and rename the views files 
echo "Migrating and renaming the view files..."
mv "${MODULE_PATH}Views/"* "${VIEWS_PATH}${MODULE_NAME_LOWER}/"

# Move and rename the translations files 
echo "Migrating and renaming the translations files..."
mv "${MODULE_PATH}Translations/en/lang.php" "${LANG_PATH}${MODULE_NAME_LOWER}.php"

# Move the migrations files
echo "Migrating and renaming the archivos de migración..."
mv "${MODULE_PATH}Database/Migrations/"* "${MIGRATIONS_PATH}"

# Move the models files
# echo "Migrating and renaming the models files..."
# mkdir -p app/Models/${MODULE_NAME}/
# mv app/Modules/${MODULE_NAME}/Models/* app/Models/${MODULE_NAME}/

# List of the controllers and prepare the names to update the routes
echo "List of the controllers..."
CONTROLLER_NAMES=$(find "${MODULE_PATH}Controllers/" -type f -name "*.php" -exec basename {} .php \;)

# Move controllers and update namespace
echo "Migrating and renaming the controllers..."
mkdir -p "${CONTROLLERS_PATH}${MODULE_NAME}"
for file in ${MODULE_PATH}Controllers/*; do
    CONTROLLER_NAME=$(basename "$file" .php)
    sed -i '' -e "s#namespace App\\\\Modules\\\\${MODULE_NAME}\\\\Controllers;#namespace App\\\\Http\\\\Controllers\\\\${MODULE_NAME};#g" "$file"
    mv "$file" "${CONTROLLERS_PATH}${MODULE_NAME}/${CONTROLLER_NAME}.php"
done

# Update controller paths in web.php for the Sales module
WEB_PATH="${MODULE_PATH}routes/web.php"
if [ -f "$WEB_PATH" ]; then
    echo "Updating controller paths in web.php..."
    for CONTROLLER_NAME in $CONTROLLER_NAMES; do
        # Add the use statement at the beginning of the file if not already present
        if ! grep -q "use App\\Http\\Controllers\\${MODULE_NAME}\\${CONTROLLER_NAME} as ${MODULE_NAME}${CONTROLLER_NAME};" "$WEB_PATH"; then
            sed -i '' "1i\\
use App\\\\Http\\\\Controllers\\\\${MODULE_NAME}\\\\${CONTROLLER_NAME} as ${MODULE_NAME}${CONTROLLER_NAME};\\
" "$WEB_PATH"
        fi
        ALIAS="${MODULE_NAME}${CONTROLLER_NAME}Controller"
        # Update controller paths in web.php for the Sales module
        sed -i '' -E "s|@([^']+)'|'\1']|g" "$WEB_PATH"
        sed -i '' -E "s|'App\\\\Modules\\\\${MODULE_NAME}\\\\Controllers\\\\${CONTROLLER_NAME}|[${MODULE_NAME}${CONTROLLER_NAME}::class, |g" "$WEB_PATH"
    done
fi

# Extract and merge menu configurations
MENU_FILE="${MODULE_PATH}config/menu.php"
MAIN_MENU_FILE="${CONFIG_PATH}menu.php"
echo "Fusionando configuraciones de menú..."
# Merging menu configurations
if [[ -f "$MENU_FILE" ]]; then
    # Extract content between brackets
    CONTENT=$(sed -n '/return \[/,/];/p' "$MENU_FILE" | sed '1d;$d')
    # Prepare content for insertion with backslashes
    CONTENT=$(echo "$CONTENT" | sed 's/$/\\/' | sed '$ s/\\//')
    # Prepare comment indicating the origin of the content
    COMMENT="// ${MODULE_NAME} module menu configuration"
    # Insert comment and content in the main menu file before the last bracket
    sed -i '' "/];/i \\
$COMMENT\\
$CONTENT\\
" "$MAIN_MENU_FILE"
fi

# Deleting the original menu.php file from the Modules/Config/menu.php folder
echo "Removing the original menu.php file from the module"
rm "${MENU_FILE}"

# Find and replace model paths in all PHP files
echo "Replacing model paths in PHP files..."
find . -type f -name "*.php" ! -path "./vendor/*" -exec sed -i '' -e "s#App\\Modules\\${MODULE_NAME}\\Models\\${MODULE_NAME}#App\\${MODULE_NAME}#g" {} +

# Updating the view path of the module

# Completion message
echo "Migration completed."
