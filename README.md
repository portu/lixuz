# LIXUZ - Content management system

Lixuz is a content management system written in perl. Lixuz is using Catalyst,
DBIx::Class, jQuery and several other libraries. It is capable of handling
anything from small websites to large news portals, and has built-in support
for automated image-resizing and audio/video playing.

By default Lixuz uses "FastCGI", enabling it to run under many different web
servers, including Apache 2 and nginx. It also has caching with memcached
builtin to speed up common page requests, and reduce database load for complex
queries.

Lixuz at a glance:

- Fully web-based CMS
- Builtin support for playing video and audio files
- Automatic resizing of images
- Flexible template support with HTML::Mason, with all application logic handled by Lixuz
- Support for importing RSS feeds from external sources
- Flexible access control, with custom permission levels
- Builtin dictionary, tagging and newsletter support
- Support for running under FastCGI and mod_perl
- Uses MySQL and memcached
- Simple installation and upgrading
- Free and open source software, licensed under the GNU General Public License version 3 or later
- Written in Perl (requires 5.10+) using modern technologies like Catalyst, DBIx::Class and Moose

## Development VM

Lixuz comes with a [Vagrant](http://vagrantup.com)-based development
environment. To quickly get a Debian 7 VM with Lixuz and all dependencies first
install Vagrant and then run:

    vagrant up

Once a VM is running you can start a Lixuz server that will listen on
http://127.0.0.1:3000/ by running:

    vagrant ssh -c bin/lixuz_server

See the Vagrant documentation as well as the message output once `vagrant up`
finishes for more information.

## Documentation

Installation documentation, as well as template API documentation etc. can be
found in the docs/ directory.

## License

Copyright (C) Utrop A/S Portu media & Communications 2008-2014

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
