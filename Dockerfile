FROM ubuntu:bionic

# Do not ask for user input
ENV DEBIAN_FRONTEND=noninteractive

# Install dh-virtualenv from a custom PPA (maintained by developer) to get latest version
# the ubuntu base containers do not have add-apt-repository preinstalled so we need a couple
# of steps to fully set it up
RUN apt-get update
RUN apt-get install -y software-properties-common
RUN add-apt-repository ppa:jyrki-pulliainen/dh-virtualenv
RUN apt-get update
RUN apt-get install -y dh-virtualenv

# These are the suggested dependencies
RUN apt-get install -y devscripts python-virtualenv python-sphinx python-sphinx-rtd-theme git equivs

# Backport fix for debhelper bug. We may not need this on other ubuntu releases
# https://github.com/Debian/debhelper/commit/ce3ce761086919fd6e20b840e6f02407bffaaca7
COPY fix-mv-hardlink.patch .
RUN patch -d /usr/share/perl5/Debian/Debhelper/ < fix-mv-hardlink.patch 
