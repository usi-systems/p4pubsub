# Setup

Disable the kernel from automatically sending IPv6 router solicitation requests:

    sudo sysctl -w net.ipv6.conf.eth21.autoconf=0


# Debugging

Detect droped UDP packets on port 1234 (0x04d2):

    while true; do cat /proc/net/udp | grep ":04"; sleep 0.5; done
