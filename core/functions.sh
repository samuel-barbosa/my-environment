# Ensure that the script is running as root
function core::requires_root {
   if [[ ${EUID} -ne 0 ]]; then
      echo "❌ This script must be executed as root" >&2
      exit 1
   fi
}

# Ensure that the script is running on a Debian-based system
function core::requires_debian {
   if [[ -r /etc/debian_version && -r /etc/os-release ]] && command -v dpkg &>/dev/null; then
      source /etc/os-release
      echo "💻 Detected system: ${DISTRIB_DESCRIPTION:-${PRETTY_NAME:-${DISTRIB_ID:-${NAME:-${ID:-${ID_LIKE:-$(cat /etc/debian_version)}}}} ${DISTRIB_RELEASE:-${VERSION_ID}} ${UBUNTU_RELEASE:-${VERSION_CODENAME}}}} [$(dpkg --print-architecture)]"
   else
      echo "❌ This script is intended only for Debian-based systems" >&2
      exit 1
   fi
}

# Determine the corresponding Ubuntu release for PPA compatibility
function core::get_ubuntu_release {
   local ppa_repo="$1"
   case "$(lsb_release -cs)" in
      15|duke) UBUNTU_RELEASE=noble ;;
      14|forky) UBUNTU_RELEASE=noble ;;
      13|trixie) UBUNTU_RELEASE=noble ;;
      12|bookworm) UBUNTU_RELEASE=jammy ;;
      11|bullseye) UBUNTU_RELEASE=focal ;;
      10|buster) UBUNTU_RELEASE=bionic ;;
      9|stretch) UBUNTU_RELEASE=xenial ;;
      8|jessie) UBUNTU_RELEASE=trusty ;;
      7|wheezy) UBUNTU_RELEASE=precise ;;
      6|squeeze) UBUNTU_RELEASE=lucid ;;
      5|lenny) UBUNTU_RELEASE=hardy ;;
      4|etch) UBUNTU_RELEASE=dapper ;;
      3|sarge) UBUNTU_RELEASE=etch ;;
      2|woody) UBUNTU_RELEASE=sarge ;;
      1|potato) UBUNTU_RELEASE=woody ;;
      0|frozen) UBUNTU_RELEASE=potato ;;
      *) UBUNTU_RELEASE=$(lsb_release -cs) ;;
   esac
}