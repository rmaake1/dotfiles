#!/usr/bin/env bash

# --- Wait for hyprpaper ---
echo "Waiting for hyprpaper to become responsive..."
while ! hyprctl hyprpaper listloaded > /dev/null 2>&1; do
  sleep 1 # Wait 1 second before trying again
done
echo "hyprpaper is responsive. Starting wallpaper loop."
# --------------------------

WALLPAPER_DIR="$HOME/Pictures/wallpaper/"
PREVIOUS_WALLPAPER="" # Variable to store the last used wallpaper path

# --- Check if wallpaper directory exists ---
if [[ ! -d "$WALLPAPER_DIR" ]]; then
  echo "$(date): Error: Wallpaper directory '$WALLPAPER_DIR' not found. Exiting." >&2
  exit 1
fi

# --- Count wallpapers once for edge case handling ---
WALLPAPER_COUNT=$(find "$WALLPAPER_DIR" -type f -print0 | grep -cz .) # Count null-terminated files
if [[ "$WALLPAPER_COUNT" -eq 0 ]]; then
    echo "$(date): Error: No wallpapers found in '$WALLPAPER_DIR'. Exiting." >&2
    exit 1
fi
echo "$(date): Found $WALLPAPER_COUNT wallpapers."

# --- Main Loop ---
while true; do
  NEW_WALLPAPER=""
  SELECTION_ATTEMPTS=0
  MAX_ATTEMPTS=10 # Safety break if it takes too long to find a different one

  # --- Inner loop to find a DIFFERENT wallpaper ---
  while [[ -z "$NEW_WALLPAPER" || "$NEW_WALLPAPER" == "$PREVIOUS_WALLPAPER" ]]; do
    # If only 1 wallpaper exists overall, no point trying to find a different one
    if [[ "$WALLPAPER_COUNT" -le 1 ]]; then
       if [[ "$SELECTION_ATTEMPTS" -eq 0 ]]; then # Only print warning once
           echo "$(date): Warning: Only one wallpaper available." >&2
       fi
       # Select the only one available
       read -r -d $'\0' NEW_WALLPAPER < <(find "$WALLPAPER_DIR" -type f -print0 | shuf -z -n 1)
       break # Exit inner loop, we have the only choice
    fi

    # Select a random wallpaper using null bytes
    read -r -d $'\0' NEW_WALLPAPER < <(find "$WALLPAPER_DIR" -type f -print0 | shuf -z -n 1)

    # Handle case where find returns nothing unexpectedly mid-script
    if [[ -z "$NEW_WALLPAPER" ]]; then
       echo "$(date): Error: Failed to find any wallpaper during selection." >&2
       NEW_WALLPAPER="" # Ensure we don't proceed
       break # Exit inner loop, outer loop will sleep and retry
    fi

    # Safety break for the inner loop if it takes too many tries
    ((SELECTION_ATTEMPTS++))
    if [[ "$SELECTION_ATTEMPTS" -gt "$MAX_ATTEMPTS" ]]; then
         echo "$(date): Warning: Could not select a different wallpaper after $MAX_ATTEMPTS attempts. Using the last selected one anyway: $NEW_WALLPAPER" >&2
         break # Exit inner loop, use whatever was picked last
    fi

    # Debug: uncomment to see selection process
    # echo "Attempt $SELECTION_ATTEMPTS: Picked '$NEW_WALLPAPER', Previous was '$PREVIOUS_WALLPAPER'"

  done # End of inner wallpaper selection loop

  # --- Proceed only if we successfully selected a wallpaper ---
  if [[ -n "$NEW_WALLPAPER" ]]; then
    WALLPAPER="$NEW_WALLPAPER" # Assign the chosen wallpaper

    # Check if the selected wallpaper is actually different, or if we fell through due to warnings
    if [[ "$WALLPAPER" != "$PREVIOUS_WALLPAPER" || -z "$PREVIOUS_WALLPAPER" ]]; then
        echo "$(date): Setting wallpaper to: $WALLPAPER"
    else
        echo "$(date): Re-setting wallpaper to the same file (due to issues finding a different one): $WALLPAPER"
    fi

    # Preload the new wallpaper (reduces flicker on change)
    hyprctl hyprpaper preload "$WALLPAPER"

    # Apply the selected wallpaper (ensure monitor ID is correct, e.g., ",$WALLPAPER" for default/first)
    # If you have multiple monitors use specific identifiers like "DP-1,$WALLPAPER"
    hyprctl hyprpaper wallpaper ",$WALLPAPER"

    # --- Moved this section ---
    # Unload previously loaded, now inactive wallpapers AFTER setting the new one
    hyprctl hyprpaper unload all
    # -------------------------

    # Update the previous wallpaper variable for the *next* iteration
    PREVIOUS_WALLPAPER="$WALLPAPER"
  else
     # This branch now likely only reachable if find failed during selection loop
     echo "$(date): Warning: Failed to select a wallpaper in this cycle."
  fi

  # Wait for 5 minutes (300 seconds)
  echo "$(date): Sleeping for 5 minutes..."
  sleep 300
done
