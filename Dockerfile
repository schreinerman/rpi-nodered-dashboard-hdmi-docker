#use armv7hf compatible base image
FROM balenalib/raspberry-pi-debian:buster

#dynamic build arguments coming from the /hooks/build file
ARG BUILD_DATE
ARG VCS_REF

#metadata labels
LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.vcs-url="https://github.com/schreinerman/rpi-nodered-dashboard-hdmi" \
      org.label-schema.vcs-ref=$VCS_REF

#version
ENV IOEXPERT_NODERED_DASHBOARD_HDMI_VERSION 1.0.0

#labeling
LABEL maintainer="info@io-expert.com" \
      version=$IOEXPERT_NODERED_DASHBOARD_HDMI_VERSION \
      description="Desktop"

#set user credentials
ENV USER=pi
ENV PASSWD=raspberry

#update source lists, keys
#create testuser
RUN apt-get update \
 && useradd --create-home --shell /bin/bash $USER \
 && echo $USER:$PASSWD | chpasswd \
 && adduser $USER tty \
 && adduser $USER video \
 && adduser $USER sudo \
 && adduser $USER input \
 && echo $USER " ALL=(root) NOPASSWD:ALL" >> /etc/sudoers.d/$USER \
 && chmod 0440 /etc/sudoers.d/$USER \
 && apt install -y \
#install ssh
    openssh-server \
 && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
 && sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd \
 && mkdir /var/run/sshd \
#install xserver, desktop, login manager, ALSA sound driver
 && apt install -y \
    xserver-xorg \
    xinit \
    x11-xserver-utils \
    xfce4 \
    xfce4-terminal \
 && mkdir /etc/X11/xorg.conf.d \
 && chmod u+s /usr/bin/Xorg \
 && chown -c $USER /etc/X11/xorg.conf.d \
 && apt install -y \
    xserver-xorg-input-evdev \
    gnome-icon-theme tango-icon-theme \
    alsa-oss alsa-tools alsa-tools-gui alsa-utils alsamixergui mpg123 \
# && touch /home/$USER/.Xauthority \
# && chmod 777 /home/$USER/.Xauthority \
 && rm -rf /var/lib/apt/lists/*

#install userland raspberry pi tools (needed vor VNC)
RUN apt-get update && apt install -y \
    git \
 && git clone --depth 1 https://github.com/raspberrypi/firmware /tmp/firmware \
 && mv /tmp/firmware/hardfp/opt/vc /opt \
 && echo "/opt/vc/lib" >/etc/ld.so.conf.d/00-vmcs.conf \
 && /sbin/ldconfig \
 && rm -rf /opt/vc/src \
 && echo "deb http://archive.raspberrypi.org/debian/ buster main" | tee -a /etc/apt/sources.list \
 && gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-key 82B129927FA3303E \
 && gpg -a --export 82B129927FA3303E | apt-key add - \
 && apt update \
 && apt install -y \
#install VNC
    realvnc-vnc-server \
#install pulseaudio
    dbus-x11 pulseaudio \
 && sed -i -e 's;load-module module-console-kit;#load-module module-console-kit;' /etc/pulse/default.pa \
 && usermod -a -G audio $USER \
 && usermod -a -G pulse $USER \
 && usermod -a -G pulse-access $USER \
 && apt install \
#install chromium browser
    chromium-browser \
 && apt install libgles2* \
 && rm -rf /tmp/* \
 && apt remove wget git \
 && apt autoremove \
 && apt upgrade \
 && rm -rf /var/lib/apt/lists/*

#copy files
COPY "./init.d/*" /etc/init.d/

#set the entrypoint
ENTRYPOINT ["/etc/init.d/entrypoint.sh"]

#SSH port
EXPOSE 22 5900

#set STOPSGINAL
STOPSIGNAL SIGTERM

#start container as non-root user, else chromium will not run
USER $USER
