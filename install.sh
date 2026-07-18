#!/usr/bin/env bash

# ==============================================================================
# Niri Rice Installer
# Target Environment: Arch Linux (Niri + Noctalia Base Ecosystem)
# Reference URL: https://github.com/Jerbe-Dev/Niri
# ==============================================================================

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# --- Benchmarking ---
START_TIME=$(date +%s)
readonly START_TIME

# --- Global Constants ---
readonly VERSION="3.4.0"
readonly AUTHOR="Jerbe"
readonly LOG_DIR="$HOME/.cache/niri-rice"
readonly LOG_FILE="$LOG_DIR/install.log"
TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
readonly TIMESTAMP
readonly BACKUP_DIR="$HOME/.config-backup-$TIMESTAMP"

# --- UI Colors ---
readonly NC='\033[0m'
readonly BOLD='\033[1m'
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'

# --- Component Ordering ---
readonly PREFERRED_ORDER=(
    "niri"
    "noctalia"
    "kitty"
    "nvim"
    "mpd"
    "mpv"
    "fastfetch"
    "yazi"
    "rmpc"
)

# --- Component Maps ---
declare -A BINARY_MAP=(
    ["nvim"]="nvim"
    ["kitty"]="kitty"
    ["fastfetch"]="fastfetch"
    ["mpv"]="mpv"
    ["mpd"]="mpd"
    ["niri"]="niri"
    ["noctalia"]="noctalia"
    ["rmpc"]="rmpc"
    ["yazi"]="yazi"
)

declare -A PACKAGE_MAP=(
    ["nvim"]="neovim"
    ["kitty"]="kitty"
    ["fastfetch"]="fastfetch"
    ["mpv"]="mpv"
    ["mpd"]="mpd"
    ["niri"]="niri"
    ["noctalia"]="noctalia-shell"
    ["rmpc"]="rmpc"
    ["yazi"]="yazi"
)

# --- Default Applications ---
readonly DEFAULT_APP_ORDER=(
    "cliphist"
    "playerctl"
    "brightnessctl"
    "nautilus"
    "brave"
    "vscodium"
    "obsidian"
    "spotify"
    "spicetify"
    "polkit-gnome"
    "qt6ct"
    "bibata-cursor-theme"
)

declare -A DEFAULT_APP_BINARY_MAP=(
    ["cliphist"]="cliphist"
    ["playerctl"]="playerctl"
    ["brightnessctl"]="brightnessctl"
    ["nautilus"]="nautilus"
    ["brave"]="brave"
    ["vscodium"]="codium"
    ["obsidian"]="obsidian"
    ["spotify"]="spotify"
    ["spicetify"]="spicetify"
    ["polkit-gnome"]="polkit-gnome"
    ["qt6ct"]="qt6ct"
    ["bibata-cursor-theme"]="bibata-cursor-theme"
)

declare -A DEFAULT_APP_PACKAGE_MAP=(
    ["cliphist"]="cliphist"
    ["playerctl"]="playerctl"
    ["brightnessctl"]="brightnessctl"
    ["nautilus"]="nautilus"
    ["brave"]="brave-bin"
    ["vscodium"]="vscodium-bin"
    ["obsidian"]="obsidian"
    ["spotify"]="spotify"
    ["spicetify"]="spicetify-cli"
    ["polkit-gnome"]="polkit-gnome"
    ["qt6ct"]="qt6ct"
    ["bibata-cursor-theme"]="bibata-cursor-theme"
)

# --- State Trackers ---
CURRENT_STEP=0
TOTAL_STEPS=12  # Verified: 12 actual execution phases

INSTALLED_CONFIGS=()
SKIPPED_CONFIGS=()
FAILED_CONFIGS=()
FAILED_BACKUPS=()
FAILED_ASSETS=()
INSTALLED_PACKAGES=()
ALREADY_PRESENT_PACKAGES=()
FAILED_PACKAGES=()

DRY_RUN=false
HAS_INTERNET=true

# ==============================================================================
# 1. Logging & Signals
# ==============================================================================

mkdir -p "$LOG_DIR"
echo "=== NIRI RICE INITIALIZATION AUDIT RUNNING AT $(date) ===" > "$LOG_FILE"

log_to_file() {
    local level="$1"
    local msg="$2"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $msg" >> "$LOG_FILE"
}

cleanup_handler() {
    local exit_code=$?
    if [ "$exit_code" -eq 130 ]; then
        echo -e "\n\n${YELLOW}Installation cancelled by user.${NC}"
        log_to_file "INFO" "Execution cancelled by user (SIGINT/SIGTERM)."
    elif [ "$exit_code" -ne 0 ]; then
        echo -e "\n\n${RED}${BOLD}!!! Script terminated unexpectedly. Detailed diagnostics written to: $LOG_FILE${NC}"
        log_to_file "FATAL" "Execution process halted via shell trap error boundary."
    fi
    exit "$exit_code"
}
trap cleanup_handler EXIT
trap 'exit 130' SIGINT SIGTERM

# ==============================================================================
# 2. Terminal UI
# ==============================================================================

