# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

TF_SUCCESS='false'

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Fix Docker socket permissions on macOS
fix_docker_permissions() {
    if [ -S /var/run/docker.sock ]; then
        log_info "Fixing Docker socket permissions..."
        sudo chmod 666 /var/run/docker.sock
        log_success "Docker socket permissions fixed"
    fi
}

clean_docker_permissions() {
    if [ -S /var/run/docker.sock ]; then
        log_info "Resetting Docker socket permissions..."
        sudo chmod 660 /var/run/docker.sock
        log_success "Docker socket permissions fixed"
    fi
}
