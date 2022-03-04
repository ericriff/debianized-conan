# Experiments with the dh-virtualenv tool
This repo is an exploration of the dh-virtualenv tool which allows us to package python packages as deb packages.
As an example we will be repackaging the Conan package manager since it is a fairly complex project which a bunch of dependencies.
Related links:
* https://github.com/spotify/dh-virtualenv
* https://dh-virtualenv.readthedocs.io/en/1.2.1/
* https://docs.conan.io/en/latest/
* https://cookiecutter.readthedocs.io/
* https://github.com/Springerle/debianized-pypi-mold

The vast majority of the files here are autogenerated, using the `cookiecutter` tool and the `debianized-pypi-mold` template (see links above for more info).
```bash
$ cookiecutter https://github.com/Springerle/debianized-pypi-mold.git
```
To make the project work we had to modify 2 of these autogenerated files. See the commit history for details.
* `debian/rules`: Remove the `--setuptools` argument since its meaning changed on newer versions of `virtualenv`. The desired outcome is now the default and keeping it as-is makes the build fail.
* `debian/changelog`: Remove `~~dev1~jessie` from the version field. No idea where this is comming from but it makes pip try to pull `conan==1.45.0.dev1` which doesn't exist. With this fix it pulls `conan==1.45.0` as expected.

Since `dh-virtualenv` needs a lot of dependencies (most of them are transitive dependencies of `devscripts`) to work we will be using a Docker container to polute the base OS as litte as possible.

The Ubuntu version used in the Dockerfile (`bionic`) has an outdated `debhelper` package that has a bug which prevents this from working. The dockerfile will appy the `fix-mv-hardlink.patch` patch present in the repo, which is a backport of the actual fix.

## Usage
```bash
$ docker build --tag ubuntu-bionic-dh-virtualenv 
# We need to mount the working directory 2 levels deep since debhelper puts its output in cwd/.. so we need the parent directory of the workdir to be accessible as well.
$ docker run -it --rm -v $PWD:/py2deb/py2deb ubuntu-bionic-dh-virtualenv:latest
$ cd /py2deb/py2de
# This installs a bunch of build-time dependencies.
$ yes | mk-build-deps --install debian/control
# This creates the deb package. It creates a virtualenv, uses pip to pull conan and all its dependencies and packages it as a deb. The output is located in ..
$ dpkg-buildpackage -uc -us -b
# Check output
$ ls ..
# Install it
$ cd ..
$ apt install ./conan_1.45.0-1_amd64.deb
$ conan --version
```

# Everything below this line was autogenerated, take it with a grain of salt.
________________________________________________________________________________
# "conan" Debian Packaging