print_banner() {
    clear
    echo -e "${PURPLE}+-----------------------------------------------------------------+${NC}"
    echo -e "${PURPLE}|                                                                 |${NC}"
    echo -e "${PURPLE}|                ${GREEN}[Niri] Niri Rice Installer [Niri]${PURPLE}                      |${NC}"
    echo -e "${PURPLE}|                                                                 |${NC}"
    echo -e "${PURPLE}|                 ${CYAN}Niri + Noctalia Configuration${PURPLE}                 |${NC}"
    echo -e "${PURPLE}|                                                                 |${NC}"
    echo -e "${PURPLE}+-----------------------------------------------------------------+${NC}"
    echo -e "  ${BOLD}Version:${NC} ${YELLOW}$VERSION${NC} | ${BOLD}Author:${NC} ${YELLOW}$AUTHOR${NC} | ${BOLD}Log:${NC} ${BLUE}$LOG_FILE${NC}"
    echo -e "-------------------------------------------------------------------\n"
}

render_progress() {
    local percent=$1
    local width=30
    local filled=$(( percent * width / 100 ))
    local empty=$(( width - filled ))
    
    printf "  Progress: ["
    if [ "$filled" -gt 0 ]; then
        printf "%${filled}s" "" | tr ' ' '#'
    fi
    if [ "$empty" -gt 0 ]; then
        printf "%${empty}s" "" | tr ' ' ' '
    fi
    printf "] %d%%\n\n" "$percent"
}

log_step() {
    ((++CURRENT_STEP))
    local title="$1"
    local pct=$(( (CURRENT_STEP * 100) / TOTAL_STEPS ))
    
    echo -e "\n${BLUE}${BOLD}-------------------------------------------------------------------${NC}"
    echo -e "${BLUE}${BOLD}[$CURRENT_STEP/$TOTAL_STEPS] $title${NC}"
    echo -e "${BLUE}${BOLD}-------------------------------------------------------------------${NC}"
    render_progress "$pct"
    log_to_file "STEP" "Started step: $title"
}

log_success() { echo -e "  ${GREEN}[OK]${NC} $1"; log_to_file "SUCCESS" "$1"; }
log_fail()    { echo -e "  ${RED}[FAIL]${NC} $1"; log_to_file "ERROR" "$1"; }
log_info()    { echo -e "  ${CYAN}[INFO]${NC} $1"; log_to_file "INFO" "$1"; }
log_warn()    { echo -e "  ${YELLOW}[WARN]${NC} $1"; log_to_file "WARN" "$1"; }

# ==============================================================================
# 3. Hardware & Repository Inspection
# ==============================================================================

verify_environment() {
    if [ ! -d "$SCRIPT_DIR/configs" ]; then
        log_fail "Repository layout error. Required configs directory is missing."
        exit 1
    fi

    if [ ! -f /etc/arch-release ]; then
        log_fail "Distribution target unsupported. This profile requires Arch Linux."
        exit 1
    fi

    local required_commands=(
        "sudo"
        "pacman"
        "find"
        "cp"
        "mv"
        "rm"
        "mkdir"
    )

    local cmd
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            log_fail "Required system command is missing: $cmd"
            exit 1
        fi
    done

    if ! command -v chsh &>/dev/null; then
        log_warn "Optional command missing: chsh. Default shell configuration will be skipped."
    fi

    log_success "Environment and required system commands verified."
}

probe_network() {
    log_to_file "NETWORK" "Running network link tests."
    if timeout 3 bash -c 'true > /dev/tcp/1.1.1.1/53' 2>/dev/null || \
       timeout 3 bash -c 'true > /dev/tcp/8.8.8.8/53' 2>/dev/null; then
        HAS_INTERNET=true
        log_to_file "NETWORK" "Internet access available."
    else
        HAS_INTERNET=false
        log_to_file "NETWORK" "Internet access unavailable."
    fi
}

