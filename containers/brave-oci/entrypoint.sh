#!/bin/sh
# Keep the container alive across Chromium's Relaunch.
#
# Relaunch (flags page, update restart) starts a fresh browser process and
# then lets the old one exit. With brave as pid 1 that exit stops the
# container and kills the new process, so the window just vanishes.
# Run brave as a child instead and stay up until no browser process is left.
p=x11
[ -n "$WAYLAND_DISPLAY" ] && p=wayland

/opt/brave.com/brave/brave --no-sandbox --ozone-platform=$p "$@" &
child=$!

# Print the pid of every browser process. Renderer, gpu and utility
# children carry --type= and exit together with their browser.
browser_pids() {
  for f in /proc/[0-9]*/cmdline; do
    # The group carries the redirect: a pid can vanish after the glob, and
    # the shell prints that failure itself, outside tr's 2>/dev/null.
    c=$({ tr '\0' ' ' <"$f"; } 2>/dev/null) || continue
    case "$c" in
      /opt/brave.com/brave/brave\ *--type=*) ;;
      /opt/brave.com/brave/brave\ *) pid=${f#/proc/}; echo "${pid%/cmdline}" ;;
    esac
  done
}

# Forward SIGTERM on container stop to the browser that is running now,
# which after a relaunch is not the one started above, so the profile
# gets flushed instead of killed mid-write.
trap 'kill -TERM $(browser_pids) 2>/dev/null' TERM INT

wait "$child"
# A relaunched browser is already running by now; give it a moment anyway.
sleep 1
while [ -n "$(browser_pids)" ]; do
  sleep 1
done
