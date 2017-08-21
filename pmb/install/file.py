"""
Copyright 2017 Pablo Castellano

This file is part of pmbootstrap.

pmbootstrap is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

pmbootstrap is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with pmbootstrap.  If not, see <http://www.gnu.org/licenses/>.
"""
import logging

import pmb.config
import pmb.helpers.git


def write_os_release(args, suffix):
    logging.info("(" + suffix + ") write /etc/os-release")
    revision = pmb.helpers.git.rev_parse(args)
    filepath = args.work + "/chroot_" + suffix + "/etc/os-release"

    with open(filepath, "w") as fp:
        os_release = \
            """
            PRETTY_NAME="postmarketOS {version}"
            NAME="postmarketOS"
            VERSION_ID="{version}"
            VERSION="{version}"
            ID=postmarketos
            ID_LIKE=alpine
            HOME_URL="http://www.postmarketos.org/"
            SUPPORT_URL="https://github.com/postmarketOS"
            BUG_REPORT_URL="https://github.com/postmarketOS"
            PMOS_HASH="{hash}"
            """.format(version=pmb.config.version, hash=revision)
        fp.write(os_release)