![BSD 3-clause licensed](https://img.shields.io/badge/license-BSD_3--clause-red.svg)
[![debianized-conan](https://img.shields.io/pypi/v/debianized-conan.svg)](https://pypi.python.org/pypi/debianized-conan/)
[![conan](https://img.shields.io/pypi/v/conan.svg)](https://pypi.python.org/pypi/conan/)

**Contents**

 * [What is this?](#what-is-this)
 * [How to build and install the package](#how-to-build-and-install-the-package)
 * [How to set up a simple service instance](#how-to-set-up-a-simple-service-instance)
 * [Trouble-Shooting](#trouble-shooting)
   * ['pkg-resources not found' or similar during virtualenv creation](#pkg-resources-not-found-or-similar-during-virtualenv-creation)
 * [Configuration Files](#configuration-files)
 * [Data Directories](#data-directories)
 * [References](#references)
   * [Related Projects](#related-projects)


## What is this?

This project helps to install typical Python services like Django web applications on Debian-like target hosts,
by providing DEB packaging for the server component.
This makes life-cycle management on production hosts a lot easier, and
[avoids common drawbacks](https://nylas.com/blog/packaging-deploying-python/) of ‘from source’ installs,
like needing build tools and direct internet access in production environments.

The Debian packaging metadata in
[debian](https://github.com/ericriff/debianized-conan/tree/master/debian)
puts the `conan` Python package and its dependencies as released on PyPI into a DEB package,
using [dh-virtualenv](https://github.com/spotify/dh-virtualenv).
The resulting *omnibus package* is thus easily installed to and removed from a machine,
but is not a ‘normal’ Debian `python-*` package. If you want that, look elsewhere.

To add any plugins or other optional dependencies, add them to ``install_requires`` in ``setup.py`` as usual
– only use versioned dependencies so package builds are reproducible.


## How to build and install the package

You need a build machine with all build dependencies installed, specifically
[dh-virtualenv](https://github.com/spotify/dh-virtualenv) in addition to the normal Debian packaging tools.
You can get it from [this PPA](https://launchpad.net/~spotify-jyrki/+archive/ubuntu/dh-virtualenv),
the [official Ubuntu repositories](http://packages.ubuntu.com/search?keywords=dh-virtualenv),
or [Debian packages](https://packages.debian.org/source/sid/dh-virtualenv).

This code requires and is tested with ``dh-virtualenv`` v1.0
– depending on your platform you might get an older version via the standard packages.
On *Jessie*, install it from ``jessie-backports``.
*Zesty* provides a package for *Ubuntu* that works on older releases too,
see *“Extra steps on Ubuntu”* below for how to use it.
In all other cases build *v1.0* from source,
see the [dh-virtualenv documentation](https://dh-virtualenv.readthedocs.io/en/latest/tutorial.html#step-1-install-dh-virtualenv) for that.

With tooling installed,
the following commands will install a *release* version of `conan` into `/opt/venvs/conan/`,
and place a symlink for the `conan` command into the machine's PATH.

```sh
git clone https://github.com/ericriff/debianized-conan.git
cd debianized-conan/
# or "pip download --no-deps --no-binary :all: debianized-conan" and unpack the archive

sudo apt-get install build-essential debhelper devscripts equivs

# Extra steps on Jessie
echo "deb http://ftp.debian.org/debian jessie-backports main" \
    | sudo tee /etc/apt/sources.list.d/jessie-backports.list >/dev/null
sudo apt-get update -qq
sudo apt-get install -t jessie-backports cmake dh-virtualenv
# END jessie

# Extra steps on Ubuntu
( cd /tmp && curl -LO "http://mirrors.kernel.org/ubuntu/pool/universe/d/dh-virtualenv/dh-virtualenv_1.0-1_all.deb" )
sudo dpkg -i /tmp/dh-virtualenv_1.0-1_all.deb
# END Ubuntu

sudo mk-build-deps --install debian/control
dpkg-buildpackage -uc -us -b
dpkg-deb -I ../conan_*.deb
```

The resulting package, if all went well, can be found in the parent of your project directory.
You can upload it to a Debian package repository via e.g. `dput`, see
[here](https://github.com/jhermann/artifactory-debian#package-uploading)
for a hassle-free solution that works with *Artifactory* and *Bintray*.

You can also install it directly on the build machine:

```sh
sudo dpkg -i ../conan_*.deb
/usr/bin/conan --version  # ensure it basically works
```

To list the installed version of `conan` and all its dependencies, call this:

```sh
/opt/venvs/conan/bin/pip freeze | column
```


## Trouble-Shooting

### 'pkg-resources not found' or similar during virtualenv creation

If you get errors regarding ``pkg-resources`` during the virtualenv creation,
update your build machine's ``pip`` and ``virtualenv``.
The versions on many distros are just too old to handle current infrastructure (especially PyPI).

This is the one exception to “never sudo pip”, so go ahead and do this:

```sh
sudo pip install -U pip virtualenv
```

Then try building the package again.


### 'no such option: --no-binary' during package builds

This package needs a reasonably recent `pip` for building.
On `Debian Jessie`, for the internal `pip` upgrade to work,
that means you need a newer `pip` on the system,
or else at least `dh-virtualenv 1.1` installed (as of this writing, that is *git HEAD*).

To upgrade `pip` (which makes sense anyway, version 1.5.6 is ancient), call ``sudo pip install -U pip``.

And to get `dh-virtualenv 1.1` right now on `Jessie`, you need to apply this patch *before* building it:

```diff
--- a/debian/changelog
+++ b/debian/changelog
@@ -1,3 +1,9 @@
+dh-virtualenv (1.1-1~~dev1) unstable; urgency=medium
+
+  * Non-maintainer upload.
+
+ -- Juergen Hermann <jh@web.de>  Wed, 20 Jun 2018 10:22:32 +0000
+
 dh-virtualenv (1.0-1) unstable; urgency=medium

   * New upstream release
--- a/debian/rules
+++ b/debian/rules
@@ -1,7 +1,7 @@
 #!/usr/bin/make -f

 %:
-       dh $@ --with python2 --with sphinxdoc
+       dh $@ --with python2

 override_dh_auto_clean:
        rm -rf doc/_build
@@ -13,6 +13,3 @@ override_dh_auto_build:
        rst2man doc/dh_virtualenv.1.rst > doc/dh_virtualenv.1
        dh_auto_build

-override_dh_installdocs:
-       python setup.py build_sphinx
-       dh_installdocs doc/_build/html

--- a/setup.py
+++ b/setup.py
@@ -25,7 +25,7 @@ from setuptools import setup

 project = dict(
     name='dh_virtualenv',
-    version='1.0',
+    version='1.1.dev1',
     author=u'Jyrki Pulliainen',
     author_email='jyrki@spotify.com',
     url='https://github.com/spotify/dh-virtualenv',
```

See [this ticket](https://github.com/spotify/dh-virtualenv/issues/234) for details,
and hopefully for a resolution at the time you read this.


## How to set up a simple service instance

**TODO** Link to packaged project's documentation, and adapt the text below as needed!

After installing the package, …

The package contains a ``systemd`` unit for the service, and starting it is done via ``systemctl``:

```sh
# conan-web requires conan-worker and conan-cron,
# so there is no need to start / enable them separately
sudo systemctl enable conan
sudo systemctl start conan

# This should show the service in state "active (running)"
systemctl status 'conan' | grep -B2 Active:
```

The service runs as ``conan.daemon``.
Note that the ``conan`` user is not removed when purging the package,
but the ``/var/{log,opt}/conan`` directories and the configuration are.

After an upgrade, the services restart automatically by default,


## Changing the Service Unit Configuration

The best way to change or augment the configuration of a *systemd* service
is to use a ‘drop-in’ file.
For example, to increase the limit for open file handles
above the system defaults, use this in a **``root``** shell:

```sh
unit='conan'

# Change max. number of open files for ‘$unit’…
mkdir -p /etc/systemd/system/$unit.service.d
cat >/etc/systemd/system/$unit.service.d/limits.conf <<'EOF'
[Service]
LimitNOFILE=8192
EOF

systemctl daemon-reload
systemctl restart $unit

# Check that the changes are effective…
systemctl cat $unit
let $(systemctl show $unit -p MainPID)
cat "/proc/$MainPID/limits" | egrep 'Limit|files'
```


## Configuration Files

 * ``/etc/default/conan`` – Operational parameters like global log levels.
 * ``/etc/conan/config.yml`` – The service's YAML configuration.
 * ``/etc/cron.d/conan`` – The house-keeping cron job running each day.

 :information_source: Please note that the files in ``/etc/conan``
 are *not* world-readable, since they might contain passwords.


## Data Directories

 * ``/var/log/conan`` – Extra log files (by the cron job).
 * ``/var/opt/conan`` – Data files created during runtime.

You should stick to these locations, because the maintainer scripts have special handling for them.
If you need to relocate, consider using symbolic links to point to the physical location.


## References

### Related Projects

 * [Springerle/debianized-pypi-mold](https://github.com/Springerle/debianized-pypi-mold) – Cookiecutter that was used to create this project.
