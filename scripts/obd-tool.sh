#!/bin/bash

set -eou pipefail

initializeBackplaneDNS() {
    [ -f /etc/coredns/Corefile ] && return 0
    local ADDRESS=$(ip addr show eth0 | grep "inet\b" | grep "brd" | awk '{print $2}' | cut -d'/' -f1)
    local CIDR="$(ipcalc -n $ADDRESS | awk '/Network/ {print $2}')"
    touch /etc/coredns/internal.hosts
    touch /etc/coredns/external.hosts
    createCorefile
}

createCorefile() {
    cat >/etc/coredns/Corefile <<EOL
. {
    view Internal {
        expr incidr(client_ip(), '$CIDR')
    }

    hosts /etc/coredns/internal.hosts orbitlab.internal {
        ttl 300
        reload 10s
        fallthrough
    }

    forward . /etc/resolv.conf {
        policy sequential
        max_concurrent 1000
    }

    cache 30
    reload
    log
    errors
    health
    ready
}
EOL
}

addRecord() {
    local SUBCOMMAND="$1"
    local ADDRESS="$2"
    local HOSTNAME="$3"

    [ -z "$ADDRESS" ] && SUBCOMMAND=""
    [ -z "$HOSTNAME" ] && SUBCOMMAND=""

    case "$SUBCOMMAND" in
        internal)
            FILE="/etc/coredns/internal.hosts"
            ;;
        external)
            FILE="/etc/coredns/external.hosts"
            ;;
        *)
            echo "obd-tool add-record [internal|external] IPV4_ADDRESS HOSTNAME"
            exit 1
            ;;
    esac

    echo "$ADDRESS $(printf '\t') $HOSTNAME $(printf '\t') $HOSTNAME.orbitlab.internal" >> "$FILE"
}

deleteRecord() {
    local SUBCOMMAND="$1"
    local ADDRESS="$2"

    [ -z "$ADDRESS" ] && SUBCOMMAND=""

    case "$SUBCOMMAND" in
        internal)
            FILE="/etc/coredns/internal.hosts"
            ;;
        external)
            FILE="/etc/coredns/external.hosts"
            ;;
        *)
            echo "obd-tool delete-record [internal|external] IPV4_ADDRESS"
            exit 1
            ;;
    esac

    TMP_FILE=$(mktemp)
    grep -Ev "^${ADDRESS}[[:space:]]" "$FILE" > "$TMP_FILE"
    mv "$TMP_FILE" "$FILE"
}

enableExternal() {
    cat >>/etc/coredns/Corefile <<EOL
. {

    hosts /etc/coredns/external.hosts orbitlab.internal {
        ttl 300
        reload 10s
        fallthrough
    }

    forward . /etc/resolv.conf {
        policy sequential
        max_concurrent 1000
    }

    cache 30
    reload
    log
    errors
    health
    ready
}
EOL
    systemctl restart coredns
}

COMMAND="$1"

case "$COMMAND" in
    init)
        initializeBackplaneDNS
        ;;
    add-record)
        SUBCOMMAND="$2"
        ADDRESS="$3"
        HOSTNAME="$4"
        addRecord "$SUBCOMMAND" "$ADDRESS" "$HOSTNAME"
        ;;
    delete-record)
        SUBCOMMAND="$2"
        ADDRESS="$3"
        deleteRecord "$SUBCOMMAND" "$ADDRESS" "$HOSTNAME"
        ;;
    enable-external)
        grep -q "/etc/coredns/external.hosts" /etc/coredns/Corefile || enableExternal
        ;;
    disable-external)
        createCorefile
        systemctl restart coredns
        ;;
    *)
        echo "Unknown command: $COMMAND" || exit 1
        ;;
esac
