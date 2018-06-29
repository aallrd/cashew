# Cashew

This script allows you to package binaries *à la* OpenCSW and upload the generated datastream on an internal Solaris catalog.

## Usage
    ---------------------------------------------------------------------------
    Usage: cashew.sh [OPTIONS]
    -----[ OPTIONS ]-----------------------------------------------------------
          -h|--help            : Print this helper.
          -n|--name            : The tool name.
          -p|--pkgname         : The catalog package name.
          -d|--description     : A string to describe the package.
          -v|--version         : The tool version.
          --root               : The root path of the binaries to package.
                                 Default is current local directory.
          --dependencies       : A string containing the list of dependencies.
          --profile            : Specifies the deployment profile to use.
                                 Default is official.
                                 Values: {official|dev}
          --pkg-prefix         : The company prefix to use in the catalog.
                                 Default is ORG.
          --pkg-output         : The directory where to output the created package.
                                 Default is /tmp.
          --catalog-root       : The root path of the catalog where to upload the datastream.
                                 Default is /opt/opencsw/org.
          --verbose            : Print useful variables for debugging purpose.
          --reload-utils       : Reload the bash utils from the repo.


## Example

    ./cashew.sh --verbose \
    --name binutils \
    --pkgname binutilsorg \
    --description "GNU binutils package" \
    --version 2.28 \
    --root /tmp/binutils-2.28-builddir \
    --dependencies "CSWalternatives CSWcas-texinfo CSWcommon CSWcoreutils" \
    --pkg-output /var/tmp

The binaries installed under */tmp/binutils-2.28-builddir* are packaged in the datastream *binutilsorg-2.28,REV=2017.06.21-SunOS5.10-i386-ORG.pkg.gz*

When installed, the package binaries will be deployed under */opt/org/binutils/2.28*

## Install the package

    # Make sure pkgutil is configured to deal with non CSW packages
    $ gsed -i "s/#noncsw=true/noncsw=true/g" /etc/opt/csw/pkgutil.conf

    # Add your organisation repo to the pkgutil list of mirrors
    $ if [[ $(grep -c "opencsw/org" /etc/opt/csw/pkgutil.conf) -ne 1 ]] ; then gsed -i "/mirror=.*/a mirror=http://my.org.fr/opencsw/org" /etc/opt/csw/pkgutil.conf ;fi

    # Update the catalog and install the package
    $ pkgutil -U
    => Fetching new catalog and descriptions (http://my.org.fr/opencsw/testing/i386/5.10) if available ...
    ==> 3971 packages loaded from /var/opt/csw/pkgutil/catalog.my.org.fr_opencsw_testing_i386_5.10
    => Fetching new catalog and descriptions (http://my.org.fr/opencsw/org/i386/5.10) if available ...
    ==> 1 package loaded from /var/opt/csw/pkgutil/catalog.my.org.fr_opencsw_org_i386_5.10
    $ pkgutil -i -y ORGbinutilsorg

## Remove the package

    $ pkgrm ORGbinutilsorg