get_discovered_modules() {
    local dynamic_modules=()
    local ordered_item
    
    for ordered_item in "${PREFERRED_ORDER[@]}"; do
        if [ -d "$SCRIPT_DIR/configs/$ordered_item" ]; then
            dynamic_modules+=("$ordered_item")
        fi
    done
    
    if [ -d "configs" ]; then
        local entry
        for entry in "$SCRIPT_DIR"/configs/*; do
            if [ -d "$entry" ]; then
                local base_entry="${entry##*/}"
                local is_known=false
                local known_item
                
                for known_item in "${dynamic_modules[@]}"; do
                    if [[ "$known_item" == "$base_entry" ]]; then
                        is_known=true
                        break
                    fi
                done
                
                if ! $is_known; then
                    dynamic_modules+=("$base_entry")
                fi
            fi
        done
    fi
    
    if [ ${#dynamic_modules[@]} -gt 0 ]; then
        printf '%s\n' "${dynamic_modules[@]}"
    fi
}

get_system_aur_helper() {
    if command -v yay &>/dev/null; then
        echo "yay"
    elif command -v paru &>/dev/null; then
        echo "paru"
    else
        echo ""
    fi
}

declare -A PACMAN_CHECK_MODULES=(
    ["noctalia"]=1
)

is_dependency_installed() {
    local mod="$1"
    local check_cmd="$2"
    local pkg_name="$3"

    if [ -n "${PACMAN_CHECK_MODULES[$mod]:-}" ]; then
        pacman -Qi "$pkg_name" &>/dev/null
    else
        command -v "$check_cmd" &>/dev/null
    fi
}

# ==============================================================================
# 4. Execution Core Phases
# ==============================================================================

phase_validate_env() {
    log_step "Validating Environment"
    
    if ! command -v niri &>/dev/null; then
        log_warn "Niri window manager not found in local system bin paths."
    else
        log_success "Niri base environment verified."
    fi

    if is_dependency_installed "noctalia" "${BINARY_MAP[noctalia]}" "${PACKAGE_MAP[noctalia]}"; then
        log_success "Noctalia base environment verified."
    else
        log_warn "Noctalia configuration shell interface not found."
    fi
}

phase_system_refresh() {
    local interactive=$1
    log_step "Updating System"
    if $DRY_RUN; then log_info "Dry Run: Skipping system updates."; return 0; fi

    if ! $HAS_INTERNET; then
        log_warn "Offline state detected. Skipping pacman mirror sync operations."
        return 0
    fi

    local choice="Y"
    if $interactive; then
        read -rp "  Run system package upgrade via pacman? [Y/n]: " choice
        choice=${choice:-Y}
    fi
    
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        log_info "Running pacman system upgrade..."
        if sudo pacman -Syu; then
            log_success "System update complete."
        else
            log_fail "Pacman synchronization encountered an execution error."
            return 1
        fi
    else
        log_info "System update skipped by user choice."
    fi
    return 0
}

phase_inspect_dependencies() {
    log_step "Checking Installed Programs"
    local modules
    mapfile -t modules < <(get_discovered_modules)
    
    local mod
    for mod in "${modules[@]}"; do
        local check_cmd="${BINARY_MAP[$mod]:-"$mod"}"
        local target_pkg="${PACKAGE_MAP[$mod]:-"$mod"}"
        
        if is_dependency_installed "$mod" "$check_cmd" "$target_pkg"; then
            log_success "Package dependency met: $mod ($target_pkg)"
            ALREADY_PRESENT_PACKAGES+=("$target_pkg")
        else
            log_warn "Package dependency missing: $mod ($target_pkg)"
        fi
    done
}

phase_resolve_dependencies() {
    local interactive=$1
    log_step "Installing Missing Programs"
    if $DRY_RUN; then log_info "Dry Run: Skipping application deployment."; return 0; fi

    if ! $HAS_INTERNET; then
        log_warn "Network connection required to install packages. Skipping package deployment."
        return 0
    fi

    local modules
    mapfile -t modules < <(get_discovered_modules)
    local missing_pkgs=()
    local missing_mods=()

    local mod
    for mod in "${modules[@]}"; do
        local check_cmd="${BINARY_MAP[$mod]:-"$mod"}"
        local target_pkg="${PACKAGE_MAP[$mod]:-"$mod"}"
        
        if ! is_dependency_installed "$mod" "$check_cmd" "$target_pkg"; then
            missing_pkgs+=("$target_pkg")
            missing_mods+=("$mod")
        fi
    done

    if [ ${#missing_pkgs[@]} -eq 0 ]; then
        log_success "All application dependencies are verified."
        return 0
    fi

    echo -e "  The following programs are missing: ${YELLOW}${missing_pkgs[*]}${NC}"
    
    local choice="Y"
    if $interactive; then
        read -rp "  Install missing programs? [Y/n]: " choice
        choice=${choice:-Y}
    fi

    if [[ ! "$choice" =~ ^[Yy]$ ]]; then
        log_warn "Skipped program installation. Some system components may be non-functional."
        return 0
    fi

    local helper
    helper=$(get_system_aur_helper)

    local i
    for ((i=0; i<${#missing_pkgs[@]}; i++)); do
        local pkg="${missing_pkgs[i]}"
        log_info "Installing package: $pkg"
        
        if pacman -Si "$pkg" &>/dev/null; then
            if sudo pacman -S --needed --noconfirm "$pkg" 2>>"$LOG_FILE"; then
                log_success "Successfully installed native package: $pkg"
                INSTALLED_PACKAGES+=("$pkg")
                continue
            fi

            log_fail "Official repository package installation failed: $pkg"
            FAILED_PACKAGES+=("$pkg")
            continue
        fi

        if [ -n "$helper" ]; then
            log_info "Package is not available in official repositories. Trying AUR helper: $helper"
            if "$helper" -S --needed --noconfirm "$pkg" 2>>"$LOG_FILE"; then
                log_success "Successfully installed AUR package: $pkg"
                INSTALLED_PACKAGES+=("$pkg")
                continue
            fi
        fi

        log_fail "Failed to install required program package: $pkg"
        FAILED_PACKAGES+=("$pkg")
    done
}

phase_install_default_apps() {
    local interactive=$1
    log_step "Installing Default Applications"
    if $DRY_RUN; then log_info "Dry Run: Skipping default application deployment."; return 0; fi

    if ! $HAS_INTERNET; then
        log_warn "Network connection required to install default applications. Skipping."
        return 0
    fi

    local missing_pkgs=()
    local app
    for app in "${DEFAULT_APP_ORDER[@]}"; do
        local check_cmd="${DEFAULT_APP_BINARY_MAP[$app]:-"$app"}"
        local target_pkg="${DEFAULT_APP_PACKAGE_MAP[$app]:-"$app"}"

        local installed=false

        case "$app" in
            polkit-gnome|bibata-cursor-theme)
                pacman -Qi "$target_pkg" &>/dev/null && installed=true
                ;;
            *)
                command -v "$check_cmd" &>/dev/null && installed=true
                ;;
        esac

        if $installed; then
            log_success "Default application already present: $app ($target_pkg)"
            ALREADY_PRESENT_PACKAGES+=("$target_pkg")
        else
            missing_pkgs+=("$target_pkg")
        fi
    done

    if [ ${#missing_pkgs[@]} -eq 0 ]; then
        log_success "All default applications are already installed."
        return 0
    fi

    echo -e "  The following default apps (browser, editor, notes, file manager, music) are missing: ${YELLOW}${missing_pkgs[*]}${NC}"
    
    local choice="Y"
    if $interactive; then
        read -rp "  Install default applications? [Y/n]: " choice
        choice=${choice:-Y}
    fi

    if [[ ! "$choice" =~ ^[Yy]$ ]]; then
        log_warn "Skipped default application installation. Keybindings referencing them will not work."
        return 0
    fi

    local helper
    helper=$(get_system_aur_helper)

    local pkg
    for pkg in "${missing_pkgs[@]}"; do
        log_info "Installing package: $pkg"
        if pacman -Si "$pkg" &>/dev/null; then
            if sudo pacman -S --needed --noconfirm "$pkg" 2>>"$LOG_FILE"; then
                log_success "Successfully installed native package: $pkg"
                INSTALLED_PACKAGES+=("$pkg")
                continue
            fi

            log_fail "Official repository default application installation failed: $pkg"
            FAILED_PACKAGES+=("$pkg")
            continue
        fi

        if [ -n "$helper" ]; then
            log_info "Package is not available in official repositories. Trying AUR helper: $helper"
            if "$helper" -S --needed --noconfirm "$pkg" 2>>"$LOG_FILE"; then
                log_success "Successfully installed AUR package: $pkg"
                INSTALLED_PACKAGES+=("$pkg")
                continue
            fi
        fi

        log_fail "Failed to install default application package: $pkg"
        FAILED_PACKAGES+=("$pkg")
    done
}

phase_execute_backup() {
    log_step "Backing Up Existing Configurations"
    if $DRY_RUN; then log_info "Dry Run: Bypassing filesystem backup creation."; return 0; fi

    local modules
    mapfile -t modules < <(get_discovered_modules)
    
    local extra_paths=(
        "$HOME/.config/brave-flags.conf"
        "$HOME/.zshrc"
        "$HOME/.p10k.zsh"
        "$HOME/Pictures/Wallpapers"
        "$HOME/.local/share/fonts"
        "$HOME/.local/share/themes"
        "$HOME/.local/share/icons"
        "$HOME/.local/bin"
    )

    local has_something_to_backup=false
    
    local mod
    for mod in "${modules[@]}"; do
        if [ -e "$HOME/.config/$mod" ]; then
            has_something_to_backup=true
            break
        fi
    done

    if ! $has_something_to_backup; then
        local extra
        for extra in "${extra_paths[@]}"; do
            if [ -e "$extra" ]; then
                has_something_to_backup=true
                break
            fi
        done
    fi

    if ! $has_something_to_backup; then
        log_info "No pre-existing configurations or assets detected. Skipping backup creation."
        return 0
    fi

    if ! mkdir -p "$BACKUP_DIR" 2>>"$LOG_FILE"; then
        log_fail "Failed to initialize backup matrix location directory."
        return 1
    fi

    local verified_backups=()
    for mod in "${modules[@]}"; do
        if [ -e "$HOME/.config/$mod" ]; then
            verified_backups+=("$mod")
        fi
    done

    for mod in "${verified_backups[@]}"; do
        if cp -a "$HOME/.config/$mod" "$BACKUP_DIR/" 2>>"$LOG_FILE"; then
            log_success "Saved backup copy of: ~/.config/$mod"
        else
            log_fail "Failed to copy backup configurations for module component target: $mod"
            FAILED_BACKUPS+=("$HOME/.config/$mod")
        fi
    done

    local extra
    for extra in "${extra_paths[@]}"; do
        if [ -e "$extra" ]; then
            local relative="${extra#"$HOME"/}"
            local destination="$BACKUP_DIR/$relative"

            if ! mkdir -p "$(dirname "$destination")" 2>>"$LOG_FILE"; then
                log_fail "Failed to create backup directory: $(dirname "$destination")"
                FAILED_BACKUPS+=("$destination")
                continue
            fi

            if cp -a "$extra" "$destination" 2>>"$LOG_FILE"; then
                log_success "Saved backup copy of: ~/$relative"
            else
                log_fail "Failed to back up: ~/$relative"
                FAILED_BACKUPS+=("$HOME/$relative")
            fi
        fi
    done

    if [ ${#FAILED_BACKUPS[@]} -gt 0 ]; then
        log_fail "Backup completed with ${#FAILED_BACKUPS[@]} failure(s). Refusing to modify user files."
        return 1
    fi
    return 0
}

phase_deploy_configs() {
    local interactive=$1
    log_step "Installing Configurations"
    
    local modules
    mapfile -t modules < <(get_discovered_modules)
    
    if [ ! -d "$HOME/.config" ] && ! $DRY_RUN; then
        if ! mkdir -p "$HOME/.config" 2>>"$LOG_FILE"; then
            log_fail "Failed to create ~/.config directory."
            return 1
        fi
    fi

    local mod
    for mod in "${modules[@]}"; do
        local action=true
        if $interactive; then
            local choice
            read -rp "  Install user configuration profile layout for [${mod}]? [Y/n]: " choice
            choice=${choice:-Y}
            [[ ! "$choice" =~ ^[Yy]$ ]] && action=false
        fi

        if $action; then
            if $DRY_RUN; then
                log_info "Dry Run: Would safe-deploy configurations path profile module: $mod"
                INSTALLED_CONFIGS+=("$mod")
            else
                local tmp_dest="$HOME/.config/.$mod.tmp.$TIMESTAMP"
                local final_dest="$HOME/.config/$mod"
                
                rm -rf "$tmp_dest"
                if cp -a "$SCRIPT_DIR/configs/$mod" "$tmp_dest" 2>>"$LOG_FILE"; then
                    local rollback_dest="$HOME/.config/.$mod.rollback.$TIMESTAMP"

                    if [ -e "$final_dest" ]; then
                        rm -rf "$rollback_dest"
                        if ! mv "$final_dest" "$rollback_dest" 2>>"$LOG_FILE"; then
                            log_fail "Could not stage existing configuration for rollback: $mod"
                            FAILED_CONFIGS+=("$mod")
                            rm -rf "$tmp_dest"
                            continue
                        fi
                    fi

                    if mv "$tmp_dest" "$final_dest" 2>>"$LOG_FILE"; then
                        rm -rf "$rollback_dest"
                        log_success "Installed configuration profile: $mod"
                        INSTALLED_CONFIGS+=("$mod")
                    else
                        log_fail "Configuration deployment failed; restoring previous configuration: $mod"
                        rm -rf "$final_dest"
                        if [ -e "$rollback_dest" ]; then
                            mv "$rollback_dest" "$final_dest" 2>>"$LOG_FILE" || true
                        fi
                        FAILED_CONFIGS+=("$mod")
                        rm -rf "$tmp_dest"
                    fi
                else
                    log_fail "Staging execution step failed for configuration module: $mod"
                    FAILED_CONFIGS+=("$mod")
                    rm -rf "$tmp_dest"
                fi
            fi
        else
            log_warn "Skipped installation profile: $mod"
            SKIPPED_CONFIGS+=("$mod")
        fi
    done

    local asset_folders=("wallpapers" "fonts" "themes" "icons" "bin")
    local asset
    for asset in "${asset_folders[@]}"; do
        if [ -d "$asset" ]; then
            local dest=""
            case "$asset" in
                "wallpapers") dest="$HOME/Pictures/Wallpapers" ;;
                "fonts")      dest="$HOME/.local/share/fonts" ;;
                "themes")     dest="$HOME/.local/share/themes" ;;
                "icons")      dest="$HOME/.local/share/icons" ;;
                "bin")        dest="$HOME/.local/bin" ;;
            esac
            
            if [ -n "$dest" ]; then
                log_info "Installing auxiliary asset profile: $asset"
                if ! $DRY_RUN; then
                    mkdir -p "$dest" 2>>"$LOG_FILE"
                    if cp -a "$asset"/. "$dest/" 2>>"$LOG_FILE"; then
                        log_success "Asset deployment complete: $asset -> $dest"
                    else
                        log_fail "Failed to install asset files for: $asset"
                        FAILED_ASSETS+=("$asset")
                    fi
                else
                    log_info "Dry Run: Would deploy additional components from $asset -> $dest"
                fi
            fi
        fi
    done

    if [ ${#FAILED_CONFIGS[@]} -gt 0 ] || [ ${#FAILED_ASSETS[@]} -gt 0 ]; then
        return 1
    fi
    return 0
}

phase_install_shell_config() {
    local interactive=$1
    log_step "Niri Rice Shell Configuration"
    
    if $interactive; then
        local choice
        read -rp "  Would you like to install Niri Rice Shell Configuration? [Y/n]: " choice
        choice=${choice:-Y}
        if [[ ! "$choice" =~ ^[Yy]$ ]]; then
            log_info "Niri Rice Shell Configuration skipped by user choice."
            return 0
        fi
    fi

    if $DRY_RUN; then
        log_info "Dry Run: Skipping shell component deployments."
        return 0
    fi

    log_info "Verifying prerequisite package binaries (zsh, git, curl)..."
    local shell_pkgs=("zsh" "git" "curl")
    local missing_shell_pkgs=()
    local pkg

    for pkg in "${shell_pkgs[@]}"; do
        if ! command -v "$pkg" &>/dev/null; then
            missing_shell_pkgs+=("$pkg")
        fi
    done

    if [ ${#missing_shell_pkgs[@]} -gt 0 ]; then
        log_info "Missing shell dependencies: ${missing_shell_pkgs[*]}"
        if ! $HAS_INTERNET; then
            log_fail "Network access unavailable. Cannot install missing required shell packages."
            return 1
        fi

        local helper
        helper=$(get_system_aur_helper)
        
        for pkg in "${missing_shell_pkgs[@]}"; do
            log_info "Installing required tool: $pkg"
            if sudo pacman -S --needed --noconfirm "$pkg" 2>>"$LOG_FILE"; then
                log_success "Successfully installed native package: $pkg"
                INSTALLED_PACKAGES+=("$pkg")
            else
                if [ -n "$helper" ]; then
                    log_info "Retrying package installation with helper: $helper"
                    if "$helper" -S --needed --noconfirm "$pkg" 2>>"$LOG_FILE"; then
                        log_success "Successfully installed AUR package: $pkg"
                        INSTALLED_PACKAGES+=("$pkg")
                        continue
                    fi
                fi
                log_fail "Critical dependency installation failure: $pkg"
                return 1
            fi
        done
    else
        log_success "All shell tool dependencies are already met."
    fi

    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        log_info "Installing Oh My Zsh framework..."
        if ! $HAS_INTERNET; then
            log_fail "Network offline. Cannot fetch Oh My Zsh installer."
            return 1
        fi
        if curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh > "$LOG_DIR/omz-install.sh" 2>>"$LOG_FILE"; then
            if RUNZSH=no KEEP_ZSHRC=yes sh "$LOG_DIR/omz-install.sh" --unattended >>"$LOG_FILE" 2>&1; then
                log_success "Oh My Zsh deployment successfully completed."
            else
                log_fail "Oh My Zsh installation script reported execution errors."
                return 1
            fi
        else
            log_fail "Failed to safely fetch Oh My Zsh web installer binary."
            return 1
        fi
    else
        log_success "Oh My Zsh framework is already present."
    fi

    local p10k_dest="$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
    if [ ! -d "$p10k_dest" ]; then
        log_info "Cloning Powerlevel10k theme asset tree..."
        if ! $HAS_INTERNET; then
            log_fail "Network offline. Cannot clone Powerlevel10k theme."
            return 1
        fi
        if git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k_dest" >>"$LOG_FILE" 2>&1; then
            log_success "Powerlevel10k configuration theme cloned."
        else
            log_fail "Failed to successfully clone Powerlevel10k repository mirror target."
            return 1
        fi
    else
        log_success "Powerlevel10k theme repository structure is already present."
    fi

    local plugin_names=("zsh-autosuggestions" "zsh-syntax-highlighting")
    declare -A plugin_urls=(
        ["zsh-autosuggestions"]="https://github.com/zsh-users/zsh-autosuggestions"
        ["zsh-syntax-highlighting"]="https://github.com/zsh-users/zsh-syntax-highlighting"
    )

    local pl
    for pl in "${plugin_names[@]}"; do
        local pl_dest="$HOME/.oh-my-zsh/custom/plugins/$pl"
        if [ ! -d "$pl_dest" ]; then
            log_info "Cloning system extension zsh plugin: $pl"
            if ! $HAS_INTERNET; then
                log_fail "Network offline. Cannot clone plugin: $pl"
                return 1
            fi
            if git clone --depth=1 "${plugin_urls[$pl]}" "$pl_dest" >>"$LOG_FILE" 2>&1; then
                log_success "Plugin linked cleanly: $pl"
            else
                log_fail "Failed to pull configuration plugin assets: $pl"
                return 1
            fi
        else
            log_success "Extension configuration plugin already found: $pl"
        fi
    done

    log_info "Using the centralized backup matrix for existing shell configuration files."

    if [ -f "$SCRIPT_DIR/home/.zshrc" ]; then
        if cp -f "$SCRIPT_DIR/home/.zshrc" "$HOME/.zshrc" 2>>"$LOG_FILE"; then
            log_success "Deployed target user profile link mapping: ~/.zshrc"
        else
            log_fail "Failed to copy user environment file: home/.zshrc"
            return 1
        fi
    else
        log_warn "Repository layout missing configuration context element: home/.zshrc"
    fi

    if [ -f "$SCRIPT_DIR/home/.p10k.zsh" ]; then
        if cp -f "$SCRIPT_DIR/home/.p10k.zsh" "$HOME/.p10k.zsh" 2>>"$LOG_FILE"; then
            log_success "Deployed target user prompt profile link mapping: ~/.p10k.zsh"
        else
            log_fail "Failed to copy prompt layout configuration item: home/.p10k.zsh"
            return 1
        fi
    else
        log_warn "Repository layout missing configuration context element: home/.p10k.zsh"
    fi

    local current_shell
    current_shell=$(getent passwd "$USER" 2>/dev/null | cut -d: -f7) || current_shell=""
    
    local target_shell
    target_shell=$(command -v zsh 2>/dev/null || echo "/usr/bin/zsh")
    
    if [[ "$current_shell" != *zsh ]]; then
        log_info "Configuring default login shell profile path context target..."
        if chsh -s "$target_shell"; then
            log_success "User default login workspace shell updated to: $target_shell"
        else
            log_warn "Failed to execute default shell change command automatically."
        fi
    else
        log_success "Zsh is already registered as the default workspace shell environment."
    fi

    log_success "Niri Rice Shell Configuration pipeline successfully processed."
    return 0
}

phase_signal_environments() {
    log_step "Reloading Running Applications"
    if $DRY_RUN; then log_info "Dry Run: Bypassing operational live reloads."; return 0; fi

    if pgrep -x "kitty" &>/dev/null; then
        killall -USR1 kitty 2>/dev/null && log_success "Kitty configuration reload signal dispatched." || true
    fi
}

# ==============================================================================
# 5. Reporting Engine
# ==============================================================================

phase_compile_summary() {
    echo -e "\n${BLUE}${BOLD}-------------------------------------------------------------------${NC}"
    echo -e "${BLUE}${BOLD}Installation Summary${NC}"
    echo -e "${BLUE}${BOLD}-------------------------------------------------------------------${NC}"
    
    local end_time
    end_time=$(date +%s)
    local elapsed=$((end_time - START_TIME))
    
    echo -e "  ${BOLD}* Installed Packages:${NC}       ${GREEN}${INSTALLED_PACKAGES[*]:-None}${NC}"
    echo -e "  ${BOLD}* Already Met Packages:${NC}    ${CYAN}${ALREADY_PRESENT_PACKAGES[*]:-None}${NC}"
    echo -e "  ${BOLD}* Failed Package Installs:${NC}   ${RED}${FAILED_PACKAGES[*]:-None}${NC}"
    echo -e "  ${BOLD}* Installed Configs:${NC}        ${GREEN}${INSTALLED_CONFIGS[*]:-None}${NC}"
    echo -e "  ${BOLD}* Skipped Configs:${NC}          ${YELLOW}${SKIPPED_CONFIGS[*]:-None}${NC}"
    echo -e "  ${BOLD}* Failed Configs:${NC}           ${RED}${FAILED_CONFIGS[*]:-None}${NC}"
    echo -e "  ${BOLD}* Failed Backups:${NC}          ${RED}${FAILED_BACKUPS[*]:-None}${NC}"
    echo -e "  ${BOLD}* Failed Assets:${NC}           ${RED}${FAILED_ASSETS[*]:-None}${NC}"
    
    if [ -d "$BACKUP_DIR" ]; then
        echo -e "  ${BOLD}* Backup Matrix Root:${NC}       ${PURPLE}$BACKUP_DIR${NC}"
    fi
    echo -e "  ${BOLD}* Diagnostic Log Location:${NC}  ${BLUE}$LOG_FILE${NC}"
    echo -e "  ${BOLD}* Run Time Processing:${NC}      ${YELLOW}$elapsed seconds${NC}"
    echo -e "${BLUE}-------------------------------------------------------------------${NC}"
    
    if [ ${#FAILED_PACKAGES[@]} -gt 0 ] || [ ${#FAILED_CONFIGS[@]} -gt 0 ] || [ ${#FAILED_BACKUPS[@]} -gt 0 ] || [ ${#FAILED_ASSETS[@]} -gt 0 ]; then
        echo -e "\n${RED}${BOLD}        Installation Completed With Errors        ${NC}"
        echo -e "${YELLOW}   Review the failed packages/configurations above. ${NC}\n"
    else
        echo -e "\n${GREEN}${BOLD}        Installation Complete!                    ${NC}"
        echo -e "${GREEN}   Please log out and back in to reload your profile.${NC}"
        echo -e "${GREEN}                 Enjoy Niri Rice!                 ${NC}\n"
    fi
}

# ==============================================================================
# 6. Backup Restore Engine
# ==============================================================================

restore_backup_engine() {
    local target_dir="$1"
    log_info "Restoring configuration from: $target_dir"

    local item
    local relative
    local destination
    local parent
    local restore_failures=0

    while IFS= read -r -d '' item; do
        relative="${item#"$target_dir"/}"
        destination="$HOME/$relative"
        parent="$(dirname "$destination")"

        if ! mkdir -p "$parent" 2>>"$LOG_FILE"; then
            log_fail "Failed to create restore destination: $parent"
            ((++restore_failures))
            continue
        fi

        if [ -e "$destination" ] || [ -L "$destination" ]; then
            rm -rf "$destination" 2>>"$LOG_FILE" || true
        fi

        if cp -a "$item" "$destination" 2>>"$LOG_FILE"; then
            log_success "Restored: ~/$relative"
        else
            log_fail "Failed to restore: ~/$relative"
            ((++restore_failures))
        fi
    done < <(find "$target_dir" -mindepth 1 -maxdepth 1 -print0)

    if [ "$restore_failures" -eq 0 ]; then
        log_success "System rollback operations completed successfully."
        return 0
    else
        log_warn "System rollback completed with $restore_failures failure(s)."
        return 1
    fi
}

execute_restore_operation() {
    CURRENT_STEP=0
    TOTAL_STEPS=2
    
    log_step "Selecting Backup Archive"

    local backups=()
    local dir

    if [ -d "$HOME" ]; then
        for dir in "$HOME"/.config-backup-*; do
            if [ -d "$dir" ]; then
                backups+=("$dir")
            fi
        done
    fi

    if [ ${#backups[@]} -eq 0 ]; then
        log_fail "No previous configurations backup archives found."
        return 1
    fi

    echo -e "\n  ${BOLD}Available Backups:${NC}"

    local i
    for i in "${!backups[@]}"; do
        echo -e "  ${GREEN}[$((i+1))]${NC} $(basename "${backups[$i]}")"
    done

    echo -e "  ${RED}[c]${NC} Cancel"
    echo -e "${BLUE}-------------------------------------------------------------------${NC}"

    local choice
    read -rp "Select a backup archive index to restore: " choice

    if ! [[ "$choice" =~ ^[0-9]+$ ]] ||
       [ "$choice" -gt "${#backups[@]}" ] ||
       [ "$choice" -lt 1 ]; then
        log_info "Rollback procedures canceled."
        return 0
    fi

    local target_dir="${backups[$((choice - 1))]}"
    
    log_step "Restoring System Backups"
    restore_backup_engine "$target_dir" || true
}

# ==============================================================================
# 7. Auxiliary Post-Install Phases
# ==============================================================================

phase_check_noctalia_version() {
    log_step "Checking Noctalia Version"
    if $DRY_RUN; then return 0; fi
    
    local ver
    ver=$(pacman -Q noctalia-shell 2>/dev/null)
    if [ -z "$ver" ]; then 
        log_info "noctalia-shell is not installed yet."
        return 0
    fi
    
    ver=${ver#* }
    case "$ver" in
        4.*) log_success "noctalia-shell version $ver matches the required 4.x line." ;;
        *) log_warn "Installed noctalia-shell version ($ver) is not 4.x -- this rice targets v4.7.7 and may break on v5+. See README." ;;
    esac
}

phase_deploy_brave_flags() {
    log_step "Deploying Brave Flags"
    if [ ! -f "$SCRIPT_DIR/configs/brave-flags.conf" ]; then
        log_info "No brave-flags.conf found. Skipping."
        return 0
    fi
    
    if $DRY_RUN; then
        log_info "Dry Run: Would deploy ~/.config/brave-flags.conf for Brave Wayland support"
        return 0
    fi
    
    mkdir -p "$HOME/.config" 2>>"$LOG_FILE"
    if cp -f "$SCRIPT_DIR/configs/brave-flags.conf" "$HOME/.config/brave-flags.conf" 2>>"$LOG_FILE"; then
        log_success "Deployed Brave Wayland launch flags: ~/.config/brave-flags.conf"
    else
        log_warn "Failed to deploy ~/.config/brave-flags.conf"
    fi
}

phase_apply_spicetify() {
    log_step "Applying Spicetify"
    if ! command -v spotify &>/dev/null || ! command -v spicetify &>/dev/null; then
        log_info "Spotify or Spicetify not installed. Skipping."
        return 0
    fi
    
    if $DRY_RUN; then
        log_info "Dry Run: Would apply Spicetify theme to Spotify."
        return 0
    fi

    local cfg="$HOME/.config/spicetify/config-xpui.ini"
    local spotify_dir=""
    if [ -f "$cfg" ]; then
        spotify_dir=$(grep -oP '^\s*spotify_path\s*=\s*\K.*' "$cfg" 2>/dev/null | tr -d '\r')
    fi

    if [ -n "$spotify_dir" ] && [ -d "$spotify_dir" ]; then
        sudo chmod a+wr "$spotify_dir" 2>>"$LOG_FILE"
        [ -d "$spotify_dir/Apps" ] && sudo chmod -R a+wr "$spotify_dir/Apps" 2>>"$LOG_FILE"
    fi

    if spicetify backup apply &>>"$LOG_FILE"; then
        log_success "Applied Spicetify theme to Spotify."
    else
        log_warn "Could not apply Spicetify automatically. Launch Spotify once, log in, close it, then run: spicetify backup apply"
    fi
}

# ==============================================================================
# 8. Main Orchestration & Entry Point
# ==============================================================================

run_orchestrated_installer() {
    local interactive=$1
    phase_validate_env
    
    phase_system_refresh "$interactive" || true
    phase_inspect_dependencies
    phase_resolve_dependencies "$interactive" || true
    phase_check_noctalia_version
    phase_install_default_apps "$interactive" || true
    
    if ! phase_execute_backup; then
        log_fail "Aborting installation due to backup failures."
        phase_compile_summary
        return 1
    fi
    
    if ! phase_deploy_configs "$interactive"; then
        log_fail "Configuration deployment failed. Initiating automatic rollback..."
        if [ -d "$BACKUP_DIR" ]; then
            restore_backup_engine "$BACKUP_DIR" || true
        fi
        phase_compile_summary
        return 1
    fi
    
    if ! phase_install_shell_config "$interactive"; then
        log_fail "Shell configuration failed. Initiating automatic rollback..."
        if [ -d "$BACKUP_DIR" ]; then
            restore_backup_engine "$BACKUP_DIR" || true
        fi
        phase_compile_summary
        return 1
    fi
    
    phase_deploy_brave_flags
    phase_apply_spicetify
    
    phase_signal_environments
    phase_compile_summary
}

main() {
    verify_environment
    probe_network
    print_banner

    echo -e "  ${BOLD}Select an action to proceed:${NC}"
    echo -e "  ${GREEN}[1]${NC} Full Auto-Install"
    echo -e "  ${GREEN}[2]${NC} Install Selected Configs (Interactive Mode)"
    echo -e "  ${YELLOW}[3]${NC} Restore Backup"
    echo -e "  ${CYAN}[4]${NC} Dry Run"
    echo -e "  ${RED}[5]${NC} Exit"
    echo -e "-------------------------------------------------------------------${NC}"
    local menu_choice
    read -rp "Selection: " menu_choice

    case "$menu_choice" in
        1)
            DRY_RUN=false
            run_orchestrated_installer false
            ;;
        2)
            DRY_RUN=false
            run_orchestrated_installer true
            ;;
        3)
            execute_restore_operation
            ;;
        4)
            DRY_RUN=true
            log_warn "Dry Run Simulation Active. No modifications will be made to your system."
            run_orchestrated_installer false
            ;;
        5)
            echo -e "\nExiting installation workspace. Have an excellent day! [Niri]"
            exit 0
            ;;
        *)
            log_fail "Invalid menu choice selected."
            exit 1
            ;;
    esac
}

main "$@"
