#!/bin/sh
# Lixuz Vagrant initialization script
# Part of the LIXUZ content management system
# Copyright (C) Utrop A/S Portu media & Communications 2008-2014
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

if [ "$(id -u)" = "0" ]; then
    # Root actions
    set -x
    # Make sure debconf doesn't try to open any prompts
    export DEBIAN_FRONTEND=noninteractive
    # Use http.debian.net
    perl -pi -e 's/http....debian.org/http.debian.net/g' /etc/apt/sources.list
    # Update packages
    apt-get update
    apt-get dist-upgrade -y
    # Install dependencies
    apt-get install -y mysql-server memcached cpanminus build-essential git-core inotify-tools make manpages perl-doc rsync screen ssh sudo tig vim wget zsh manpages-dev cpanminus libany-moose-perl libaudio-file-perl libcatalyst-manual-perl libcatalyst-modules-extra-perl libdevel-repl-perl libfile-mmagic-perl libhttp-server-simple-perl libhttp-server-simple-static-perl libjson-any-perl liblocal-lib-perl libmime-lite-perl libmojolicious-perl libmoo-perl libmoosex-declare-perl libmouse-perl libperl-critic-perl libpoe-perl libterm-readline-gnu-perl libtry-tiny-perl libx11-guitest-perl libjson-perl libjson-xs-perl libgtk2-perl-doc libmethod-signatures-perl libgraphics-magick-perl libfile-libmagic-perl perl-tk gettext
    # Install additional useful tools
    apt-get install -y ruby-sass ruby-compass yui-compressor
    # Remove downloaded package files
    apt-get clean
    # Exit with success
    exit 0
else
    # User actions
    set -x
    ln -s /vagrant lixuz
    # Initialize the perl installation
    cpanm --local-lib=~/perl5 --notest local::lib
    perl -I ~/perl5/lib/perl5/ -Mlocal::lib >> ~/.bash_profile
    eval $(perl -I ~/perl5/lib/perl5/ -Mlocal::lib)
    # Modify paths for our local bins and local::lib
    perl -I ~/perl5/lib/perl5/ -Mlocal::lib | tee -a ~/.bash_profile ~/.profile ~/.bashrc ~/.zshrc ~/.shell_shared_local
    echo 'export PATH="/home/vagrant/bin/:$PATH"' | tee -a ~/.bash_profile ~/.profile ~/.bashrc ~/.zshrc ~/.shell_shared_local
    # Upgrade cpanm
    cpanm --local-lib=~/perl5 --self-upgrade --notest
    # Install all required modules from our stratopan repo
    for module in $(perl lixuz/DEPSLIST list 2>/dev/null); do
        if echo "$module" |egrep -q "\w"; then
            cpanm --local-lib=~/perl5 --mirror-only --mirror https://stratopan.com/eskildportu/lixuz/master --notest $module
        fi
    done
    cpanm --local-lib=~/perl5 --mirror-only --mirror https://stratopan.com/eskildportu/lixuz/master --notest Starman JSON::DWIW
    # Create the mysql database and user
    mysql -uroot -e 'CREATE DATABASE lixuz'
    mysql -uroot -e 'CREATE USER "lixuz"@"localhost" IDENTIFIED BY "lixuzpw";'
    mysql -uroot -e 'GRANT ALL ON lixuz.* TO "lixuz"@"localhost";'
    # Instal simpleJSi18n
    mkdir -p ~/bin
    git clone https://github.com/zerodogg/simpleJSi18n.git
    cd simpleJSi18n
    ln -s $PWD/jsxgettext $PWD/jsmsgfmt ~/bin
    cpanm --local-lib=~/perl5 Locale::PO
    export PATH="$HOME/bin:$PATH"
    # Generate a config file and initialize the database
    cd /vagrant
    perl script/lixuz_install.pl --bootstrap --dbname lixuz --dbuser lixuz --dbpwd lixuzpw --installpath /vagrant --filepath ~/lixuztmp/files --templatepath ~/lixuztmp/templates/ --temppath ~/lixuztmp/tmp --indexFiles ~/lixuztmp/indexer --memcached 127.0.0.1:11211 --memcachednamespace orglixuzvagrant --fromemail vagrant@localhost
    # Build dependencies
    make build
	# Add a default user
	/vagrant/tools/lixuzctl plumbing v8 adduser admin admin
    set -
    # Write a wrapper script that starts the server
    cat << EOF > ~/bin/lixuz_server
#!/bin/sh
cd /vagrant
eval \$(perl -I~/perl5/lib/perl5/ -Mlocal::lib)
exec ./script/lixuz_server.pl -f -r "\$@"
EOF
    cat << EOF > ~/bin/vlixuzctl
#!/bin/sh
if [ "\$(pwd)" == "\$HOME" ]; then
    cd /vagrant
fi
eval \$(perl -I~/perl5/lib/perl5/ -Mlocal::lib)
exec /vagrant/tools/lixuzctl "\$@"
EOF
    ln -s /vagrant/tools/lixuzctl ~/bin
    chmod +x ~/bin/lixuz_server
	echo "***"
	echo "Initialization of VM successfully completed."
	echo "The default username and password for logging into lixuz is: admin admin"
	echo "***"
    # Exit with success
    exit 0
fi
